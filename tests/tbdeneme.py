# --------------------------------------------------------------------------- #
#  Single-cycle RISC-V cocotb test-bench                                       #
# --------------------------------------------------------------------------- #
import logging
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.result import SimTimeoutError
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer, with_timeout

from Helper_lib import (
    ByteAddressableMemory,
    RISCVInstruction,
    is_signed,
    sra,
    read_file_to_list,
    reverse_hex_string_endianness,
)
from Helper_Student import Log_Datapath, Log_Controller, Log_Registers


# --------------------------------------------------------------------------- #
#  Tiny diagnostics helpers                                                   #
# --------------------------------------------------------------------------- #
def _setup_logger() -> logging.Logger:
    lg = logging.getLogger("PerfModel")

    banner_fmt = "%(asctime)s %(levelname)-5s | %(message)s"   # time comes from SimLog
    if lg.handlers:
        # Cocotb’s SimLog handler is already attached – just restyle it
        lg.handlers[0].setFormatter(logging.Formatter(banner_fmt))
    else:
        # Fallback: attach our own stream handler (unlikely in cocotb)
        h = logging.StreamHandler()
        h.setFormatter(logging.Formatter(banner_fmt))
        lg.addHandler(h)

    lg.setLevel(logging.INFO)
    lg.propagate = False          # prevent duplicates up the root logger
    return lg


