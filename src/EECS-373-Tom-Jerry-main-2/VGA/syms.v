module sym_triangle #(parameter SCALE=2, parameter X_POS=0, parameter Y_POS=0)(
    input [9:0] sx, sy, output pixel
);
    localparam COLS=12, ROWS=12;
    wire in_box = (sx>=X_POS && sx<X_POS+COLS*SCALE && sy>=Y_POS && sy<Y_POS+ROWS*SCALE);
    wire [3:0] col = (sx-X_POS)/SCALE;
    wire [3:0] row = (sy-Y_POS)/SCALE;
    reg [11:0] bmp [0:11];
    initial begin
        bmp[0]  = 12'b000001100000;
        bmp[1]  = 12'b000011110000;
        bmp[2]  = 12'b000110011000;
        bmp[3]  = 12'b001100001100;
        bmp[4]  = 12'b011000000110;
        bmp[5]  = 12'b110000000011;
        bmp[6]  = 12'b111111111111;
        bmp[7]  = 12'b000000000000;
        bmp[8]  = 12'b000000000000;
        bmp[9]  = 12'b000000000000;
        bmp[10] = 12'b000000000000;
        bmp[11] = 12'b000000000000;
    end
    assign pixel = in_box && bmp[row][col];
endmodule

module sym_circle #(parameter SCALE=2, parameter X_POS=0, parameter Y_POS=0)(
    input [9:0] sx, sy, output pixel
);
    localparam COLS=12, ROWS=12;
    wire in_box = (sx>=X_POS && sx<X_POS+COLS*SCALE && sy>=Y_POS && sy<Y_POS+ROWS*SCALE);
    wire [3:0] col = (sx-X_POS)/SCALE;
    wire [3:0] row = (sy-Y_POS)/SCALE;
    reg [11:0] bmp [0:11];
    initial begin
        bmp[0]  = 12'b000111111000;
        bmp[1]  = 12'b011000000110;
        bmp[2]  = 12'b110000000011;
        bmp[3]  = 12'b100000000001;
        bmp[4]  = 12'b100000000001;
        bmp[5]  = 12'b100000000001;
        bmp[6]  = 12'b100000000001;
        bmp[7]  = 12'b100000000001;
        bmp[8]  = 12'b110000000011;
        bmp[9]  = 12'b011000000110;
        bmp[10] = 12'b000111111000;
        bmp[11] = 12'b000000000000;
    end
    assign pixel = in_box && bmp[row][col];
endmodule

module sym_cross #(parameter SCALE=2, parameter X_POS=0, parameter Y_POS=0)(
    input [9:0] sx, sy, output pixel
);
    localparam COLS=12, ROWS=12;
    wire in_box = (sx>=X_POS && sx<X_POS+COLS*SCALE && sy>=Y_POS && sy<Y_POS+ROWS*SCALE);
    wire [3:0] col = (sx-X_POS)/SCALE;
    wire [3:0] row = (sy-Y_POS)/SCALE;
    reg [11:0] bmp [0:11];
    initial begin
        bmp[0]  = 12'b110000000011;
        bmp[1]  = 12'b011000000110;
        bmp[2]  = 12'b001100001100;
        bmp[3]  = 12'b000110011000;
        bmp[4]  = 12'b000011110000;
        bmp[5]  = 12'b000001100000;
        bmp[6]  = 12'b000011110000;
        bmp[7]  = 12'b000110011000;
        bmp[8]  = 12'b001100001100;
        bmp[9]  = 12'b011000000110;
        bmp[10] = 12'b110000000011;
        bmp[11] = 12'b000000000000;
    end
    assign pixel = in_box && bmp[row][col];
endmodule

module sym_square #(parameter SCALE=2, parameter X_POS=0, parameter Y_POS=0)(
    input [9:0] sx, sy, output pixel
);
    localparam COLS=12, ROWS=12;
    wire in_box = (sx>=X_POS && sx<X_POS+COLS*SCALE && sy>=Y_POS && sy<Y_POS+ROWS*SCALE);
    wire [3:0] col = (sx-X_POS)/SCALE;
    wire [3:0] row = (sy-Y_POS)/SCALE;
    reg [11:0] bmp [0:11];
    initial begin
        bmp[0]  = 12'b111111111111;
        bmp[1]  = 12'b100000000001;
        bmp[2]  = 12'b100000000001;
        bmp[3]  = 12'b100000000001;
        bmp[4]  = 12'b100000000001;
        bmp[5]  = 12'b100000000001;
        bmp[6]  = 12'b100000000001;
        bmp[7]  = 12'b100000000001;
        bmp[8]  = 12'b100000000001;
        bmp[9]  = 12'b100000000001;
        bmp[10] = 12'b111111111111;
        bmp[11] = 12'b000000000000;
    end
    assign pixel = in_box && bmp[row][col];
endmodule

module sym_dpad #(parameter SCALE=2, parameter X_POS=0, parameter Y_POS=0)(
    input [9:0] sx, sy, output pixel
);
    localparam COLS=12, ROWS=12;
    wire in_box = (sx>=X_POS && sx<X_POS+COLS*SCALE && sy>=Y_POS && sy<Y_POS+ROWS*SCALE);
    wire [3:0] col = (sx-X_POS)/SCALE;
    wire [3:0] row = (sy-Y_POS)/SCALE;
    reg [11:0] bmp [0:11];
    initial begin
        bmp[0]  = 12'b000011110000;
        bmp[1]  = 12'b000011110000;
        bmp[2]  = 12'b000011110000;
        bmp[3]  = 12'b111111111111;
        bmp[4]  = 12'b111111111111;
        bmp[5]  = 12'b111111111111;
        bmp[6]  = 12'b111111111111;
        bmp[7]  = 12'b000011110000;
        bmp[8]  = 12'b000011110000;
        bmp[9]  = 12'b000011110000;
        bmp[10] = 12'b000000000000;
        bmp[11] = 12'b000000000000;
    end
    assign pixel = in_box && bmp[row][col];
endmodule

module sym_joystick #(parameter SCALE=2, parameter X_POS=0, parameter Y_POS=0)(
    input [9:0] sx, sy, output pixel
);
    localparam COLS=12, ROWS=12;
    wire in_box = (sx>=X_POS && sx<X_POS+COLS*SCALE && sy>=Y_POS && sy<Y_POS+ROWS*SCALE);
    wire [3:0] col = (sx-X_POS)/SCALE;
    wire [3:0] row = (sy-Y_POS)/SCALE;
    reg [11:0] bmp [0:11];
    initial begin
        bmp[0]  = 12'b000111111000;  // outer circle top
        bmp[1]  = 12'b011111111110;
        bmp[2]  = 12'b011111111110;
        bmp[3]  = 12'b011111111110;
        bmp[4]  = 12'b000111111000;  // outer circle bottom
        bmp[5]  = 12'b000001100000;  // stick
        bmp[6]  = 12'b000001100000;
        bmp[7]  = 12'b000111111000;  // base
        bmp[8]  = 12'b001111111100;
        bmp[9]  = 12'b001111111100;
        bmp[10] = 12'b000111111000;
        bmp[11] = 12'b000000000000;
    end
    assign pixel = in_box && bmp[row][col];
endmodule