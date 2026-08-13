// top.v
// Free-running counter[25:6] gives 20 bits of entropy to the LFSR.
// counter[25] toggles roughly every 0.67 seconds at 50 MHz —
// using bits [25:6] means the entropy word changes every ~13 microseconds,
// so the exact moment KEY[0] is released determines a very different value.

module top (
    input  CLOCK_50,
    input  [3:0]  KEY,
    input  [17:0] SW,
	 input  UART_RXD,
	 output UART_TXD,
    output VGA_HS,
    output VGA_VS,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK,
    output [17:0] LEDR
);

    wire clk25MHz;
    wire pll_locked;
    wire [3:0] w_red, w_green, w_blue;
    wire w_hsync, w_vsync;

    // Free-running counter — never reset, counts from power-on
    reg [25:0] counter = 0;
    always @(posedge CLOCK_50)
        counter <= counter + 1;

    // KEY[0] is active-low; invert for active-high reset
    wire reset = ~KEY[0];

    // Use counter bits [25:6] as the 20-bit entropy word.
    // These bits toggle fast enough that release timing always differs.
    wire [19:0] entropy = counter[25:6];

    //-----------------------------------------------------------------
    // PLL: 50 MHz -> 25 MHz
    ip ip1 (
        .areset (1'b0),
        .inclk0 (CLOCK_50),
        .c0     (clk25MHz),
        .locked (pll_locked)
    );

    //-----------------------------------------------------------------
    // Display
    display disp (
        .clk      (CLOCK_50),
        .clk25MHz (clk25MHz),
        .reset    (reset),
        .entropy  (entropy),
		  .btn_regen(~KEY[1]),
		  .UART_RXD (UART_RXD),
		  .UART_TXD (UART_TXD),
        .o_hsync  (w_hsync),
        .o_vsync  (w_vsync),
        .o_red    (w_red),
        .o_green  (w_green),
        .o_blue   (w_blue),
		  .LED_RX (LEDR[4])
    );

    //-----------------------------------------------------------------
    // VGA
    assign VGA_HS      = ~w_hsync;
    assign VGA_VS      = ~w_vsync;
    assign VGA_BLANK_N = ~(w_hsync | w_vsync);
    assign VGA_SYNC_N  = 1'b0;
    assign VGA_CLK     = clk25MHz;
    assign VGA_R       = {w_red,   4'h0};
    assign VGA_G       = {w_green, 4'h0};
    assign VGA_B       = {w_blue,  4'h0};

    //-----------------------------------------------------------------
    // LEDs
    assign LEDR[0]    = ~KEY[0];
    assign LEDR[1]    = ~KEY[1];
    assign LEDR[2]    = ~KEY[2];
    assign LEDR[3]    = ~KEY[3];
    assign LEDR[17:5] = SW[13:0];

endmodule