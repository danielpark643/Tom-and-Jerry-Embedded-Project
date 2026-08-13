// char.v
// Draws a single character at a given screen position and scale.
//
// Parameters:
//   X_POS   : left edge in screen pixels (sx space)
//   Y_POS   : top  edge in screen pixels (sy space)
//   SCALE   : pixel multiplier (1=5x7px, 2=10x14px, 4=20x28px, ...)
//   CHAR_ID : 0=A  1=B  2=C  3=D  4=E  5=F  6=G  7=H  8=I  9=J
//             10=K 11=L 12=M 13=N 14=O 15=P 16=Q 17=R 18=S 19=T
//             20=U 21=V 22=W 23=X 24=Y 25=Z 26=space
//             (add more IDs for digits / punctuation if needed)
//
// Inputs:
//   sx, sy  : current pixel (screen-relative, 10-bit)
//
// Output:
//   pixel   : 1 if this pixel is a foreground (ink) pixel

`timescale 1ns / 1ps

module char #(
    parameter X_POS   = 0,
    parameter Y_POS   = 0,
    parameter SCALE   = 1,
    parameter CHAR_ID = 26   // default = space
)(
    input  [9:0] sx,
    input  [9:0] sy,
    output       pixel
);

    // Each character is 5 cols × 7 rows, stored as 7 × 5-bit rows (MSB = leftmost pixel).
    // Total 35 bits per character, packed into a 35-bit vector [34:0].
    // Bit [34] = row0 col0 (top-left), bit [0] = row6 col4 (bottom-right).

    localparam W = 5 * SCALE;
    localparam H = 7 * SCALE;

    wire in_box = (sx >= X_POS) && (sx < X_POS + W) &&
                  (sy >= Y_POS) && (sy < Y_POS + H);

    wire [8:0] lx = sx - X_POS;
    wire [8:0] ly = sy - Y_POS;

    wire [2:0] col = lx / SCALE;   // 0..4
    wire [2:0] row = ly / SCALE;   // 0..6

    // ----------------------------------------------------------------
    // 5×7 bitmaps — each row is 5 bits, MSB = left pixel
    // 7 rows packed: [34:30]=row0, [29:25]=row1, ... [4:0]=row6
    // ----------------------------------------------------------------
    reg [34:0] bitmap;

    always @(*) begin
        case (CHAR_ID)
            // A
            0:  bitmap = {5'b01110, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001};
            // B
            1:  bitmap = {5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10001, 5'b10001, 5'b11110};
            // C
            2:  bitmap = {5'b01110, 5'b10001, 5'b10000, 5'b10000, 5'b10000, 5'b10001, 5'b01110};
            // D
            3:  bitmap = {5'b11100, 5'b10010, 5'b10001, 5'b10001, 5'b10001, 5'b10010, 5'b11100};
            // E
            4:  bitmap = {5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b11111};
            // F
            5:  bitmap = {5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b10000};
            // G
            6:  bitmap = {5'b01110, 5'b10001, 5'b10000, 5'b10111, 5'b10001, 5'b10001, 5'b01111};
            // H
            7:  bitmap = {5'b10001, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001};
            // I
            8:  bitmap = {5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b11111};
            // J
            9:  bitmap = {5'b11111, 5'b00010, 5'b00010, 5'b00010, 5'b00010, 5'b10010, 5'b01100};
            // K
            10: bitmap = {5'b10001, 5'b10010, 5'b10100, 5'b11000, 5'b10100, 5'b10010, 5'b10001};
            // L
            11: bitmap = {5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b11111};
            // M
            12: bitmap = {5'b10001, 5'b11011, 5'b10101, 5'b10001, 5'b10001, 5'b10001, 5'b10001};
            // N
            13: bitmap = {5'b10001, 5'b11001, 5'b10101, 5'b10011, 5'b10001, 5'b10001, 5'b10001};
            // O
            14: bitmap = {5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110};
            // P
            15: bitmap = {5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10000, 5'b10000, 5'b10000};
            // Q
            16: bitmap = {5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10101, 5'b10010, 5'b01101};
            // R
            17: bitmap = {5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10100, 5'b10010, 5'b10001};
            // S
            18: bitmap = {5'b01111, 5'b10000, 5'b10000, 5'b01110, 5'b00001, 5'b00001, 5'b11110};
            // T
            19: bitmap = {5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100};
            // U
            20: bitmap = {5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110};
            // V
            21: bitmap = {5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01010, 5'b00100};
            // W
            22: bitmap = {5'b10001, 5'b10001, 5'b10001, 5'b10101, 5'b10101, 5'b11011, 5'b10001};
            // X
            23: bitmap = {5'b10001, 5'b10001, 5'b01010, 5'b00100, 5'b01010, 5'b10001, 5'b10001};
            // Y
            24: bitmap = {5'b10001, 5'b10001, 5'b01010, 5'b00100, 5'b00100, 5'b00100, 5'b00100};
            // Z
            25: bitmap = {5'b11111, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b10000, 5'b11111};
            // space (26) and default
            default: bitmap = 35'b0;
        endcase
    end

    // Extract the bit for the current (row, col)
    // bitmap[34:30] = row 0, bitmap[29:25] = row 1, ...
    // Within each row: bit[4] = col 0 (leftmost), bit[0] = col 4
    wire [4:0] row_bits = bitmap[34 - row*5 -: 5];
    wire       ink      = row_bits[4 - col];

    assign pixel = in_box && ink;

endmodule
