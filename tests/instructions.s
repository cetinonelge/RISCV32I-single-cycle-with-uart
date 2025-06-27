_00: addi    x31, x0, 0x432
_04: addi    x30, x0, 735
_08: addi    x29, x0, -704
_0C: addi    x28, x0, 20

_10: ori     x27, x29, 51
_14: add     x26, x30, x31
_18: sub     x25, x31, x30
_1C: and     x24, x31, x30
_20: xor     x23, x30, x31

_24: srai    x1, x29, 4
_28: slli    x2, x30, 8
_2C: srl     x3, x29, x28

_30: slt     x4, x29, x31
_34: sltu    x5, x31, x29
_38: slti    x6, x30, 0

_3C: lui     x7, 0xABC
_40: auipc   x8, 0xCDE

_44: sw      x30, 4(x28)
_48: lw      x9, 4(x28)

_4C: sh      x29, 8(x28)
_50: lb      x10, 4(x28)
_54: lhu     x11, 8(x28)

_58: bne     x30, x31, 12
_5C: addi    x0, x0, 0
_60: addi    x0, x0, 0
_64: bge     x29, x28, 12
_68: bltu    x30, x29, 8
_6C: addi    x0, x0, 0

_70: jal     x12, 4
_74: jalr    x13, 8(x12)
_78: addi    x0, x0, 0
_7C: jal     x0, 12
_80: addi    x0, x0, 0
_84: addi    x0, x0, 0

_88: addi    x17, x16, 65
_8C: sb      x17, 0x400(x16)
_90: addi    x17, x16, 66
_94: sb      x17, 0x400(x16)

_98: lw      x18, 0x404(x16)
_9C: lw      x18, 0x404(x16)
_A0: lw      x18, 0x404(x16)
_A4: lw      x18, 0x404(x16)
_A8: lw      x18, 0x404(x16)