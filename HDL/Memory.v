module Memory
  #( parameter BYTE_SIZE   = 4,            // bytes / word
     parameter ADDR_WIDTH  = 32,           // address bus width
     parameter DEPTH       = 1024          // total bytes in memory
   )
   ( input                    clk,
     input                    WE,
     input  [ADDR_WIDTH-1:0]  ADDR,
     input  [(BYTE_SIZE*8)-1:0] WD,
     input  [1:0]             Size_Write,   // 00->1B, 01->2B, 10->4B, 11->8B
     output [(BYTE_SIZE*8)-1:0] RD
   );

   // ------------------------------------------------------------
   // 1. Memory array - one byte per element
   // ------------------------------------------------------------
   reg [7:0] mem [0:DEPTH-1]; //ascending form important while writing testbench

   // ------------------------------------------------------------
   // 2. Combinational read (asynchronous)
   // ------------------------------------------------------------
   genvar i;
   generate
      for (i = 0; i < BYTE_SIZE; i = i + 1) begin
         assign RD[8*i +: 8] = mem[ADDR + i];
      end
   endgenerate

   // ------------------------------------------------------------
   // 3. Byte-wise write on rising edge
   // ------------------------------------------------------------
   integer k;
   always @(posedge clk) begin
      if (WE) begin
         for (k = 0; k < BYTE_SIZE; k = k + 1)
            if (k < (1 << Size_Write)) begin
               mem[ADDR + k] <= WD[8*k +: 8];
            end
      end
   end
endmodule
