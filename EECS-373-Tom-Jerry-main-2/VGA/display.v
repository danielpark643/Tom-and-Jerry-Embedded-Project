// display.v
`timescale 1ns / 1ps

// ============================================================
//  LAYOUT / POSITION DEFINES
// ============================================================
// Instruction screen layout
// Arena center X = ARENA_X + ARENA_W/2 = 164+155 = 319
// We'll center a ~260px wide block of text+icons
`define INSTR_X         180   // left edge of instruction block
`define INSTR_Y         155   // top of first line (inside arena)
`define INSTR_STRIDE_Y  26    // vertical spacing between lines
`define INSTR_SYM_SCALE 2     // symbol scale (12*2=24px wide)
`define INSTR_TXT_SCALE 2     // text scale
`define INSTR_TXT_STRIDE 12   // char stride at scale 2 (6*2)
`define INSTR_SYM_W     24    // 12*INSTR_SYM_SCALE
`define INSTR_GAP       6     // gap between symbol and text

`define VGA_H_START     10'd145
`define VGA_H_END       10'd783
`define VGA_V_START     10'd35
`define VGA_V_END       10'd514

`define TEXT_SCALE      4
`define TEXT_X          225
`define TEXT_Y          20
`define TEXT_STRIDE     24

`define ARROW_SCALE     2
`define ARROW_X         34
`define ARROW_Y         70
`define ARROW_STRIDE    58

// -- Arena --
`define ARENA_X         164
`define ARENA_Y         140
`define ARENA_W         310
`define ARENA_H         310
`define ARENA_BORDER    3

// -- Jerry: bottom-left of arena --
`define JERRY_SCALE     1
`define JERRY_X         (`ARENA_X + `ARENA_BORDER + 4)
`define JERRY_Y         (`ARENA_Y + `ARENA_H - `ARENA_BORDER - 24 - 4)

