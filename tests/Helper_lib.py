"""
Helper utilities for the single-cycle RV32I(+UART) project
==========================================================

Nothing outside the standard library is imported here, so the file is safe to
drop into any cocotb-based environment.

Public API
----------
read_file_to_list(path)                 -> list[str]
RISCVInstruction(hex32)                -> decoded instruction object
shift_helper(value, shamt, kind)       -> shifted 32-bit value
reverse_hex_string_endianness(s)       -> little/endian swap helper
ByteAddressableMemory(capacity)        -> byte-granular RAM model
is_signed(val32)                       -> signed view of 32-bit value
sra(val32, shamt)                      -> arithmetic right shift helper
"""

from __future__ import annotations

# --------------------------------------------------------------------------- #
#  General helpers                                                            #
# --------------------------------------------------------------------------- #

def read_file_to_list(path: str) -> list[str]:
    """Return file lines stripped of trailing new-lines – fast and tiny."""
    with open(path, "r", encoding="utf-8") as f:
        return [ln.rstrip("\n\r") for ln in f]

def reverse_hex_string_endianness(hex_string: str) -> str:
    """
    Swap byte order in a *compact* hex string (no ``0x``, optional spaces).

    >>> reverse_hex_string_endianness("78563412")
    '12345678'
    """
    bite_str = hex_string.replace(" ", "")
    if len(bite_str) & 1:
        raise ValueError("Hex string must have even length")
    return bytes.fromhex(bite_str)[::-1].hex()

# keep backwards-compat alias (one missing “s”)
reverse_hex_string_endiannes = reverse_hex_string_endianness  # type: ignore


def is_signed(val32: int) -> int:
    """Interpret *val32* as a signed 32-bit two’s complement integer."""
    return val32 if val32 < 0x8000_0000 else val32 - 0x1_0000_0000


def sra(val32: int, shamt: int) -> int:
    """Arithmetic right-shift for 32-bit value, result also 32-bit."""
    shamt &= 0x1F
    signed = is_signed(val32)
    shifted = signed >> shamt
    return shifted & 0xFFFF_FFFF


def shift_helper(value: int, shift: int, shift_type: int, n_bits: int = 32) -> int:
    """
    0 = logical left, 1 = logical right, 2 = arithmetic right   (no rotate).

    All results are masked back to *n_bits* (defaults to 32).
    """
    shift &= n_bits - 1
    if shift_type == 0:            # SLL
        return (value << shift) & ((1 << n_bits) - 1)
    if shift_type == 1:            # SRL
        return (value >> shift) & ((1 << n_bits) - 1)
    if shift_type == 2:            # SRA
        return sra(value, shift)
    raise ValueError("shift_type must be 0, 1 or 2")


# --------------------------------------------------------------------------- #
#  Instruction decoder                                                        #
# --------------------------------------------------------------------------- #

class RISCVInstruction:
    """
    Decode a *single* 32-bit RV32I instruction given in hex.

    Attributes
    ----------
    opcode, rd, rs1, rs2, funct3, funct7 : int
    imm   : immediate matching the instruction type
    imm_i, imm_s, imm_b, imm_u, imm_j   : all immediates pre-decoded
    inst_type : str  (R, I, LOAD, STORE, BRANCH, JAL, JALR, AUIPC, LUI, UNKNOWN)
    """

    __slots__ = (
        "binary", "opcode", "rd", "rs1", "rs2", "funct3", "funct7",
        "imm_i", "imm_s", "imm_b", "imm_u", "imm_j", "inst_type", "imm"
    )

    _OPCODE_MAP = {
        0x33: "R",
        0x13: "I",
        0x03: "LOAD",
        0x23: "STORE",
        0x63: "BRANCH",
        0x6F: "JAL",
        0x67: "JALR",
        0x17: "AUIPC",
        0x37: "LUI",
    }

    def __init__(self, hex32: str):
        word = int(hex32, 16) & 0xFFFF_FFFF
        self.binary = f"{word:032b}"

        self.opcode =  word        & 0x7F
        self.rd     = (word >>  7) & 0x1F
        self.funct3 = (word >> 12) & 0x07
        self.rs1    = (word >> 15) & 0x1F
        self.rs2    = (word >> 20) & 0x1F
        self.funct7 = (word >> 25) & 0x7F

        # --- immediates ----------------------------------------------------
        self.imm_i = self._sign_extend(word >> 20, 12)

        imm_s = ((word >> 7) & 0x1F) | ((word >> 20) & 0xFE0)
        self.imm_s = self._sign_extend(imm_s, 12)

        imm_b = ((word >> 7) & 0x1E)        | ((word >> 20) & 0x7E0) \
              | ((word << 4) & 0x800)       | ((word >> 19) & 0x1000)
        self.imm_b = self._sign_extend(imm_b, 13)

        self.imm_u = (word & 0xFFFFF000)

        imm_j = ((word >> 20) & 0x7FE)      | ((word >> 9) & 0x800) \
              | (word & 0xFF000)            | ((word >> 11) & 0x100000)
        self.imm_j = self._sign_extend(imm_j, 21)

        # --- type & canonical immediate ------------------------------------
        self.inst_type = self._OPCODE_MAP.get(self.opcode, "UNKNOWN")
        self.imm = {
            "I": self.imm_i, "LOAD": self.imm_i, "JALR": self.imm_i,
            "S": self.imm_s, "STORE": self.imm_s,
            "B": self.imm_b, "BRANCH": self.imm_b,
            "U": self.imm_u, "LUI": self.imm_u, "AUIPC": self.imm_u,
            "J": self.imm_j, "JAL": self.imm_j,
        }.get(self.inst_type, 0)

    # ------------------------------------------------------------------ #
    #  utils                                                              #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _sign_extend(value: int, bits: int) -> int:
        sign_bit = 1 << (bits - 1)
        return (value ^ sign_bit) - sign_bit

    # pretty printer for debug logging
    def log(self, logger) -> None:
        logger.debug(
            "Instr %s  opc=%02x  rd=%d rs1=%d rs2=%d  f3=%x f7=%02x  imm=%d(%s)",
            self.inst_type, self.opcode, self.rd, self.rs1, self.rs2,
            self.funct3, self.funct7, self.imm,
            ["I","S","B","U","J","-"][("IS" "B" "U" "J").find(self.inst_type[0])]
        )


# --------------------------------------------------------------------------- #
#  Simple byte-addressable memory                                             #
# --------------------------------------------------------------------------- #

class ByteAddressableMemory:
    """A very small, pure-Python byte array that supports word/byte accesses."""

    __slots__ = ("mem", "_cap")

    def __init__(self, size: int):
        self._cap = size
        self.mem  = bytearray(size)

    # ---------- helpers ------------------------------------------------ #
    def _check(self, addr: int, length: int):
        if not (0 <= addr <= self._cap - length):
            raise ValueError(f"Memory access out of range: 0x{addr:X} (+{length})")

    # ---------- word-granular ops (little-endian) ---------------------- #
    def read(self, address: int) -> bytes:
        self._check(address, 4)
        return self.mem[address : address + 4]

    def write(self, address: int, data: int) -> None:
        self._check(address, 4)
        self.mem[address : address + 4] = data.to_bytes(4, "little", signed=False)

    # ---------- byte-granular ops -------------------------------------- #
    def read_bytes(self, address: int, size: int) -> bytes:
        self._check(address, size)
        return self.mem[address : address + size]

    def write_bytes(self, address: int, data: bytes) -> None:
        self._check(address, len(data))
        self.mem[address : address + len(data)] = data
