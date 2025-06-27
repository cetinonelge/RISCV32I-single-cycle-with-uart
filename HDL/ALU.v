// ============================================================
//  ALU  -  single-cycle RV32  (Verilog-2001, no SV syntax)
//  Adds custom  NOT  (invert rs1 → rd)  -  control = 4'b1010
// ============================================================
module ALU #(
    parameter WIDTH = 32                // RV32 datapath
)(
    input      [3:0]        control,    // ALU-control from controller
    input      [WIDTH-1:0]  DATA_A,     // RS1
    input      [WIDTH-1:0]  DATA_B,     // RS2 / immediate
    output reg [WIDTH-1:0]  OUT,        // result to datapath
    output reg              CO,         // carry-out  (ADD/SUB/JALR)
    output reg              OVF,        // signed overflow flag
    output                  N,          // negative  (OUT[31])
    output                  Zero        // OUT == 0
);

    //------------------------------------------------------------------
    // Operation codes (must match your controller/ALU-control table)
    //------------------------------------------------------------------
    localparam ADD   = 4'b0000,
               SUB   = 4'b1000,
               SLL   = 4'b0001,
               SLT   = 4'b0010,
               SLTU  = 4'b0011,
               XOR_  = 4'b0100,
               NOT_A = 4'b1010,   // *** new instruction ***
               SRL   = 4'b0101,
               SRA   = 4'b1101,
               OR_   = 4'b0110,
               MOVE  = 4'b1110,   // pass B   (used for LUI/AUIPC)
               AND_  = 4'b0111,
               JALR  = 4'b1111;

    // -----------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------
    wire signed [WIDTH-1:0] sA = DATA_A;
    wire signed [WIDTH-1:0] sB = DATA_B;
    reg [WIDTH-1:0] b_inv, b_twos;
    reg [WIDTH:0]   sum_sub;

    assign N    = OUT[WIDTH-1];
    assign Zero = ~|OUT;

    // -----------------------------------------------------------------
    // Combinational ALU
    // -----------------------------------------------------------------
    always @(*) begin

        // ----------- functional cases --------------------------------
        case (control)
            // ---------------- Logical --------------------------------
            AND_:  begin
                       OUT = DATA_A & DATA_B;
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            OR_ :  begin
                       OUT = DATA_A | DATA_B;
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            XOR_:  begin
                       OUT = DATA_A ^ DATA_B;
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            NOT_A: begin                    //  *** NEW extra instruction
                       OUT = ~DATA_A;
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            // ---------------- Arithmetic -----------------------------
            ADD :  begin
                       {CO,OUT} = DATA_A + DATA_B;
                       OVF      = (sA[WIDTH-1] == sB[WIDTH-1]) &&
                                 (OUT[WIDTH-1] != sA[WIDTH-1]);
                   end
            SUB: begin
                    // 1) form two's-complement of B
                    b_inv  = ~DATA_B;
                    b_twos = b_inv + 1'b1;

                    // 2) add A + (-B)
                    sum_sub = {1'b0, DATA_A} + {1'b0, b_twos};

                    // 3) result and flags
                    OUT  = sum_sub[WIDTH-1:0];
                    CO   = sum_sub[WIDTH];  // invert: CO=1 when A≥B, CO=0 when A<B
                    OVF  = (sA[WIDTH-1] != sB[WIDTH-1]) &&
                        (OUT[WIDTH-1] != sA[WIDTH-1]);
                end
            JALR: begin
                    // 1) raw add for PC+imm
                    { CO, sum_sub[WIDTH-1:0] } = DATA_A + DATA_B;
                    sum_sub[WIDTH]            = CO;

                    // 2) signed overflow computed on raw sum
                    OVF = (sA[WIDTH-1] == sB[WIDTH-1]) &&
                        (sum_sub[WIDTH-1] != sA[WIDTH-1]);

                    // 3) clear LSB of the 32-bit result
                    OUT = { sum_sub[WIDTH-1:1], 1'b0 };
                end
            // ---------------- Shifts ---------------------------------
            SLL :  begin
                       OUT = DATA_A << DATA_B[4:0];
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            SRL :  begin
                       OUT = DATA_A >> DATA_B[4:0];
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            SRA :  begin
                       OUT = sA >>> DATA_B[4:0];
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            // ---------------- Set-less-than ---------------------------
            SLT :  begin                     // signed
                       OUT = { {WIDTH-1{1'b0}},
                               (sA < sB) };
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            SLTU:  begin                     // unsigned
                       OUT = { {WIDTH-1{1'b0}},
                               (DATA_A < DATA_B) };
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            // ---------------- Pass-through ---------------------------
            MOVE:  begin
                       OUT = DATA_B;
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
            // ---------------- Default (NOP) --------------------------
            default: begin
                       OUT = {WIDTH{1'b0}};
                       CO  = 1'b0;
                       OVF = 1'b0;
                   end
        endcase
    end

endmodule