// -- Tom: top-right of arena --
`define TOM_SCALE       1
`define TOM_X           (`ARENA_X + `ARENA_W - `ARENA_BORDER - 17 - 4)
`define TOM_Y           (`ARENA_Y + `ARENA_BORDER + 4)

// -- Win screen text --
`define WIN_TEXT_SCALE  6
`define WIN_TEXT_STRIDE 36
`define WIN_TEXT_Y      200
`define WIN_TEXT_X      200  // 7 chars (with space) * 36 = 252, (638-252)/2 = 193 screen, -145 offset + some padding

// -- Win screen sprites --
`define WIN_TOM_X       `WIN_TEXT_X - 60
`define WIN_TOM_Y       `WIN_TEXT_Y
`define WIN_TOM_SCALE   2

`define WIN_JERRY_X     `WIN_TEXT_X + 252 + 20
`define WIN_JERRY_Y     `WIN_TEXT_Y
`define WIN_JERRY_SCALE 2

// ============================================================
//  COLOR DEFINES
// ============================================================

`define TEXT_R          4'h0
`define TEXT_G          4'h0
`define TEXT_B          4'h0

`define ARROW_R         4'h3
`define ARROW_G         4'h9
`define ARROW_B         4'hF

`define ARENA_R         4'h0
`define ARENA_G         4'hA
`define ARENA_B         4'hB

`define BORDER_R        4'h0
`define BORDER_G        4'h0
`define BORDER_B        4'h0

`define BG_R            4'hF
`define BG_G            4'hF
`define BG_B            4'hF

`define WIN_TEXT_R      4'hF
`define WIN_TEXT_G      4'hA
`define WIN_TEXT_B      4'h0

// ============================================================
//  MODULE
// ============================================================

module display(
    input  clk,
    input  clk25MHz,
    input  reset,
    input  [19:0] entropy,
    input  btn_regen,
    input  UART_RXD,
    output UART_TXD,
    output o_hsync,
    output o_vsync,
    output [3:0] o_red,
    output [3:0] o_blue,
    output [3:0] o_green,
    output reg LED_RX
);

    reg [9:0] counter_x = 0;
    reg [9:0] counter_y = 0;
    reg [3:0] r_red   = 0;
    reg [3:0] r_blue  = 0;
    reg [3:0] r_green = 0;

    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;

    wire [8:0] tom_x_coord;
    wire [8:0] tom_y_coord;
    wire [8:0] jer_x_coord;
    wire [8:0] jer_y_coord;
    wire       packet_ready;
    wire       game_start;
    wire       game_stop;
    wire       game_win;

    reg [79:0] arrows = 80'b0;
    reg [19:0] arrows_sample = 0;
    reg        send_arrows = 0;
    wire       arrows_busy;
    wire       arrows_reset;
    wire       led_debug_wire;

    uart_cmds u_cmds (
        .clk        (clk25MHz),
        .reset      (reset),
        .UART_RXD   (UART_RXD),
        .UART_TXD   (UART_TXD),
        .tom_x      (tom_x_coord),
        .tom_y      (tom_y_coord),
        .jerry_x    (jer_x_coord),
        .jerry_y    (jer_y_coord),
        .packet_ready(packet_ready),
        .game_start (game_start),
        .game_stop  (game_stop),
        .game_win   (game_win),
        .arrows_reset(arrows_reset),
        .arrows     (arrows),
        .send_arrows(send_arrows),
        .arrows_busy(arrows_busy),
        .LED_DEBUG  (led_debug_wire)
    );

    always @(posedge clk25MHz)
        if (counter_x < 799) counter_x <= counter_x + 1;
        else                  counter_x <= 0;

    always @(posedge clk25MHz)
        if (counter_x == 799) begin
            if (counter_y < 525) counter_y <= counter_y + 1;
            else                 counter_y <= 0;
        end

    assign o_hsync = (counter_x < 96) ? 1'b1 : 1'b0;
    assign o_vsync = (counter_y <  2) ? 1'b1 : 1'b0;

    wire [9:0] sx = counter_x - `VGA_H_START + 10'd1;
    wire [9:0] sy = counter_y - `VGA_V_START + 10'd1;

    wire [19:0] arrow_dirs;
    reg         re_seed_pulse = 0;
    reg         do_latch = 0;

    lfsr #(.SEED(20'hACE1)) rng (
        .clk    (clk25MHz),
        .reset  (reset),
        .entropy(entropy),
        .re_seed(re_seed_pulse),
        .out    (arrow_dirs)
    );

    //------------------------------------------------------------------
    // "SEQUENCE" text
    wire cS_px, cE0_px, cQ_px, cU_px, cE1_px, cN_px, cC_px, cE2_px;

    char #(.X_POS(`TEXT_X + 0*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(18)) cS  (.sx(sx),.sy(sy),.pixel(cS_px));
    char #(.X_POS(`TEXT_X + 1*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(4))  cE0 (.sx(sx),.sy(sy),.pixel(cE0_px));
    char #(.X_POS(`TEXT_X + 2*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(16)) cQ  (.sx(sx),.sy(sy),.pixel(cQ_px));
    char #(.X_POS(`TEXT_X + 3*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(20)) cU  (.sx(sx),.sy(sy),.pixel(cU_px));
    char #(.X_POS(`TEXT_X + 4*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(4))  cE1 (.sx(sx),.sy(sy),.pixel(cE1_px));
    char #(.X_POS(`TEXT_X + 5*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(13)) cN  (.sx(sx),.sy(sy),.pixel(cN_px));
    char #(.X_POS(`TEXT_X + 6*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(2))  cC  (.sx(sx),.sy(sy),.pixel(cC_px));
    char #(.X_POS(`TEXT_X + 7*`TEXT_STRIDE), .Y_POS(`TEXT_Y), .SCALE(`TEXT_SCALE), .CHAR_ID(4))  cE2 (.sx(sx),.sy(sy),.pixel(cE2_px));

    wire any_char = cS_px | cE0_px | cQ_px | cU_px | cE1_px | cN_px | cC_px | cE2_px;

    //------------------------------------------------------------------
    // "YOU WIN" text  Y=24 O=14 U=20 (space) W=22 I=8 N=13
    wire wY_px, wO_px, wU_px, wW_px, wI_px, wN_px;

    char #(.X_POS(`WIN_TEXT_X + 0*`WIN_TEXT_STRIDE), .Y_POS(`WIN_TEXT_Y), .SCALE(`WIN_TEXT_SCALE), .CHAR_ID(24)) wY (.sx(sx),.sy(sy),.pixel(wY_px));
    char #(.X_POS(`WIN_TEXT_X + 1*`WIN_TEXT_STRIDE), .Y_POS(`WIN_TEXT_Y), .SCALE(`WIN_TEXT_SCALE), .CHAR_ID(14)) wO (.sx(sx),.sy(sy),.pixel(wO_px));
    char #(.X_POS(`WIN_TEXT_X + 2*`WIN_TEXT_STRIDE), .Y_POS(`WIN_TEXT_Y), .SCALE(`WIN_TEXT_SCALE), .CHAR_ID(20)) wU (.sx(sx),.sy(sy),.pixel(wU_px));
    char #(.X_POS(`WIN_TEXT_X + 4*`WIN_TEXT_STRIDE), .Y_POS(`WIN_TEXT_Y), .SCALE(`WIN_TEXT_SCALE), .CHAR_ID(22)) wW (.sx(sx),.sy(sy),.pixel(wW_px));
    char #(.X_POS(`WIN_TEXT_X + 5*`WIN_TEXT_STRIDE), .Y_POS(`WIN_TEXT_Y), .SCALE(`WIN_TEXT_SCALE), .CHAR_ID(8))  wI (.sx(sx),.sy(sy),.pixel(wI_px));
    char #(.X_POS(`WIN_TEXT_X + 6*`WIN_TEXT_STRIDE), .Y_POS(`WIN_TEXT_Y), .SCALE(`WIN_TEXT_SCALE), .CHAR_ID(13)) wN (.sx(sx),.sy(sy),.pixel(wN_px));

    wire any_win_char = wY_px | wO_px | wU_px | wW_px | wI_px | wN_px;

    //------------------------------------------------------------------
    // 10 arrows
    reg  send_pulse = 0;
    wire arr0_px, arr1_px, arr2_px, arr3_px, arr4_px;
    wire arr5_px, arr6_px, arr7_px, arr8_px, arr9_px;

    arrow #(.X_POS(`ARROW_X + 0*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr0 (.dir(arrows[1:0]),   .sx(sx),.sy(sy),.pixel(arr0_px));
    arrow #(.X_POS(`ARROW_X + 1*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr1 (.dir(arrows[9:8]),   .sx(sx),.sy(sy),.pixel(arr1_px));
    arrow #(.X_POS(`ARROW_X + 2*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr2 (.dir(arrows[17:16]), .sx(sx),.sy(sy),.pixel(arr2_px));
    arrow #(.X_POS(`ARROW_X + 3*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr3 (.dir(arrows[25:24]), .sx(sx),.sy(sy),.pixel(arr3_px));
    arrow #(.X_POS(`ARROW_X + 4*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr4 (.dir(arrows[33:32]), .sx(sx),.sy(sy),.pixel(arr4_px));
    arrow #(.X_POS(`ARROW_X + 5*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr5 (.dir(arrows[41:40]), .sx(sx),.sy(sy),.pixel(arr5_px));
    arrow #(.X_POS(`ARROW_X + 6*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr6 (.dir(arrows[49:48]), .sx(sx),.sy(sy),.pixel(arr6_px));
    arrow #(.X_POS(`ARROW_X + 7*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr7 (.dir(arrows[57:56]), .sx(sx),.sy(sy),.pixel(arr7_px));
    arrow #(.X_POS(`ARROW_X + 8*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr8 (.dir(arrows[65:64]), .sx(sx),.sy(sy),.pixel(arr8_px));
    arrow #(.X_POS(`ARROW_X + 9*`ARROW_STRIDE), .Y_POS(`ARROW_Y), .SCALE(`ARROW_SCALE)) arr9 (.dir(arrows[73:72]), .sx(sx),.sy(sy),.pixel(arr9_px));

    wire any_arrow = arr0_px | arr1_px | arr2_px | arr3_px | arr4_px |
                     arr5_px | arr6_px | arr7_px | arr8_px | arr9_px;

    //------------------------------------------------------------------
    // Game sprites (arena)
    reg [8:0] jer_x_pos = `JERRY_X;
    reg [8:0] jer_y_pos = `JERRY_Y;
    reg       jer_visible = 0;
    wire        jerry_px;
    wire [3:0]  jerry_r, jerry_g, jerry_b;

    jerry #(.SCALE(`JERRY_SCALE)) u_jerry (
        .jer_x(jer_x_pos), .jer_y(jer_y_pos),
        .sx(sx), .sy(sy),
        .pixel(jerry_px),
        .r(jerry_r), .g(jerry_g), .b(jerry_b)
    );

    reg [8:0] tom_x_pos = 0;
    reg [8:0] tom_y_pos = `TOM_Y;
    reg       tom_visible = 0;
    wire        tom_px;
    wire [3:0]  tom_r, tom_g, tom_b;

    tom #(.SCALE(`TOM_SCALE)) u_tom (
        .tom_x(tom_x_pos), .tom_y(tom_y_pos),
        .sx(sx), .sy(sy),
        .pixel(tom_px),
        .r(tom_r), .g(tom_g), .b(tom_b)
    );

    //------------------------------------------------------------------
    // Win screen sprites (scale 2, fixed positions)
    wire        win_jerry_px;
    wire [3:0]  win_jerry_r, win_jerry_g, win_jerry_b;

    jerry #(.SCALE(`WIN_JERRY_SCALE)) u_jerry_win (
        .jer_x(`WIN_JERRY_X), .jer_y(`WIN_JERRY_Y),
        .sx(sx), .sy(sy),
        .pixel(win_jerry_px),
        .r(win_jerry_r), .g(win_jerry_g), .b(win_jerry_b)
    );

    wire        win_tom_px;
    wire [3:0]  win_tom_r, win_tom_g, win_tom_b;

    tom #(.SCALE(`WIN_TOM_SCALE)) u_tom_win (
        .tom_x(`WIN_TOM_X), .tom_y(`WIN_TOM_Y),
        .sx(sx), .sy(sy),
        .pixel(win_tom_px),
        .r(win_tom_r), .g(win_tom_g), .b(win_tom_b)
    );

    //------------------------------------------------------------------
