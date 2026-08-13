// jerry.v
// Pixel-art sprite of Jerry the mouse.
// Grid: 23 columns x 24 rows, matching the source pixel art exactly.
// At SCALE=1 the sprite is 23x24 px.
//
// Parameters:
//   X_POS, Y_POS : top-left in screen-space (sx/sy coords)
//   SCALE        : pixel multiplier (1 = 23x24 px, 2 = 46x48 px, ...)
//
// Outputs:
//   pixel        : 1 when this scan pixel is opaque
//   r, g, b      : 4-bit colour channels (valid when pixel=1)

`timescale 1ns / 1ps
module jerry #(
    parameter SCALE = 1
)(
    input  [8:0] jer_x,
	 input  [8:0] jer_y,
    input  [9:0] sx,
    input  [9:0] sy,
    output       pixel,
    output [3:0] r,
    output [3:0] g,
    output [3:0] b
);

    localparam COLS = 23;
    localparam ROWS = 24;
    localparam W    = COLS * SCALE;
    localparam H    = ROWS * SCALE;

    wire in_box = (sx >= jer_x) && (sx < jer_x + W) &&
                  (sy >= jer_y) && (sy < jer_y + H);

    wire [8:0] lx  = sx - jer_x;
    wire [8:0] ly  = sy - jer_y;
    wire [4:0] col = lx / SCALE;   // 0..22
    wire [4:0] row = ly / SCALE;   // 0..23

    // ------------------------------------------------------------------
    // Palette indices
    //  0 = transparent
    //  1 = dark brown  (outline/shadow)   r=5 g=2 b=0
    //  2 = mid brown   (main body)        r=9 g=5 b=2
    //  3 = light brown (belly/muzzle)     r=D g=9 b=6
    //  4 = pink        (ear fill)         r=F g=9 b=A
    //  5 = dark pink   (inner ear)        r=C g=5 b=7
    //  6 = black       (eye pupil)        r=0 g=0 b=0
    //  7 = white       (eye glint)        r=F g=F b=F

    // ------------------------------------------------------------------
    // Sprite ROM — 24 rows x 23 cols
    // Palette key per cell, transparent=0.
    //
	 // Row  0: . . . 1 1 1 . . . . . . . . . . . 1 1 1 . . .
    // Row  1: . . 1 2 2 2 1 . . . . . . . . . 1 2 2 2 1 . .
    // Row  2: . 1 4 4 2 2 2 1 . . . . . . . 1 2 2 2 4 4 1 .
    // Row  3: 1 4 4 4 4 2 2 1 . 1 1 1 1 1 . 1 2 2 4 4 4 4 1
    // Row  4: 1 4 4 4 4 2 2 2 1 2 2 2 2 2 1 2 2 2 4 4 4 4 1
    // Row  5: 1 4 4 4 4 2 2 2 2 2 2 2 2 2 2 2 2 2 4 4 4 4 1
    // Row  6: 1 4 4 2 4 2 2 2 2 2 2 2 2 2 2 2 2 2 4 2 4 4 1
    // Row  7: . 1 4 4 2 2 2 2 2 1 1 2 1 1 2 2 2 2 2 4 4 1 .
    // Row  8: . . 1 4 4 1 2 2 2 2 2 2 2 2 2 2 2 1 4 4 1 . .
    // Row  9: . . . 1 1 1 2 2 3 3 2 2 2 3 3 2 2 1 1 1 . . .
    // Row 10: . . . . . 1 2 3 1 1 2 2 2 1 1 3 2 1 . . . . .
    // Row 11: . . . . . 1 2 3 1 1 2 2 2 1 1 3 2 1 . . . . .
    // Row 12: . . . . . 1 2 2 2 3 3 1 3 3 2 2 2 1 . . . . .
    // Row 13: . . . . . . 1 2 3 3 3 3 3 3 3 2 1 . . . . . .
    // Row 14: . . . . . . . 1 2 3 3 3 3 3 2 1 . . . . . . .
    // Row 15: . . . . . . . . 1 1 1 1 1 1 1 . . . . . . . .
    // Row 16: . . . . . . . 1 2 2 2 2 2 2 2 1 . . . . . . .
    // Row 17: . . . . . . 1 2 2 2 3 2 3 2 2 2 1 . . . . . .
    // Row 18: . . . . . 1 . 1 1 2 3 3 3 2 1 1 . 1 . . . . .
    // Row 19: . . . . . . 1 . 1 2 3 3 3 2 1 . 1 . . . . . .
    // Row 20: . . . . . . . . 1 2 2 2 2 2 1 . . . . . . . .
    // Row 21: . . . . . . . . 1 2 1 1 1 2 1 . . . . . . . .
    // Row 22: . . . . . . . . 1 2 1 . 1 2 1 . . . . . . . .
    // Row 23: . . . . . . . . . 1 . . . 1 . . . . . . . . .

    reg [2:0] palette_idx;
	 
	 reg [2:0] sprite [0:ROWS*COLS-1];

	 initial begin
		 $readmemh("jerry.mem", sprite);
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
            3'd1:  begin r_reg=4'h5; g_reg=4'h2; b_reg=4'h0; end  // dark brown
            3'd2:  begin r_reg=4'h9; g_reg=4'h5; b_reg=4'h2; end  // mid brown
            3'd3:  begin r_reg=4'hD; g_reg=4'h9; b_reg=4'h6; end  // light brown / belly
            3'd4:  begin r_reg=4'hF; g_reg=4'h9; b_reg=4'hA; end  // pink ear
            3'd5:  begin r_reg=4'hC; g_reg=4'h5; b_reg=4'h7; end  // dark pink inner ear
            3'd6:  begin r_reg=4'h0; g_reg=4'h0; b_reg=4'h0; end  // black
            3'd7:  begin r_reg=4'hF; g_reg=4'hF; b_reg=4'hF; end  // white glint
            default: begin r_reg=4'h0; g_reg=4'h0; b_reg=4'h0; end
        endcase
    end

    // ------------------------------------------------------------------
    wire opaque = in_box && (palette_idx != 3'd0);
    assign pixel = opaque;
    assign r     = opaque ? r_reg : 4'h0;
    assign g     = opaque ? g_reg : 4'h0;
    assign b     = opaque ? b_reg : 4'h0;

endmodule