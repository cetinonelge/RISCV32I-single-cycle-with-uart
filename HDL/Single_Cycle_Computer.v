// ---------------------------------------------------------------------------
//  Single-cycle RV32I computer – top level
// ---------------------------------------------------------------------------
module Single_Cycle_Computer
(
    input              clk,
    input              reset,

    // UART physical connections
    input              uart_rx,
    input              uart_clk,
    output             uart_tx,

    // debug port
    input      [4:0]   Debug_Source_select ,
    output     [31:0]  Debug_out,

    // fetch-stage PC for test-bench observation
    output     [31:0]  fetchPC
);


    //-----------------------------------------------------------------------
    //  Control-path ⇄ data-path interconnect
    //-----------------------------------------------------------------------
    wire         MemWrite, RegWrite, ALUSrc;
    wire  [1:0]  PCSrc, ResultSrc, Size_Write;
    wire  [2:0]  ReadDataMode, ImmSrc;
    wire  [3:0]  ALUControl;
    wire  [3:0]  ALUFlags;

    // Instructionuction word travels from datapath → controller
    wire  [31:0] Instruction;

    //-----------------------------------------------------------------------
    //  Datapath
    //-----------------------------------------------------------------------
    DATAPATH datapath_i (
    .clk(clk),
    .reset(reset),
    .MemWrite(MemWrite),
    .RegWrite(RegWrite),
    .ALUSrc(ALUSrc),
    .PCSrc(PCSrc),
    .ResultSrc(ResultSrc),
    .Size_Write(Size_Write),
    .ReadDataMode(ReadDataMode),
    .ImmSrc(ImmSrc),
    .ALUControl(ALUControl),
    .Debug_Source_select(Debug_Source_select),

    .Instruction(Instruction),
    .Debug_out(Debug_out),
    .ALUFlags(ALUFlags),
    .PC(fetchPC),

    // UART ports
    .uart_rx(uart_tx),
    .uart_tx(uart_rx),
    .uart_clk(uart_clk)
);


    //-----------------------------------------------------------------------
    //  Controller
    //-----------------------------------------------------------------------
    CONTROLLER controller_i (
        // outputs to datapath
        .MemWrite   ( MemWrite  ),
        .RegWrite   ( RegWrite  ),
        .ALUSrc     ( ALUSrc    ),
        .PCSrc      ( PCSrc     ),
        .ResultSrc  ( ResultSrc ),
        .Size_Write  ( Size_Write ),
        .ReadDataMode ( ReadDataMode),
        .ImmSrc     ( ImmSrc    ),
        .ALUControl ( ALUControl),

        // inputs from datapath
        .Instruction      ( Instruction     ),
        .ALUFlags   ( ALUFlags  )
    );

endmodule