// Instruction screen — shown when !game_active && !game_won
wire show_instr = !game_active && !game_won;

// ── Line 1: TRIANGLE to start game ──
localparam L1X = `INSTR_X;
localparam L1Y = `INSTR_Y + 0*`INSTR_STRIDE_Y;
localparam L1TX = L1X + 8*`INSTR_TXT_STRIDE + `INSTR_GAP;  // "TRIANGLE" is 8 chars wide

wire i1_s0,i1_s1,i1_s2,i1_s3,i1_s4,i1_s5,i1_s6,i1_s7;
// "TRIANGLE"
char #(.X_POS(L1X+0*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i1s0(.sx(sx),.sy(sy),.pixel(i1_s0));
char #(.X_POS(L1X+1*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i1s1(.sx(sx),.sy(sy),.pixel(i1_s1));
char #(.X_POS(L1X+2*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(8))  i1s2(.sx(sx),.sy(sy),.pixel(i1_s2));
char #(.X_POS(L1X+3*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(0))  i1s3(.sx(sx),.sy(sy),.pixel(i1_s3));
char #(.X_POS(L1X+4*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(13)) i1s4(.sx(sx),.sy(sy),.pixel(i1_s4));
char #(.X_POS(L1X+5*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(6))  i1s5(.sx(sx),.sy(sy),.pixel(i1_s5));
char #(.X_POS(L1X+6*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(11)) i1s6(.sx(sx),.sy(sy),.pixel(i1_s6));
char #(.X_POS(L1X+7*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i1s7(.sx(sx),.sy(sy),.pixel(i1_s7));
wire any_sym1 = i1_s0|i1_s1|i1_s2|i1_s3|i1_s4|i1_s5|i1_s6|i1_s7;

wire i1_c0,i1_c1,i1_c2,i1_c3,i1_c4,i1_c5,i1_c6,i1_c7,i1_c8,i1_c9,i1_c10;
// "TO START GAME"
char #(.X_POS(L1TX+ 0*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i1c0 (.sx(sx),.sy(sy),.pixel(i1_c0));
char #(.X_POS(L1TX+ 1*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(14)) i1c1 (.sx(sx),.sy(sy),.pixel(i1_c1));
char #(.X_POS(L1TX+ 3*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i1c2 (.sx(sx),.sy(sy),.pixel(i1_c2));
char #(.X_POS(L1TX+ 4*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i1c3 (.sx(sx),.sy(sy),.pixel(i1_c3));
char #(.X_POS(L1TX+ 5*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(0))  i1c4 (.sx(sx),.sy(sy),.pixel(i1_c4));
char #(.X_POS(L1TX+ 6*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i1c5 (.sx(sx),.sy(sy),.pixel(i1_c5));
char #(.X_POS(L1TX+ 7*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i1c6 (.sx(sx),.sy(sy),.pixel(i1_c6));
char #(.X_POS(L1TX+ 9*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(6))  i1c7 (.sx(sx),.sy(sy),.pixel(i1_c7));
char #(.X_POS(L1TX+10*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(0))  i1c8 (.sx(sx),.sy(sy),.pixel(i1_c8));
char #(.X_POS(L1TX+11*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(12)) i1c9 (.sx(sx),.sy(sy),.pixel(i1_c9));
char #(.X_POS(L1TX+12*`INSTR_TXT_STRIDE),.Y_POS(L1Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i1c10(.sx(sx),.sy(sy),.pixel(i1_c10));
wire any_instr1 = i1_c0|i1_c1|i1_c2|i1_c3|i1_c4|i1_c5|i1_c6|i1_c7|i1_c8|i1_c9|i1_c10;

// ── Line 2: JOYSTICK TO MOVE ──
localparam L2X = `INSTR_X;
localparam L2Y = `INSTR_Y + 1*`INSTR_STRIDE_Y;
localparam L2TX = L2X + 8*`INSTR_TXT_STRIDE + `INSTR_GAP;  // "JOYSTICK" is 8 chars wide

wire i2_s0,i2_s1,i2_s2,i2_s3,i2_s4,i2_s5,i2_s6,i2_s7;
// "JOYSTICK"
char #(.X_POS(L2X+0*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(9))  i2s0(.sx(sx),.sy(sy),.pixel(i2_s0));
char #(.X_POS(L2X+1*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(14)) i2s1(.sx(sx),.sy(sy),.pixel(i2_s1));
char #(.X_POS(L2X+2*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(24)) i2s2(.sx(sx),.sy(sy),.pixel(i2_s2));
char #(.X_POS(L2X+3*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i2s3(.sx(sx),.sy(sy),.pixel(i2_s3));
char #(.X_POS(L2X+4*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i2s4(.sx(sx),.sy(sy),.pixel(i2_s4));
char #(.X_POS(L2X+5*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(8))  i2s5(.sx(sx),.sy(sy),.pixel(i2_s5));
char #(.X_POS(L2X+6*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(2))  i2s6(.sx(sx),.sy(sy),.pixel(i2_s6));
char #(.X_POS(L2X+7*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(10)) i2s7(.sx(sx),.sy(sy),.pixel(i2_s7));
wire any_sym2 = i2_s0|i2_s1|i2_s2|i2_s3|i2_s4|i2_s5|i2_s6|i2_s7;

wire i2_c0,i2_c1,i2_c2,i2_c3,i2_c4,i2_c5;
// "TO MOVE"
char #(.X_POS(L2TX+0*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i2c0(.sx(sx),.sy(sy),.pixel(i2_c0));
char #(.X_POS(L2TX+1*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(14)) i2c1(.sx(sx),.sy(sy),.pixel(i2_c1));
char #(.X_POS(L2TX+3*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(12)) i2c2(.sx(sx),.sy(sy),.pixel(i2_c2));
char #(.X_POS(L2TX+4*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(14)) i2c3(.sx(sx),.sy(sy),.pixel(i2_c3));
char #(.X_POS(L2TX+5*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(21)) i2c4(.sx(sx),.sy(sy),.pixel(i2_c4));
char #(.X_POS(L2TX+6*`INSTR_TXT_STRIDE),.Y_POS(L2Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i2c5(.sx(sx),.sy(sy),.pixel(i2_c5));
wire any_instr2 = i2_c0|i2_c1|i2_c2|i2_c3|i2_c4|i2_c5;

// ── Line 3: CIRCLE TO FREEZE ──
localparam L3X = `INSTR_X;
localparam L3Y = `INSTR_Y + 2*`INSTR_STRIDE_Y;
localparam L3TX = L3X + 6*`INSTR_TXT_STRIDE + `INSTR_GAP;  // "CIRCLE" is 6 chars wide

wire i3_s0,i3_s1,i3_s2,i3_s3,i3_s4,i3_s5;
// "CIRCLE"
char #(.X_POS(L3X+0*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(2))  i3s0(.sx(sx),.sy(sy),.pixel(i3_s0));
char #(.X_POS(L3X+1*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(8))  i3s1(.sx(sx),.sy(sy),.pixel(i3_s1));
char #(.X_POS(L3X+2*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i3s2(.sx(sx),.sy(sy),.pixel(i3_s2));
char #(.X_POS(L3X+3*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(2))  i3s3(.sx(sx),.sy(sy),.pixel(i3_s3));
char #(.X_POS(L3X+4*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(11)) i3s4(.sx(sx),.sy(sy),.pixel(i3_s4));
char #(.X_POS(L3X+5*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i3s5(.sx(sx),.sy(sy),.pixel(i3_s5));
wire any_sym3 = i3_s0|i3_s1|i3_s2|i3_s3|i3_s4|i3_s5;

wire i3_c0,i3_c1,i3_c2,i3_c3,i3_c4,i3_c5,i3_c6,i3_c7;
// "TO FREEZE"
char #(.X_POS(L3TX+0*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i3c0(.sx(sx),.sy(sy),.pixel(i3_c0));
char #(.X_POS(L3TX+1*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(14)) i3c1(.sx(sx),.sy(sy),.pixel(i3_c1));
char #(.X_POS(L3TX+3*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(5))  i3c2(.sx(sx),.sy(sy),.pixel(i3_c2));
char #(.X_POS(L3TX+4*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i3c3(.sx(sx),.sy(sy),.pixel(i3_c3));
char #(.X_POS(L3TX+5*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i3c4(.sx(sx),.sy(sy),.pixel(i3_c4));
char #(.X_POS(L3TX+6*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i3c5(.sx(sx),.sy(sy),.pixel(i3_c5));
char #(.X_POS(L3TX+7*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(25)) i3c6(.sx(sx),.sy(sy),.pixel(i3_c6));
char #(.X_POS(L3TX+8*`INSTR_TXT_STRIDE),.Y_POS(L3Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i3c7(.sx(sx),.sy(sy),.pixel(i3_c7));
wire any_instr3 = i3_c0|i3_c1|i3_c2|i3_c3|i3_c4|i3_c5|i3_c6|i3_c7;

// ── Line 4: DPAD INPUT SEQUENCE ──
localparam L4X = `INSTR_X;
localparam L4Y = `INSTR_Y + 3*`INSTR_STRIDE_Y;
localparam L4TX = L4X + 4*`INSTR_TXT_STRIDE + `INSTR_GAP;  // "DPAD" is 4 chars wide

wire i4_s0,i4_s1,i4_s2,i4_s3;
// "DPAD"
char #(.X_POS(L4X+0*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(3))  i4s0(.sx(sx),.sy(sy),.pixel(i4_s0));
char #(.X_POS(L4X+1*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(15)) i4s1(.sx(sx),.sy(sy),.pixel(i4_s1));
char #(.X_POS(L4X+2*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(0))  i4s2(.sx(sx),.sy(sy),.pixel(i4_s2));
char #(.X_POS(L4X+3*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(3))  i4s3(.sx(sx),.sy(sy),.pixel(i4_s3));
wire any_sym4 = i4_s0|i4_s1|i4_s2|i4_s3;

wire i4_c0,i4_c1,i4_c2,i4_c3,i4_c4,i4_c5,i4_c6,i4_c7;
// "INPUT SEQ"
char #(.X_POS(L4TX+0*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(8))  i4c0(.sx(sx),.sy(sy),.pixel(i4_c0));
char #(.X_POS(L4TX+1*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(13)) i4c1(.sx(sx),.sy(sy),.pixel(i4_c1));
char #(.X_POS(L4TX+2*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(15)) i4c2(.sx(sx),.sy(sy),.pixel(i4_c2));
char #(.X_POS(L4TX+3*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(20)) i4c3(.sx(sx),.sy(sy),.pixel(i4_c3));
char #(.X_POS(L4TX+4*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i4c4(.sx(sx),.sy(sy),.pixel(i4_c4));
char #(.X_POS(L4TX+6*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i4c5(.sx(sx),.sy(sy),.pixel(i4_c5));
char #(.X_POS(L4TX+7*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i4c6(.sx(sx),.sy(sy),.pixel(i4_c6));
char #(.X_POS(L4TX+8*`INSTR_TXT_STRIDE),.Y_POS(L4Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(16)) i4c7(.sx(sx),.sy(sy),.pixel(i4_c7));
wire any_instr4 = i4_c0|i4_c1|i4_c2|i4_c3|i4_c4|i4_c5|i4_c6|i4_c7;

