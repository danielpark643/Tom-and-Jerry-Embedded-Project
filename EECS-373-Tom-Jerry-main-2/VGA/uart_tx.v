module uart_tx #(
    parameter CLK_FREQ  = 25000000,
    parameter BAUD_RATE = 115200
)(
    input        clk,
    input        reset,
    input  [7:0] data,
    input        start,
    output reg   UART_TXD,
    output reg   busy
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

reg [9:0] clk_count = 0;
reg [3:0] bit_index = 0;
reg [7:0] tx_shift  = 0;

localparam IDLE  = 2'd0;
localparam START = 2'd1;
localparam DATA  = 2'd2;
localparam STOP  = 2'd3;

reg [1:0] state = IDLE;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state     <= IDLE;
        UART_TXD  <= 1;
        busy      <= 0;
        clk_count <= 0;
        bit_index <= 0;
    end else begin
        case (state)
            IDLE: begin
                UART_TXD  <= 1;
                busy      <= 0;
                clk_count <= 0;
                if (start) begin
                    tx_shift <= data;
                    busy     <= 1;
                    state    <= START;
                end
            end
            START: begin
                UART_TXD <= 0;
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    bit_index <= 0;
                    state     <= DATA;
                end else
                    clk_count <= clk_count + 1;
            end
            DATA: begin
                UART_TXD <= tx_shift[bit_index];
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    if (bit_index == 7)
                        state <= STOP;
                    else
                        bit_index <= bit_index + 1;
                end else
                    clk_count <= clk_count + 1;
            end
            STOP: begin
                UART_TXD <= 1;
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    busy      <= 0;
                    state     <= IDLE;
                end else
                    clk_count <= clk_count + 1;
            end
        endcase
    end
end
endmodule