# --------------------------------------------------------------------------- #
#  Performance-model / reference                                              #
# --------------------------------------------------------------------------- #
class TB:
    MEM_SIZE = 1024  # bytes

    def __init__(self, instr_hex: list[str], dut, pc_sig, regfile_sig):
        self.dut           = dut
        self.sig_pc        = pc_sig
        self.sig_regfile   = regfile_sig
        self.instr_hex     = [h.replace(" ", "") for h in instr_hex]
        
        self.log           = _setup_logger()
        self.rf            = [0] * 32
        self.pc            = 0
        self.mem           = ByteAddressableMemory(self.MEM_SIZE)
        self.cycles        = 0

    # ------------- utilities -------------------------------------------- #
    def _wreg(self, idx: int, val: int) -> None:
        if idx:                               # x0 is hard-wired to zero
            self.rf[idx] = val & 0xFFFF_FFFF

    def _rreg(self, idx: int) -> int:
        return self.rf[idx]

    # ------------- main reference step ---------------------------------- #
    async def model_step(self):
        self.cycles += 1
        raw   = reverse_hex_string_endianness(self.instr_hex[self.pc // 4])
        instr = RISCVInstruction(raw)

        # ─── pretty logging ─────────────────────────────────────────── #
        self.log.info("═══════════ NEW INSTRUCTION ═══════════")
        self.log.info("[%2d] PC=0x%08X  %s", self.cycles, self.pc, instr.inst_type)
        instr.log(self.log)             # pretty one-liner from Helper_lib
        # ─────────────────────────────────────────────────────────────── #

        next_pc = self.pc + 4
        rd, rs1, rs2 = instr.rd, instr.rs1, instr.rs2
        rv1, rv2     = self._rreg(rs1), self._rreg(rs2)
        imm          = instr.imm
        f3, f7       = instr.funct3, instr.funct7

        # ---------------------------------------------------------------- #
        #  Execute                                                         #
        # ---------------------------------------------------------------- #
        if instr.inst_type == "R":
            match (f3, f7):
                # custom NOT rd,rs1  (funct7=0x20, funct3=FUNCT3_SLL=1)
                case (0x1, 0x20):
                    res = (~rv1) & 0xFFFFFFFF
                case (0x0, 0x00): res = rv1 + rv2
                case (0x0, 0x20): res = rv1 - rv2
                case (0x7, _):    res = rv1 & rv2
                case (0x6, _):    res = rv1 | rv2
                case (0x4, _):    res = rv1 ^ rv2
                case (0x1, _):    res = rv1 << (rv2 & 0x1F)
                case (0x5, 0x00): res = rv1 >> (rv2 & 0x1F)
                case (0x5, 0x20): res = sra(rv1,  rv2 & 0x1F)
                case (0x2, _):    res = int(is_signed(rv1) <  is_signed(rv2))
                case (0x3, _):    res = int(rv1 < rv2)
                case _: raise AssertionError("Unsupported R-type variant")
            self._wreg(rd, res)

        elif instr.inst_type == "I":
            match f3:
                case 0x0: res = rv1 + imm
                case 0x7: res = rv1 & imm
                case 0x6: res = rv1 | imm
                case 0x4: res = rv1 ^ imm
                case 0x2: res = int(is_signed(rv1) < is_signed(imm))
                case 0x3: res = int(rv1 < imm)
                case 0x1: res = rv1 << (imm & 0x1F)
                case 0x5:
                    res = rv1 >> (imm & 0x1F) if f7 == 0x00 else sra(rv1, imm & 0x1F)
                case _: raise AssertionError("Unsupported I-type variant")
            self._wreg(rd, res)

        elif instr.inst_type == "LOAD":
            addr = rv1 + imm
            if addr == 0x00000404:
                # Simulate UART RX: return 0xFFFFFFFF to indicate FIFO empty
                val = 0xFFFFFFFF
            else:
                if addr + 4 > self.MEM_SIZE:
                    raise ValueError(f"Memory access out of range: {hex(addr)} (+4)")
                size = {0: 1, 1: 2, 2: 4}[f3 & 0b11]
                raw  = self.mem.read_bytes(addr, size)
                val  = int.from_bytes(raw, "little", signed=(f3 in (0, 1, 2)))
                if f3 in (4, 5):  # LBU/LHU
                    val &= (1 << (8 * size)) - 1
            self._wreg(rd, val)

        elif instr.inst_type == "STORE":
            addr = rv1 + imm
            data = self._rreg(rs2)
            if addr == 0x00000400:
                self.log.info(f"UART TX → '{chr(data & 0xFF)}' (0x{data & 0xFF:02X})")
                # optionally store TX output for further checking
            else:
                size = {0: 1, 1: 2, 2: 4}[f3 & 0b11]
                # mask to the low “size” bytes (e.g. for SH, size=2 → mask=0xFFFF)
                mask = (1 << (8 * size)) - 1
                low_bits = data & mask
                self.mem.write_bytes(addr, low_bits.to_bytes(size, "little"))

        elif instr.inst_type == "BRANCH":
            cmp = {
                0x0: rv1 == rv2,
                0x1: rv1 != rv2,
                0x4: is_signed(rv1) <  is_signed(rv2),
                0x5: is_signed(rv1) >= is_signed(rv2),
                0x6: rv1 < rv2,
                0x7: rv1 >= rv2,
            }[f3]
            if cmp:
                next_pc = self.pc + imm

        elif instr.inst_type == "JAL":
            self._wreg(rd, self.pc + 4)
            next_pc = self.pc + imm

        elif instr.inst_type == "JALR":
            self._wreg(rd, self.pc + 4)
            next_pc = (rv1 + imm) & ~1

        elif instr.inst_type == "LUI":
            self._wreg(rd, imm)

        elif instr.inst_type == "AUIPC":
            self._wreg(rd, self.pc + imm)

        else:
            raise AssertionError(f"Unsupported instruction type {instr.inst_type}")

        # ---------------------------------------------------------------- #
        self.pc = next_pc & 0xFFFF_FFFF  # keep it 32-bit

    # ------------- DUT check ------------------------------------------- #
    def _compare(self):
        dut_pc  = self.sig_pc.value.integer & 0xFFFF_FFFF
        assert dut_pc == self.pc, f"PC mismatch: model=0x{self.pc:X}, dut=0x{dut_pc:X}"

        mask = 0xFFFF_FFFF
        for i in range(32):
            model_val = self.rf[i] & mask
            # resolve any 'x' bits to zero before int()
            bv = self.sig_regfile.Reg_Out[i].value    # BinaryValue
            bitstr = bv.binstr.replace('x','0').replace('X','0')
            dut_val = int(bitstr, 2) & mask
            assert model_val == dut_val, (
                f"x{i} mismatch: model=0x{model_val:X}, dut=0x{dut_val:X}"
            )

    # ------------- pretty print helper --------------------------------- #
    def _dump_dut(self):
        Log_Datapath(self.dut, self.log)
        Log_Controller(self.dut, self.log)

    def _dump_dut_register(self):
        Log_Registers(self.dut, self.log)
        # nothing: banner at top is enough

    # ------------- top-level run --------------------------------------- #
    async def run(self):
        self.log.info("Running reference model for %d instructions …",
                      len(self.instr_hex))

        await self.model_step()      # decode & log 1st instr
        self._dump_dut()             # <--- moved here for symmetry
        await ClockCycles(self.dut.clk, 1)
        self._dump_dut_register()             # <--- moved here for symmetry
        self._compare()

        while int(self.instr_hex[self.pc // 4], 16) != 0:
            await self.model_step()
            self._dump_dut()             # <--- moved here for symmetry
            await ClockCycles(self.dut.clk, 1)
            self._dump_dut_register()         # <--- moved here for symmetry
            self._compare()


# --------------------------------------------------------------------------- #
#  cocotb entry-point                                                        #
# --------------------------------------------------------------------------- #
@cocotb.test()
async def Single_cycle_test(dut):
    await cocotb.start(Clock(dut.clk, 10, 'us').start(start_high=False))
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await FallingEdge(dut.clk)
    instruction_lines = read_file_to_list('Instructions.hex')
    # Remove white-space and make one word per list element
    instruction_lines = [h.replace(" ", "") for h in instruction_lines]

    # --- pad with NOPs up to the memory depth --------------------------------
    MEM_BYTES   = 256                       # 256 = depth in your Verilog memory
    WORD_COUNT  = MEM_BYTES // 4
    instruction_lines += ['00000000'] * (WORD_COUNT - len(instruction_lines))
    # -------------------------------------------------------------------------

    tb = TB(instruction_lines, dut, dut.fetchPC, dut.datapath_i.RF)
    await tb.run()
