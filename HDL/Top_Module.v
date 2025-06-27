module Nexys_A7(
    //////////// GCLK //////////
    input wire                  CLK100MHZ,

    //////////// BTN //////////
    input wire BTNU, BTNL, BTNC, BTNR, BTND,

    //////////// SW //////////
    input wire [15:0] SW,

    //////////// LED //////////
    output wire [15:0] LED,

    //////////// 7 SEG //////////
    output wire [7:0] AN,
    output wire CA, CB, CC, CD, CE, CF, CG, DP,

    //////////// UART //////////
    input  wire UART_RXD_OUT,    // UART Rx pin from host
    output wire UART_TXD_IN      // UART Tx pin to host
);

    // Internal wires
    wire [31:0] reg_out, PC;
    wire [4:0] buttons;

    // Drive LEDs directly from switches
    assign LED = SW;

    // Display PC and part of reg_out on 7-segment
    MSSD mssd_0(
        .clk        (CLK100MHZ),
        .value      ({PC[7:0], reg_out[23:0]}),
        .dpValue    (8'b01000000),
        .display    ({CG, CF, CE, CD, CC, CB, CA}),
        .DP         (DP),
        .AN         (AN)
    );

    // Debounce buttons
    debouncer debouncer_0(
        .clk        (CLK100MHZ),
        .buttons    ({BTNU, BTNL, BTNC, BTNR, BTND}),
        .out        (buttons)
    );

    // Instantiate your processor (Single Cycle Computer)
    Single_Cycle_Computer my_computer(
        .clk                   (buttons[4]),
        .reset                 (buttons[0]),
        .Debug_Source_select   (SW[4:0]),             
        .Debug_out             (reg_out),
        .fetchPC               (PC),
        .uart_rx               (UART_RXD_OUT),      
        .uart_tx               (UART_TXD_IN),
        .uart_clk              (CLK100MHZ)
    );

endmodule
