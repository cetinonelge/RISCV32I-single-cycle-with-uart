module Extender (
    output reg [31:0]Extended_data,
    input [24:0]DATA,
    input [2:0]select
);

localparam EXT_I = 3'd0,
           EXT_S = 3'd1,
           EXT_B = 3'd2,
           EXT_J = 3'd3,
           EXT_U = 3'd4;

always @(*) begin
    case (select)
        EXT_I:  Extended_data = {{20{DATA[24]}},  DATA[24:13]};                        // imm[11:0]
        EXT_S:  Extended_data = {{20{DATA[24]}},  DATA[24:18], DATA[4:0]};            // imm[11:5|4:0]
        EXT_B:  Extended_data = {{19{DATA[24]}},  // 19-bit sign fill
                           DATA[24],        // imm[12]  = inst[31]
                           DATA[0],         // imm[11]  = inst[7]
                           DATA[23:18],     // imm[10:5]= inst[30:25]
                           DATA[4:1], 1'b0};// imm[4:1]|0
        EXT_J:  Extended_data = {{11{DATA[24]}},  // 11-bit sign fill
                           DATA[24],        // imm[20]  = inst[31]
                           DATA[12:5],      // imm[19:12]=inst[19:12]
                           DATA[13],        // imm[11]  = inst[20]
                           DATA[23:14], 1'b0}; // imm[10:1]|0
        EXT_U:  Extended_data = {DATA[24:5], 12'b0};                                  // inst[31:12]<<12
        default: Extended_data = {DATA[24:5], 12'b0};                                 // inst[31:12]<<12
endcase
end
    
endmodule
