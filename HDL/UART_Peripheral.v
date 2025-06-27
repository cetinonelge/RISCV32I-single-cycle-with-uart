module UART_Peripheral #(
    parameter integer CLK_FREQ  = 100_000_000,   // Hz
    parameter integer BAUD_RATE = 9_600          // bits per second
)(
    input  wire        clk,
    input  wire        rst,

    // ------------- CPU-side interface ------------------------
    input  wire        write_en,                 // 1-cycle strobe
    input  wire [7:0]  write_data,

    input  wire        read_en,                  // 1-cycle strobe
    output reg  [31:0] read_data,                // byte in [7:0]

    // ------------- serial pins -------------------------------
    input  wire        uart_rx,
    output wire        uart_tx,
    output wire        tx_busy
);
    // =============== baud-rate divisor (rounded) ==============
    localparam integer BAUD_DIV =
        (CLK_FREQ + (BAUD_RATE/2)) / BAUD_RATE;   // integer round

    // -------------------- transmitter -------------------------
    reg [9:0]  tx_shift;                          // [stop][data][start]
    reg [3:0]  tx_cnt;
    reg [15:0] tx_div;
    reg        tx_active;
    reg        tx_out;

    assign uart_tx = tx_out;
    assign tx_busy = tx_active;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_shift  <= 10'h3FF;
            tx_cnt    <= 4'd0;
            tx_div    <= 16'd0;
            tx_active <= 1'b0;
            tx_out    <= 1'b1;                    // idle high
        end else begin
            // ---------- launch new frame ----------------------
            if (write_en && !tx_active) begin
                tx_shift  <= {1'b1, write_data, 1'b0};  // stop, data[7:0], start
                tx_cnt    <= 4'd0;
                tx_div    <= 16'd0;
                tx_active <= 1'b1;
            end
            // ---------- transmit frame ------------------------
            else if (tx_active) begin
                if (tx_div == BAUD_DIV-1) begin
                    tx_div   <= 16'd0;
                    tx_out   <= tx_shift[0];
                    tx_shift <= {1'b1, tx_shift[9:1]};   // shift in idle '1'
                    tx_cnt   <= tx_cnt + 1'b1;
                    if (tx_cnt == 4'd10) begin           // 1 start + 8 data + 1 stop
                        tx_active <= 1'b0;
                        tx_out    <= 1'b1;
                    end
                end else begin
                    tx_div <= tx_div + 1'b1;
                end
            end
        end
    end

    // ---------------- input synchroniser ----------------------
    reg rx_meta, rx_sync;
    always @(posedge clk) begin
        rx_meta <= uart_rx;
        rx_sync <= rx_meta;
    end

    // -------------------- receiver ----------------------------
    reg [9:0]  rx_shift;
    reg [3:0]  rx_cnt;
    reg [15:0] rx_div;
    reg        rx_active;

    // 16-byte FIFO
    reg [7:0]  fifo [0:15];
    reg [3:0]  fifo_head, fifo_tail;
    reg [4:0]  fifo_count;

    wire fifo_empty = (fifo_count == 0);
    wire fifo_full  = (fifo_count == 16);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_active  <= 1'b0;
            rx_div     <= 16'd0;
            rx_cnt     <= 4'd0;
            fifo_head  <= 4'd0;
            fifo_tail  <= 4'd0;
            fifo_count <= 5'd0;
            read_data  <= 32'hFFFF_FFFF;
        end else begin
            // -------- detect falling edge of start bit ---------
            if (!rx_active && (rx_sync == 1'b0)) begin
                rx_active <= 1'b1;
                rx_div    <= BAUD_DIV >> 1;           // 0.5 bit delay
                rx_cnt    <= 4'd0;
            end
            // -------- sample incoming bits ---------------------
            else if (rx_active) begin
                if (rx_div == BAUD_DIV-1) begin
                    rx_div   <= 16'd0;
                    rx_shift <= {rx_sync, rx_shift[9:1]};
                    rx_cnt   <= rx_cnt + 1'b1;

                    if (rx_cnt == 4'd9) begin         // stop bit sampled
                        rx_active <= 1'b0;
                        if (!fifo_full && (rx_sync == 1'b1)) begin
                            fifo[fifo_head] <= rx_shift[8:1];
                            fifo_head  <= fifo_head + 1'b1;
                            fifo_count <= fifo_count + 1'b1;
                        end
                    end
                end else begin
                    rx_div <= rx_div + 1'b1;
                end
            end

            // -------- CPU pop request --------------------------
            if (read_en) begin
                if (!fifo_empty) begin
                    read_data  <= {24'h0, fifo[fifo_tail]};
                    fifo_tail  <= fifo_tail + 1'b1;
                    fifo_count <= fifo_count - 1'b1;
                end else begin
                    read_data  <= 32'hFFFF_FFFF;      // empty indicator
                end
            end
        end
    end
endmodule