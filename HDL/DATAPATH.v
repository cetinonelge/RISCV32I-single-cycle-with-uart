module DATAPATH (
    input clk,
    input reset,
    input        MemWrite,
    input        RegWrite,
    input        ALUSrc,
    input [1:0]  PCSrc,
    input [1:0]  ResultSrc,
    input [1:0]  Size_Write,
    input [2:0]  ReadDataMode,
    input [2:0]  ImmSrc,
    input [3:0]  ALUControl,
    input [4:0]  Debug_Source_select,

    output [31:0] Instruction,
    output [31:0] Debug_out,
    output [3:0] ALUFlags,
    output [31:0] PC,

    // UART I/O
    input uart_rx,
    input uart_clk,
    output uart_tx
);

wire [31:0] PCPlus4, PCTarget, ALUResult, PCNext;
Mux_4to1 #(32) PCNextMUX (.select(PCSrc), .input_0(PCPlus4), .input_1(PCTarget), .input_2(ALUResult), .input_3(0), .output_value(PCNext));
Register_rsten_neg #(32) PC_reg (.clk(clk), .reset(reset), .we(1'b1), .DATA(PCNext), .OUT(PC));

Adder #(32) PCPlus4Adder (.DATA_A(PC), .DATA_B(32'd4), .OUT(PCPlus4));

Instruction_memory #(4, 32) IM (.ADDR(PC), .RD(Instruction));

wire [31:0] ImmExt;
Extender Extend (.Extended_data(ImmExt), .DATA(Instruction[31:7]), .select(ImmSrc));
Adder #(32) PCTargetAdder (.DATA_A(PC), .DATA_B(ImmExt), .OUT(PCTarget));

wire [31:0] Result, RD1, RD2;
Register_file #(32) RF (
    .clk(clk),
    .reset(reset),
    .write_enable(RegWrite),
    .A1(Instruction[19:15]),
    .A2(Instruction[24:20]),
    .A3(Instruction[11:7]),
    .WD3(Result),
    .Debug_Source_select(Debug_Source_select),
    .RD1(RD1),
    .RD2(RD2),
    .Debug_out(Debug_out)
);

wire [31:0] SrcB;
Mux_2to1 #(32) ALUSrcBMUX (.select(ALUSrc), .input_0(RD2), .input_1(ImmExt), .output_value(SrcB));

wire CO, OVF, N, Zero;
ALU #(32) ALU (
    .control(ALUControl),
    .DATA_A(RD1),
    .DATA_B(SrcB),
    .OUT(ALUResult),
    .CO(CO),
    .OVF(OVF),
    .N(N),
    .Zero(Zero)
);
assign ALUFlags = {Zero, N, CO, OVF};

wire [31:0] MemReadData;
Memory #(4, 32) DM (
    .clk(clk),
    .WE(MemWrite),
    .ADDR(ALUResult),
    .WD(RD2),
    .Size_Write(Size_Write),
    .RD(MemReadData)
);

// UART Peripheral wires
wire uart_tx_busy;
wire [31:0] uart_read_data;
wire uart_write_en = MemWrite && (ALUResult == 32'h00000400);
wire uart_read_en  = !MemWrite && (ALUResult == 32'h00000404);

UART_Peripheral uart (
    .clk(uart_clk),
    .rst(reset),
    .write_en(uart_write_en),
    .write_data(RD2[7:0]),
    .read_en(uart_read_en),
    .read_data(uart_read_data),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    .tx_busy(uart_tx_busy)
);

// Select between memory and UART for read data
wire [31:0] FinalReadData;
assign FinalReadData = (ALUResult == 32'h00000404) ? uart_read_data : MemReadData;

wire [31:0] ReadDataExtended;
ReadDataExtend #(32) RDE (
    .in_word(FinalReadData),
    .mode(ReadDataMode),
    .out_word(ReadDataExtended)
);

Mux_4to1 #(32) ResultMUX (
    .select(ResultSrc),
    .input_0(ALUResult),
    .input_1(ReadDataExtended),
    .input_2(PCPlus4),
    .input_3(PCTarget),
    .output_value(Result)
);

endmodule