// ── Line 5: CROSS RESET INPUT ──
localparam L5X = `INSTR_X;
localparam L5Y = `INSTR_Y + 4*`INSTR_STRIDE_Y;
localparam L5TX = L5X + 5*`INSTR_TXT_STRIDE + `INSTR_GAP;  // "CROSS" is 5 chars wide

wire i5_s0,i5_s1,i5_s2,i5_s3,i5_s4;
// "CROSS"
char #(.X_POS(L5X+0*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(2))  i5s0(.sx(sx),.sy(sy),.pixel(i5_s0));
char #(.X_POS(L5X+1*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i5s1(.sx(sx),.sy(sy),.pixel(i5_s1));
char #(.X_POS(L5X+2*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(14)) i5s2(.sx(sx),.sy(sy),.pixel(i5_s2));
char #(.X_POS(L5X+3*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i5s3(.sx(sx),.sy(sy),.pixel(i5_s3));
char #(.X_POS(L5X+4*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i5s4(.sx(sx),.sy(sy),.pixel(i5_s4));
wire any_sym5 = i5_s0|i5_s1|i5_s2|i5_s3|i5_s4;

wire i5_c0,i5_c1,i5_c2,i5_c3,i5_c4,i5_c5,i5_c6,i5_c7,i5_c8,i5_c9;
// "RESET INPUT"
char #(.X_POS(L5TX+0*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i5c0(.sx(sx),.sy(sy),.pixel(i5_c0));
char #(.X_POS(L5TX+1*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i5c1(.sx(sx),.sy(sy),.pixel(i5_c1));
char #(.X_POS(L5TX+2*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i5c2(.sx(sx),.sy(sy),.pixel(i5_c2));
char #(.X_POS(L5TX+3*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i5c3(.sx(sx),.sy(sy),.pixel(i5_c3));
char #(.X_POS(L5TX+4*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i5c4(.sx(sx),.sy(sy),.pixel(i5_c4));
char #(.X_POS(L5TX+6*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(8))  i5c5(.sx(sx),.sy(sy),.pixel(i5_c5));
char #(.X_POS(L5TX+7*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(13)) i5c6(.sx(sx),.sy(sy),.pixel(i5_c6));
char #(.X_POS(L5TX+8*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(15)) i5c7(.sx(sx),.sy(sy),.pixel(i5_c7));
char #(.X_POS(L5TX+9*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(20)) i5c8(.sx(sx),.sy(sy),.pixel(i5_c8));
char #(.X_POS(L5TX+10*`INSTR_TXT_STRIDE),.Y_POS(L5Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i5c9(.sx(sx),.sy(sy),.pixel(i5_c9));
wire any_instr5 = i5_c0|i5_c1|i5_c2|i5_c3|i5_c4|i5_c5|i5_c6|i5_c7|i5_c8|i5_c9;

// ── Line 6: SQUARE RESET ──
localparam L6X = `INSTR_X;
localparam L6Y = `INSTR_Y + 5*`INSTR_STRIDE_Y;
localparam L6TX = L6X + 6*`INSTR_TXT_STRIDE + `INSTR_GAP;  // "SQUARE" is 6 chars wide

wire i6_s0,i6_s1,i6_s2,i6_s3,i6_s4,i6_s5;
// "SQUARE"
char #(.X_POS(L6X+0*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i6s0(.sx(sx),.sy(sy),.pixel(i6_s0));
char #(.X_POS(L6X+1*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(16)) i6s1(.sx(sx),.sy(sy),.pixel(i6_s1));
char #(.X_POS(L6X+2*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(20)) i6s2(.sx(sx),.sy(sy),.pixel(i6_s2));
char #(.X_POS(L6X+3*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(0))  i6s3(.sx(sx),.sy(sy),.pixel(i6_s3));
char #(.X_POS(L6X+4*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i6s4(.sx(sx),.sy(sy),.pixel(i6_s4));
char #(.X_POS(L6X+5*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i6s5(.sx(sx),.sy(sy),.pixel(i6_s5));
wire any_sym6 = i6_s0|i6_s1|i6_s2|i6_s3|i6_s4|i6_s5;

wire i6_c0,i6_c1,i6_c2,i6_c3,i6_c4;
// "RESET"
char #(.X_POS(L6TX+0*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(17)) i6c0(.sx(sx),.sy(sy),.pixel(i6_c0));
char #(.X_POS(L6TX+1*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i6c1(.sx(sx),.sy(sy),.pixel(i6_c1));
char #(.X_POS(L6TX+2*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(18)) i6c2(.sx(sx),.sy(sy),.pixel(i6_c2));
char #(.X_POS(L6TX+3*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(4))  i6c3(.sx(sx),.sy(sy),.pixel(i6_c3));
char #(.X_POS(L6TX+4*`INSTR_TXT_STRIDE),.Y_POS(L6Y),.SCALE(`INSTR_TXT_SCALE),.CHAR_ID(19)) i6c4(.sx(sx),.sy(sy),.pixel(i6_c4));
wire any_instr6 = i6_c0|i6_c1|i6_c2|i6_c3|i6_c4;

// combined — sym words rendered in orange, description text in black
wire any_sym   = any_sym1|any_sym2|any_sym3|any_sym4|any_sym5|any_sym6;
wire any_instr = any_instr1|any_instr2|any_instr3|any_instr4|any_instr5|any_instr6;

    //------------------------------------------------------------------
    // Arena
    wire in_arena  = (sx >= `ARENA_X && sx < (`ARENA_X + `ARENA_W) &&
                      sy >= `ARENA_Y && sy < (`ARENA_Y + `ARENA_H));
    wire in_inner  = (sx >= (`ARENA_X + `ARENA_BORDER) && sx < (`ARENA_X + `ARENA_W - `ARENA_BORDER) &&
                      sy >= (`ARENA_Y + `ARENA_BORDER) && sy < (`ARENA_Y + `ARENA_H - `ARENA_BORDER));
    wire border_px = in_arena & ~in_inner;
    wire arena_px  = in_inner;

    //------------------------------------------------------------------
    // Big red X overlay — shown for 1 second when arrows_reset goes high
    // Visible area is 638 x 479 pixels (sx: 0..637, sy: 0..478)
    // Draw two diagonals with 8px thickness using signed arithmetic
    reg        show_x  = 0;
    reg [24:0] x_timer = 0;

    // Compute signed differences to find distance from each diagonal
    wire signed [10:0] diag1 = $signed({1'b0, sx}) - $signed({1'b0, sy}); // TL->BR: sx==sy
    wire signed [10:0] diag2 = $signed({1'b0, sx}) + $signed({1'b0, sy}); // TR->BL: sx+sy==638
    wire [10:0] diag1_abs = diag1[10] ? (~diag1 + 1'b1) : diag1;
    wire [10:0] diag2_dist = (diag2 > 11'd638) ? (diag2 - 11'd638) : (11'd638 - diag2);
    wire big_x_px = show_x && ((diag1_abs < 11'd8) || (diag2_dist < 11'd8));

    //------------------------------------------------------------------
    reg game_active = 0;
    reg game_won    = 0;

    reg [19:0] debounce_cnt = 0;
    reg        btn_clean    = 0;
    reg        btn_prev     = 0;
    wire       btn_rising;

    always @(posedge clk25MHz or posedge reset) begin
        arrows_sample <= arrow_dirs;
        if (reset) begin
            debounce_cnt <= 0;
            btn_clean    <= 0;
            btn_prev     <= 0;
        end else begin
            btn_prev <= btn_clean;
            if (btn_regen != btn_clean)
                debounce_cnt <= debounce_cnt + 1;
            else
                debounce_cnt <= 0;
            if (debounce_cnt == 20'hFFFFF)
                btn_clean <= btn_regen;
        end
    end

    assign btn_rising = btn_clean & ~btn_prev;

    always @(posedge clk25MHz or posedge reset) begin
        if (reset) begin
            send_arrows   <= 0;
            re_seed_pulse <= 0;
            do_latch      <= 0;
            arrows        <= 80'b0;
            tom_x_pos     <= `TOM_X;
            tom_y_pos     <= `TOM_Y;
            jer_x_pos     <= `JERRY_X;
            jer_y_pos     <= `JERRY_Y;
            tom_visible   <= 0;
            jer_visible   <= 0;
            game_active   <= 0;
            game_won      <= 0;
            show_x        <= 0;
            x_timer       <= 0;
        end else begin

            send_arrows   <= 0;
            re_seed_pulse <= 0;
            do_latch      <= 0;

            // ── Red X timer ──
            if (arrows_reset) begin
                show_x  <= 1;
                x_timer <= 0;
            end else if (show_x) begin
                if (x_timer == 25'd24_999_999)
                    show_x <= 0;
                else
                    x_timer <= x_timer + 1;
            end

            if (game_start) begin
                tom_visible   <= 1;
                jer_visible   <= 1;
                game_active   <= 1;
                game_won      <= 0;
                re_seed_pulse <= 1;
                do_latch      <= 1;
            end

            if (game_stop) begin
                tom_visible <= 0;
                jer_visible <= 0;
                game_active <= 0;
                game_won    <= 0;
                arrows      <= 80'b0;
                tom_x_pos   <= `TOM_X;
                tom_y_pos   <= `TOM_Y;
                jer_x_pos   <= `JERRY_X;
                jer_y_pos   <= `JERRY_Y;
            end

            if (game_win) begin
                tom_visible <= 0;
                jer_visible <= 0;
                game_active <= 0;
                game_won    <= 1;
            end

            if (packet_ready && game_active) begin
                LED_RX    <= 1;
                tom_x_pos <= tom_x_coord + `ARENA_X + `ARENA_BORDER - 8;
                tom_y_pos <= tom_y_coord + `ARENA_Y + `ARENA_BORDER - 13;
                jer_x_pos <= jer_x_coord + `ARENA_X + `ARENA_BORDER - 11;
                jer_y_pos <= jer_y_coord + `ARENA_Y + `ARENA_BORDER - 12;
            end

            if ((btn_rising || arrows_reset) && game_active) begin
                LED_RX        <= 0;
                re_seed_pulse <= 1;
                do_latch      <= 1;
            end

            if (do_latch) begin
                arrows[7:0]   <= {6'b0, arrow_dirs[1:0]};
                arrows[15:8]  <= {6'b0, arrow_dirs[3:2]};
                arrows[23:16] <= {6'b0, arrow_dirs[5:4]};
                arrows[31:24] <= {6'b0, arrow_dirs[7:6]};
                arrows[39:32] <= {6'b0, arrow_dirs[9:8]};
                arrows[47:40] <= {6'b0, arrow_dirs[11:10]};
                arrows[55:48] <= {6'b0, arrow_dirs[13:12]};
                arrows[63:56] <= {6'b0, arrow_dirs[15:14]};
                arrows[71:64] <= {6'b0, arrow_dirs[17:16]};
                arrows[79:72] <= {6'b0, arrow_dirs[19:18]};
                send_arrows   <= 1;
            end

            // ── Win screen ──
            if (game_won) begin
                if (any_win_char) begin
                    r_red   <= `WIN_TEXT_R;
                    r_green <= `WIN_TEXT_G;
                    r_blue  <= `WIN_TEXT_B;
                end else if (win_tom_px) begin
                    r_red   <= win_tom_r;
                    r_green <= win_tom_g;
                    r_blue  <= win_tom_b;
                end else if (win_jerry_px) begin
                    r_red   <= win_jerry_r;
                    r_green <= win_jerry_g;
                    r_blue  <= win_jerry_b;
                end else begin
                    r_red   <= `BG_R;
                    r_green <= `BG_G;
                    r_blue  <= `BG_B;
                end
            end
            // ── Normal rendering ──
            else begin
                if (big_x_px) begin
                    // Red X overlay — highest priority
                    r_red   <= 4'hF;
                    r_green <= 4'h0;
                    r_blue  <= 4'h0;
                end else if (any_char && game_active) begin
                    r_red   <= `TEXT_R;
                    r_green <= `TEXT_G;
                    r_blue  <= `TEXT_B;
                end else if (any_arrow && game_active) begin
                    r_red   <= `ARROW_R;
                    r_green <= `ARROW_G;
                    r_blue  <= `ARROW_B;
                end else if (show_instr && any_sym) begin
                    r_red   <= 4'hF;
                    r_green <= 4'h5;
                    r_blue  <= 4'h0;  // orange symbols
                end else if (show_instr && any_instr) begin
                    r_red   <= 4'h0;
                    r_green <= 4'h0;
                    r_blue  <= 4'h0;  // black text
                end else if (jerry_px && jer_visible) begin
                    r_red   <= jerry_r;
                    r_green <= jerry_g;
                    r_blue  <= jerry_b;
                end else if (tom_px && tom_visible) begin
                    r_red   <= tom_r;
                    r_green <= tom_g;
                    r_blue  <= tom_b;
                end else if (border_px) begin
                    r_red   <= `BORDER_R;
                    r_green <= `BORDER_G;
                    r_blue  <= `BORDER_B;
                end else if (arena_px) begin
                    r_red   <= `ARENA_R;
                    r_green <= `ARENA_G;
                    r_blue  <= `ARENA_B;
                end else begin
                    r_red   <= `BG_R;
                    r_green <= `BG_G;
                    r_blue  <= `BG_B;
                end
            end
        end
    end

    wire visible = (counter_x > `VGA_H_START && counter_x <= `VGA_H_END &&
                    counter_y > `VGA_V_START  && counter_y <= `VGA_V_END);

    assign o_red   = visible ? r_red   : 4'h0;
    assign o_green = visible ? r_green : 4'h0;
    assign o_blue  = visible ? r_blue  : 4'h0;

endmodule