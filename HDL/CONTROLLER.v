// ---------------------------------------------------------------------------
//  Single-cycle RV32I   --  Control Unit
//  * adds custom NOT  rd, rs1   (bitwise invert of rs1)
//  * every opcode OPC_branch drives every control output
//  * symbolic localparams for easy maintenance
// ---------------------------------------------------------------------------
module CONTROLLER #(
    parameter XLEN = 32
)(
    // ----------- status / decode inputs ------------------------------------
    input      [XLEN-1:0] Instruction,     // current Instruction
    input      [3:0]      ALUFlags,     // {Zero , Neg , Carry , Ovf}
    
    // ----------- control signals to datapath -------------------------------
    output reg         MemWrite,
    output reg         RegWrite,
    output reg         ALUSrc,
    output reg  [1:0]  PCSrc,
    output reg  [1:0]  ResultSrc,
    output reg  [1:0]  Size_Write,
    output reg  [2:0]  ReadDataMode,
    output reg  [2:0]  ImmSrc,
    output reg  [3:0]  ALUControl
);

    // -----------------------------------------------------------------------
    //  Field extraction
    // -----------------------------------------------------------------------
    wire [6:0]  opcode  = Instruction[6:0];
    wire [2:0]  funct3  = Instruction[14:12];
    wire [6:0]  funct7  = Instruction[31:25];
    wire        funct7b5 = Instruction[30];        // handy alias

    // -----------------------------------------------------------------------
    //  Opcodes
    // -----------------------------------------------------------------------
    localparam  OPC_OP_IMM  = 7'b0010011,
                OPC_OP      = 7'b0110011,
                OPC_LOAD    = 7'b0000011,
                OPC_STORE   = 7'b0100011,
                OPC_BRANCH  = 7'b1100011,
                OPC_JALR    = 7'b1100111,
                OPC_JAL     = 7'b1101111,
                OPC_AUIPC   = 7'b0010111,
                OPC_LUI     = 7'b0110111;

    // -----------------------------------------------------------------------
    //  Funct3 codes used repeatedly
    // -----------------------------------------------------------------------
    localparam  FUNCT3_BEQ  = 3'b000,
                FUNCT3_BNE  = 3'b001,
                FUNCT3_BLT  = 3'b100,
                FUNCT3_BGE  = 3'b101,
                FUNCT3_BLTU = 3'b110,
                FUNCT3_BGEU = 3'b111,

                FUNCT3_ADD  = 3'b000,
                FUNCT3_SLL  = 3'b001,
                FUNCT3_SLT  = 3'b010,
                FUNCT3_SLTU = 3'b011,
                FUNCT3_XOR  = 3'b100,
                FUNCT3_SRL  = 3'b101,
                FUNCT3_OR   = 3'b110,
                FUNCT3_AND  = 3'b111;

    // -----------------------------------------------------------------------
    //  Immediate type selector (to Extender)
    // -----------------------------------------------------------------------
    localparam  IMM_ITYPE = 3'd0,
                IMM_STYPE = 3'd1,
                IMM_BTYPE = 3'd2,
                IMM_JTYPE = 3'd3,
                IMM_UTYPE = 3'd4;

    // -----------------------------------------------------------------------
    //  ALU-control codes
    //  {bit3,bit2:0} == {funct7[30],funct3} for all base ops
    //  4'b1111 used for OPC_JALR
    //  4'b1010 reserved here for custom NOT
    // -----------------------------------------------------------------------
    localparam  ALU_NOT  = 4'b1010,
                ALU_OPC_JALR = 4'b1111;   // reuse from earlier discussion

    //  Constants to make ResultSrc / PCSrc more readable
    localparam  RS_ALU   = 2'b00,
                RS_MEM   = 2'b01,
                RS_PC4   = 2'b10,
                RS_OPC_AUIPC = 2'b11;

    localparam  PC_PLUS4 = 2'b00,
                PC_OPC_BRANCH= 2'b01,
                PC_OPC_JALR  = 2'b10;

    // -----------------------------------------------------------------------
    //  Combinational controller
    // -----------------------------------------------------------------------
    always @* begin
        case (opcode)
        // -------------------------------------------------------------- OP-IMM
        OPC_OP_IMM: begin
            ImmSrc       = IMM_ITYPE;
            ALUSrc       = 1'b1;                 // use immediate
            ResultSrc    = RS_ALU;
            RegWrite     = 1'b1;
            PCSrc        = PC_PLUS4;
            MemWrite     = 0;
            Size_Write   = 2'bXX;
            ReadDataMode = 3'bXXX;

            // SRLI vs SRAI need the MSB of funct7
            if (funct3 == FUNCT3_SRL)
                ALUControl = {funct7b5, FUNCT3_SRL};
            else
                ALUControl = {1'b0,     funct3   };
        end
        // ---------------------------------------------------------------- OP
        OPC_OP: begin
            ImmSrc       = 3'bXXX;                 // not used
            ALUSrc       = 1'b0;                   // rs2
            ResultSrc    = RS_ALU;
            RegWrite     = 1'b1;
            PCSrc        = PC_PLUS4;
            MemWrite     = 0;
            Size_Write   = 2'bXX;
            ReadDataMode = 3'bXXX;

            // ---- custom NOT rd,rs1  (funct7/funct3 chosen to be unique)
            if (funct7 == 7'b0100000 && funct3 == FUNCT3_SLL)   // example: 0x20 & 001
                ALUControl = ALU_NOT;
            else
                ALUControl = {funct7b5, funct3};
        end
        // -------------------------------------------------------------  OPC_LOAD
        OPC_LOAD: begin
            ImmSrc       = IMM_ITYPE;
            ALUSrc       = 1'b1;                 // base+offset
            ResultSrc    = RS_MEM;
            RegWrite     = 1'b1;
            ReadDataMode = funct3;
            ALUControl   = {1'b0, FUNCT3_ADD};   // address calc
            PCSrc        = PC_PLUS4;
            MemWrite     = 0;
            Size_Write   = 2'bXX;
        end
        // ------------------------------------------------------------- OPC_STORE
        OPC_STORE: begin
            ImmSrc       = IMM_STYPE;
            ALUSrc       = 1'b1;
            MemWrite     = 1'b1;
            Size_Write   = Instruction[13:12];         // 00:B 01:H 10:W
            ALUControl   = {1'b0, FUNCT3_ADD};
            ResultSrc    = RS_MEM;               // address calc
            RegWrite     = 1'b0;
            PCSrc        = PC_PLUS4;
            ReadDataMode = 3'bXXX;
        end
        // ------------------------------------------------------------- OPC_BRANCH
        OPC_BRANCH: begin
            ImmSrc       = IMM_BTYPE;
            ALUSrc       = 1'b0;
            ALUControl   = {1'b1, FUNCT3_ADD};   // SUB for compare
            ResultSrc    = 2'bXX;
            // condition logic
            case (funct3)
                FUNCT3_BEQ : PCSrc = ALUFlags[3] ? PC_OPC_BRANCH : PC_PLUS4;
                FUNCT3_BNE : PCSrc = ~ALUFlags[3]? PC_OPC_BRANCH : PC_PLUS4;
                FUNCT3_BLT : PCSrc = (ALUFlags[2]^ALUFlags[0])?PC_OPC_BRANCH:PC_PLUS4;
                FUNCT3_BGE : PCSrc = (ALUFlags[2]^ALUFlags[0])?PC_PLUS4 : PC_OPC_BRANCH;
                FUNCT3_BLTU: PCSrc =  ALUFlags[1]? PC_PLUS4 : PC_OPC_BRANCH;
                FUNCT3_BGEU: PCSrc =  ALUFlags[1]? PC_OPC_BRANCH : PC_PLUS4;
                default    : PCSrc = PC_PLUS4;
            endcase
            RegWrite      = 0;
			MemWrite      = 0;
			ReadDataMode    = 3'bXXX;
			Size_Write     = 2'bXX;
        end
        // -------------------------------------------------------------- OPC_JALR
        OPC_JALR: begin
            ImmSrc       = IMM_ITYPE;
            ALUSrc       = 1'b1;
            RegWrite     = 1'b1;
            ResultSrc    = RS_PC4;
            PCSrc        = PC_OPC_JALR;
            ALUControl   = ALU_OPC_JALR;
            MemWrite     = 0;
			ReadDataMode   = 3'bXXX;
			Size_Write    = 2'bXX;
        end
        // -------------------------------------------------------------- JAL
        OPC_JAL: begin
            ImmSrc       = IMM_JTYPE;
            RegWrite     = 1'b1;
            ResultSrc    = RS_PC4;
            PCSrc        = PC_OPC_BRANCH;            // PCTarget = PC + Imm
            MemWrite     = 0;
			ReadDataMode   = 3'bXXX;
			Size_Write    = 2'bXX;
            ALUSrc       = 1'bX;
            ALUControl   = 4'bXXXX;
        end
        // ------------------------------------------------------------- OPC_AUIPC
        OPC_AUIPC: begin
            ImmSrc       = IMM_UTYPE;
            RegWrite     = 1'b1;
            ResultSrc    = RS_OPC_AUIPC;
            PCSrc        = PC_PLUS4;
            ALUControl   = 4'bXXXX;
			ALUSrc       = 1'bX;
            MemWrite     = 0;
			ReadDataMode   = 3'bXXX;
			Size_Write    = 2'bXX;
        end
        // --------------------------------------------------------------- OPC_LUI
        OPC_LUI: begin
            ImmSrc       = IMM_UTYPE;
            RegWrite     = 1'b1;
            ALUSrc       = 1'b1;
            ResultSrc    = RS_ALU;
            ALUControl   = {1'b1, FUNCT3_OR};    // "pass B"
            PCSrc        = PC_PLUS4;
            MemWrite     = 0;
			ReadDataMode   = 3'bXXX;
			Size_Write    = 2'bXX;
        end
        // ----------------------------------------------------------- default
        default: begin
        //--------------------------------------------------------------------
        //  Set **explicit defaults** to avoid accidental latches
        //--------------------------------------------------------------------
            MemWrite     = 1'b0;
            RegWrite     = 1'b0;
            ALUSrc       = 1'b0;
            PCSrc        = PC_PLUS4;
            ResultSrc    = RS_ALU;
            Size_Write   = 2'bXX;
            ReadDataMode = 3'bXXX;
            ImmSrc       = IMM_ITYPE;
            ALUControl   = {funct7b5,funct3};  // sane default (ADD/SUB/…)
        end
        // -------------------------------------------------------------------
        endcase
    end  // always @*
endmodule
