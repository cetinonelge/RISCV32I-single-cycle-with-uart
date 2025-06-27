INDENT = "                               "          # ← eight spaces   (change to "\t\t" if you prefer real tabs)
def ToHex(value):
    try:
        ret = hex(value.integer)
    except: #If there are 'x's in the value
        ret = "0b" + str(value)
    return ret

def Log_Datapath(dut, logger):
    sigs = {
        "Instruction" : ToHex(dut.datapath_i.Instruction.value),
        "A3"          : ToHex(dut.datapath_i.RF.A3.value),
        "WD3"         : ToHex(dut.datapath_i.RF.WD3.value),
        "RegWrite"    : ToHex(dut.datapath_i.RegWrite.value),
        "MemWrite"    : ToHex(dut.datapath_i.MemWrite.value),
        "ALUSrc"      : ToHex(dut.datapath_i.ALUSrc.value),
        "PCSrc"       : ToHex(dut.datapath_i.PCSrc.value),
        "ResultSrc"   : ToHex(dut.datapath_i.ResultSrc.value),
        "Size_Write"  : ToHex(dut.datapath_i.Size_Write.value),
        "ReadDataMode": ToHex(dut.datapath_i.ReadDataMode.value),
        "ImmSrc"      : ToHex(dut.datapath_i.ImmSrc.value),
        "ALUControl"  : ToHex(dut.datapath_i.ALUControl.value),
        "ALUResult"   : ToHex(dut.datapath_i.ALUResult.value),
        "PCNext"      : ToHex(dut.datapath_i.PCNext.value),
    }
    block = ("\n" + INDENT).join(f"{k:12}: {v}" for k, v in sigs.items())
    logger.info("***** DATAPATH SIGNALS *****\n%s%s", INDENT, block)


def Log_Controller(dut, logger):
    sigs = {
        "RegWrite" : ToHex(dut.datapath_i.RegWrite.value),
        "MemWrite" : ToHex(dut.datapath_i.MemWrite.value),
        "ALUSrc"   : ToHex(dut.datapath_i.ALUSrc.value),
        "PCSrc"    : ToHex(dut.datapath_i.PCSrc.value),
        "ResultSrc": ToHex(dut.datapath_i.ResultSrc.value),
        "ImmSrc"   : ToHex(dut.datapath_i.ImmSrc.value),
        "ALUCtrl"  : ToHex(dut.datapath_i.ALUControl.value),
        # add more control-path wires if you like …
    }
    block = ("\n" + INDENT).join(f"{k:12}: {v}" for k, v in sigs.items())
    logger.info("***** CONTROLLER SIGNALS *****\n%s%s", INDENT, block)

# ──────────────────────────────────────────────────────────────────────
#  Pretty register dump (x0–x31)                                        #
# ──────────────────────────────────────────────────────────────────────
def Log_Registers(dut, logger):
    """
    Pretty-print x0…x31 from RF.Reg_Out[*], resolving 'x' bits as 0.
    """
    rf = dut.datapath_i.RF
    try:
        arr = rf.Reg_Out
    except AttributeError:
        logger.warning("RF.Reg_Out not visible — skipping register dump")
        return

    words = []
    for idx in range(32):
        handle = arr[idx]
        bv = handle.value  # this is a BinaryValue
        # get the raw bit-string, replace any x/X with '0'
        bitstr = bv.binstr.replace('x','0').replace('X','0')
        # parse it
        val = int(bitstr, 2)
        words.append(f"x{idx:02d}:{val:08x}")

    # 8 regs per line
    lines = ["  ".join(words[i:i+8]) for i in range(0, 32, 8)]
    INDENT = "        "
    logger.info("***** REGISTERS *****\n%s%s", INDENT, ("\n"+INDENT).join(lines))


