// arrow.v
// Draws a single arrow at a given screen position and scale.
//
// Parameters (elaboration-time, fixed):
//   X_POS  : left edge in screen pixels (sx space)
//   Y_POS  : top  edge in screen pixels (sy space)
//   SCALE  : pixel multiplier (1=24x24px, 2=48x48px, ...)
//
// Ports (runtime, can be driven by wire/reg/LFSR):
//   dir    : 2-bit direction  0=→  1=↑  2=←  3=↓
//   sx, sy : current pixel coordinates (screen-relative, 10-bit)
//   pixel  : 1 when this pixel belongs to the arrow

`timescale 1ns / 1ps

module arrow #(
    parameter X_POS = 0,
    parameter Y_POS = 0,
    parameter SCALE = 1
)(
    input  [1:0] dir,
    input  [9:0] sx,
    input  [9:0] sy,
    output       pixel
);

    localparam W = 24 * SCALE;
    localparam H = 24 * SCALE;

    wire in_box = (sx >= X_POS) && (sx < X_POS + W) &&
                  (sy >= Y_POS) && (sy < Y_POS + H);

    wire [8:0] lx = sx - X_POS;
    wire [8:0] ly = sy - Y_POS;

    wire [4:0] col = lx / SCALE;
    wire [4:0] row = ly / SCALE;

    wire [4:0] row_dist = (row >= 5'd11) ? (row - 5'd11) : (5'd11 - row);
    wire [4:0] col_dist = (col >= 5'd11) ? (col - 5'd11) : (5'd11 - col);

    // Right (→): shaft row 9-14 col 0-15 | head col>=14, row_dist<=(23-col)
    wire px_right = in_box && (dir == 2'd0) && (
        ((col <= 5'd15) && (row >= 5'd9)  && (row <= 5'd14)) ||
        ((col >= 5'd14) && (row_dist <= (5'd23 - col)))
    );

    // Up (↑): shaft col 9-14 row 10-23 | head row<=11, col_dist<=row
    wire px_up = in_box && (dir == 2'd1) && (
        ((row >= 5'd10) && (col >= 5'd9)  && (col <= 5'd14)) ||
        ((row <= 5'd11) && (col_dist <= row))
    );

    // Left (←): shaft row 9-14 col 8-23 | head col<=9, row_dist<=col
    wire px_left = in_box && (dir == 2'd2) && (
        ((col >= 5'd8)  && (row >= 5'd9)  && (row <= 5'd14)) ||
        ((col <= 5'd9)  && (row_dist <= col))
    );

    // Down (↓): shaft col 9-14 row 0-13 | head row>=12, col_dist<=(23-row)
    wire px_down = in_box && (dir == 2'd3) && (
        ((row <= 5'd13) && (col >= 5'd9)  && (col <= 5'd14)) ||
        ((row >= 5'd12) && (col_dist <= (5'd23 - row)))
    );

    assign pixel = px_right | px_up | px_left | px_down;

endmodule