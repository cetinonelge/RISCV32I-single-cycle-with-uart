// ------------------------------------------------------------
// 5-to-32 one-hot decoder  (Verilog-2001)
// OUT[i] == 1  when  IN == i
// ------------------------------------------------------------
module Decoder_5to32 (
    input  wire [4:0] IN,      // binary select
    output wire [31:0] OUT     // one-hot
);

    // A left-shift of 1 by IN places the ’1’ in the desired bit position.
    assign OUT = 32'h1 << IN;

endmodule
