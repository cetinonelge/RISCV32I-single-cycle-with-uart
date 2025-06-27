// ------------------------------------------------------------
// 32-to-1 multiplexer (Verilog-2001)
//
// * WIDTH : data word width (default = 4 bits)
// * select: 5-bit one-hot encoded index
// ------------------------------------------------------------
module Mux_32to1 #(parameter WIDTH = 4) (
    input  [4:0]          select,
    // 32 individual word inputs
    input  [WIDTH-1:0]    input_0 , input_1 , input_2 , input_3 ,
    input  [WIDTH-1:0]    input_4 , input_5 , input_6 , input_7 ,
    input  [WIDTH-1:0]    input_8 , input_9 , input_10, input_11,
    input  [WIDTH-1:0]    input_12, input_13, input_14, input_15,
    input  [WIDTH-1:0]    input_16, input_17, input_18, input_19,
    input  [WIDTH-1:0]    input_20, input_21, input_22, input_23,
    input  [WIDTH-1:0]    input_24, input_25, input_26, input_27,
    input  [WIDTH-1:0]    input_28, input_29, input_30, input_31,
    output [WIDTH-1:0]    output_value
);

    // ----------------------------------------------------------------
    // 1) Bundle the thirty-two WIDTH-bit words into a Verilog memory.
    //    Verilog-2001 allows variable indexing of memories.
    // ----------------------------------------------------------------
    wire [WIDTH-1:0] in_bus [0:31];

    assign in_bus[ 0] = input_0 ;
    assign in_bus[ 1] = input_1 ;
    assign in_bus[ 2] = input_2 ;
    assign in_bus[ 3] = input_3 ;
    assign in_bus[ 4] = input_4 ;
    assign in_bus[ 5] = input_5 ;
    assign in_bus[ 6] = input_6 ;
    assign in_bus[ 7] = input_7 ;
    assign in_bus[ 8] = input_8 ;
    assign in_bus[ 9] = input_9 ;
    assign in_bus[10] = input_10;
    assign in_bus[11] = input_11;
    assign in_bus[12] = input_12;
    assign in_bus[13] = input_13;
    assign in_bus[14] = input_14;
    assign in_bus[15] = input_15;
    assign in_bus[16] = input_16;
    assign in_bus[17] = input_17;
    assign in_bus[18] = input_18;
    assign in_bus[19] = input_19;
    assign in_bus[20] = input_20;
    assign in_bus[21] = input_21;
    assign in_bus[22] = input_22;
    assign in_bus[23] = input_23;
    assign in_bus[24] = input_24;
    assign in_bus[25] = input_25;
    assign in_bus[26] = input_26;
    assign in_bus[27] = input_27;
    assign in_bus[28] = input_28;
    assign in_bus[29] = input_29;
    assign in_bus[30] = input_30;
    assign in_bus[31] = input_31;

    // ----------------------------------------------------------------
    // 2) Variable-index read — synthesises to a wide 32-input mux.
    // ----------------------------------------------------------------
    assign output_value = in_bus[select];

endmodule
