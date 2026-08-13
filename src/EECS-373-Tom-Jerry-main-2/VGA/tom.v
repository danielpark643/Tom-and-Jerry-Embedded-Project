// tom.v
// Pixel-art sprite of Tom the cat.
// Grid: 17 columns x 26 rows, matching the source pixel art exactly.
// At SCALE=1 the sprite is 17x26 px.
//
// Parameters:
//   SCALE        : pixel multiplier (1 = 17x26 px, 2 = 34x52 px, ...)
//
// Outputs:
//   pixel        : 1 when this scan pixel is opaque
//   r, g, b      : 4-bit colour channels (valid when pixel=1)

`timescale 1ns / 1ps
module tom #(
    parameter SCALE = 1
)(
	 input  [8:0] tom_x,
	 input  [8:0] tom_y,
    input  [9:0] sx,
    input  [9:0] sy,
    output       pixel,
    output [3:0] r,
    output [3:0] g,
    output [3:0] b
);

    localparam COLS = 17;
    localparam ROWS = 26;
    localparam W    = COLS * SCALE;
    localparam H    = ROWS * SCALE;

    wire in_box = (sx >= tom_x) && (sx < tom_x + W) &&
                  (sy >= tom_y) && (sy < tom_y + H);

    wire [7:0] lx  = sx - tom_x;
    wire [7:0] ly  = sy - tom_y;
    wire [4:0] col = lx / SCALE;   // 0..16
    wire [4:0] row = ly / SCALE;   // 0..25

    // ------------------------------------------------------------------
    // Palette indices
    //  0 = transparent
    //  1 = dark grey   (outline)          r=3 g=3 b=3
    //  2 = mid grey    (main body)        r=8 g=8 b=8
    //  3 = light grey  (face highlight)   r=C g=C b=C
    //  4 = white       (muzzle/belly)     r=F g=F b=F
    //  5 = pink        (ear fill)         r=F g=9 b=A
    //  6 = dark pink   (inner ear)        r=C g=5 b=7
    //  7 = black       (pupil/nose)       r=0 g=0 b=0
    //  8 = yellow      (iris)             r=F g=E b=0
    //  9 = dark stripe (forehead/neck)    r=2 g=2 b=2

    // ------------------------------------------------------------------
    // Sprite ROM — 26 rows x 17 cols
    //
    // Row  0: 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0
    // Row  1: 1 2 1 1 0 0 0 0 0 0 0 0 0 1 1 2 1
    // Row  2: 1 5 2 2 1 0 0 0 0 0 0 0 1 2 2 2 1
    // Row  3: 1 5 5 2 2 1 1 0 0 0 1 1 2 2 2 2 1
    // Row  4: 1 5 5 2 2 2 2 1 1 1 2 2 2 2 2 2 1
    // Row  5: 1 5 2 5 2 2 2 2 2 2 2 2 2 2 2 2 1
    // Row  6: 0 1 5 5 2 1 1 2 2 2 1 1 2 2 2 1 0
    // Row  7: 0 0 1 2 2 8 8 2 2 2 8 8 2 2 1 0 0
    // Row  8: 0 1 2 2 8 1 8 2 2 2 8 1 8 2 2 1 0
    // Row  9: 1 2 2 2 8 1 1 2 2 2 1 1 8 2 2 2 1
    // Row 10: 0 1 2 2 2 2 4 4 1 4 4 2 2 2 2 1 0
    // Row 11: 0 0 1 1 4 4 4 4 4 4 4 4 4 1 1 0 0
    // Row 12: 0 0 0 0 1 1 4 4 4 4 4 1 1 0 0 0 0
    // Row 13: 0 0 0 0 0 0 1 1 1 1 1 0 0 0 0 0 0
    // Row 14: 0 0 0 0 0 1 2 2 2 2 2 1 0 0 0 0 0
    // Row 15: 0 0 0 0 1 2 2 2 4 2 2 2 1 0 0 0 0
    // Row 16: 0 0 0 1 2 2 4 4 4 4 4 2 2 1 0 0 0
    // Row 17: 0 0 1 2 2 2 4 4 4 4 4 2 2 2 1 0 0
    // Row 18: 0 1 2 2 2 1 4 4 4 4 4 1 2 2 2 1 0
    // Row 19: 0 1 4 4 1 1 4 4 4 4 4 1 1 4 4 1 0
    // Row 20: 0 0 1 1 0 1 4 4 4 4 4 1 0 1 1 0 0
    // Row 21: 0 0 0 0 0 1 2 2 2 2 2 1 0 0 0 0 0
    // Row 22: 0 0 0 0 0 1 2 2 1 2 2 1 0 0 0 0 0
    // Row 23: 0 0 0 0 0 1 2 1 0 1 2 1 0 0 0 0 0
    // Row 24: 0 0 0 0 1 4 4 1 0 1 4 4 1 0 0 0 0
    // Row 25: 0 0 0 0 0 1 1 0 0 0 1 1 0 0 0 0 0

    reg [3:0] palette_idx;

	 reg [3:0] sprite [0:ROWS*COLS-1];

	 initial begin
		 $readmemh("tom.mem", sprite);
	 end

	 wire [10:0] addr = row * COLS + col;

	 always @(*) begin
		 if (in_box)
			  palette_idx = sprite[addr];
		 else
			  palette_idx = 0;
	 end

    // ------------------------------------------------------------------
    // Palette → RGB (4-bit channels)
    reg [3:0] r_reg, g_reg, b_reg;
    always @(*) begin
        case (palette_idx)
            4'd1:  begin r_reg=4'h3; g_reg=4'h3; b_reg=4'h3; end  // dark grey outline
            4'd2:  begin r_reg=4'h8; g_reg=4'h8; b_reg=4'h8; end  // mid grey body
            4'd3:  begin r_reg=4'hC; g_reg=4'hC; b_reg=4'hC; end  // light grey face
            4'd4:  begin r_reg=4'hF; g_reg=4'hF; b_reg=4'hF; end  // white muzzle/belly
            4'd5:  begin r_reg=4'hF; g_reg=4'h9; b_reg=4'hA; end  // pink ear
            4'd6:  begin r_reg=4'hC; g_reg=4'h5; b_reg=4'h7; end  // dark pink inner ear
            4'd7:  begin r_reg=4'h0; g_reg=4'h0; b_reg=4'h0; end  // black pupil/nose
            4'd8:  begin r_reg=4'hF; g_reg=4'hE; b_reg=4'h0; end  // yellow iris
            4'd9:  begin r_reg=4'h2; g_reg=4'h2; b_reg=4'h2; end  // dark stripe
            default: begin r_reg=4'h0; g_reg=4'h0; b_reg=4'h0; end
        endcase
    end

    // ------------------------------------------------------------------
    wire opaque = in_box && (palette_idx != 4'd0);
    assign pixel = opaque;
    assign r     = opaque ? r_reg : 4'h0;
    assign g     = opaque ? g_reg : 4'h0;
    assign b     = opaque ? b_reg : 4'h0;

endmodule