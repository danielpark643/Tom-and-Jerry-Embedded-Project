// lfsr.v
// 20-bit Galois LFSR with an entropy input to break determinism.
//
// The problem with a plain LFSR reset:
//   Same seed + same number of warmup cycles = same output every time.
//
// The fix:
//   XOR an external entropy word into the LFSR register the moment reset
//   deasserts. Since the entropy input comes from a free-running counter in
//   top.v that has been counting since power-on, its value depends on the
//   exact moment the user releases KEY[0] — which varies every time.
//
// Ports:
//   clk        : 25 MHz pixel clock
//   reset      : active-high (held while KEY[0] is pressed)
//   entropy    : free-running bits from top.v (e.g. counter[25:6])
//   re_seed    : pulse high 1 cycle to re-randomize mid-game
//   out[19:0]  : stable random value, 2 bits per arrow x 10 arrows

`timescale 1ns / 1ps

module lfsr #(
    parameter SEED = 20'hACE1
)(
    input        clk,
    input        reset,
    input [19:0] entropy,   // wired to free-running counter bits in top.v
    input        re_seed,
    output [19:0] out
);

    reg [19:0] lfsr_reg = SEED;
    reg        prev_reset = 0;

    // Detect the falling edge of reset (moment user releases KEY[0])
    wire reset_falling = prev_reset && !reset;

    wire feedback = lfsr_reg[0];

    always @(posedge clk) begin
        prev_reset <= reset;

        if (reset) begin
            // While reset held: keep churning from seed so the internal
            // state is always moving while the button is pressed
            lfsr_reg    <= {feedback, lfsr_reg[19:1]};
            lfsr_reg[2] <= lfsr_reg[3] ^ feedback;
        end
        else if (reset_falling) begin
            // The instant reset releases: XOR in the entropy word.
            // This makes every release produce a different sequence
            // because the counter value is different every time.
            lfsr_reg <= lfsr_reg ^ entropy;
        end
        else if (re_seed) begin
            // Mid-game re-roll: shift once and XOR entropy again
            lfsr_reg    <= {feedback, lfsr_reg[19:1]} ^ entropy;
            lfsr_reg[2] <= lfsr_reg[3] ^ feedback;
        end
        // else: hold value — arrows stay stable on screen
    end

    assign out = lfsr_reg;

endmodule