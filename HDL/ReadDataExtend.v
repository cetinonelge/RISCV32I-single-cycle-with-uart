//----------------------------------------------
// Load-data size / sign-extension unit
//----------------------------------------------
//  funct3  |  meaning        | action
// ---------+-----------------+------------------------------
//  3'b000  | LB   (byte  S)  | sign-extend   8 bits
//  3'b100  | LBU  (byte  U)  | zero-extend   8 bits
//  3'b001  | LH   (half  S)  | sign-extend  16 bits
//  3'b101  | LHU  (half  U)  | zero-extend  16 bits
//  3'b010  | LW              | no change (32 bits)
//----------------------------------------------
module ReadDataExtend
  #(parameter XLEN = 32)                       // RV32 → 32,  RV64 → 64
(
    input      [XLEN-1:0] in_word ,            // raw data from memory
    input      [2:0]      mode    ,            // = funct3[2:0] from LOAD
    output reg [XLEN-1:0] out_word             // properly extended result
);

    // localparam aliases to make the case statement easier to read
    localparam LD_B  = 3'b000,
               LD_H  = 3'b001,
               LD_W  = 3'b010,
               LD_BU = 3'b100,
               LD_HU = 3'b101;

    always @* begin
        case (mode)
            //---------------------------------- 8-bit results
            LD_B :  out_word = {{(XLEN-8){in_word[7] }},  in_word[7:0] }; // sign
            LD_BU:  out_word = {{(XLEN-8){1'b0       }},  in_word[7:0] }; // zero

            //--------------------------------- 16-bit results
            LD_H :  out_word = {{(XLEN-16){in_word[15]}}, in_word[15:0]}; // sign
            LD_HU:  out_word = {{(XLEN-16){1'b0}}, in_word[15:0]}; // zero

            //--------------------------------- full-word result (32 bits)
            default /* LD_W or reserved */:
                     out_word = in_word;                               // pass through
        endcase
    end

endmodule
