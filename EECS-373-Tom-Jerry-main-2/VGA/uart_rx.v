module uart_rx #(
    parameter CLK_FREQ  = 25000000,
    parameter BAUD_RATE = 115200
)(
    input        clk,
    input        reset,
    input        UART_RXD,
    output reg [7:0] data,
    output reg       valid
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

reg [9:0] clk_count = 0;
reg [3:0] bit_index = 0;
reg [7:0] rx_shift  = 0;
reg       rx_sync1  = 1;
reg       rx_sync2  = 1;

always @(posedge clk) begin
    rx_sync1 <= UART_RXD;
    rx_sync2 <= rx_sync1;
end

localparam IDLE  = 2'd0;
localparam START = 2'd1;
localparam DATA  = 2'd2;
localparam STOP  = 2'd3;

reg [1:0] state = IDLE;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state     <= IDLE;
        clk_count <= 0;
        bit_index <= 0;
        valid     <= 0;
        data      <= 0;
    end else begin
        valid <= 0;
        case (state)
            IDLE: begin
                clk_count <= 0;
                bit_index <= 0;
                if (rx_sync2 == 0)
                    state <= START;
            end
            START: begin
                if (clk_count == (CLKS_PER_BIT/2) - 1) begin
                    if (rx_sync2 == 0) begin
                        clk_count <= 0;
                        state     <= DATA;
                    end else
                        state <= IDLE;
                end else
                    clk_count <= clk_count + 1;
            end
            DATA: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count           <= 0;
                    rx_shift[bit_index] <= rx_sync2;
                    if (bit_index == 7) begin
                        bit_index <= 0;
                        state     <= STOP;
                    end else
                        bit_index <= bit_index + 1;
                end else
                    clk_count <= clk_count + 1;
            end
            STOP: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    if (rx_sync2 == 1) begin
                        valid <= 1;
                        data  <= rx_shift;
                    end
                    clk_count <= 0;
                    state     <= IDLE;
                end else
                    clk_count <= clk_count + 1;
            end
        endcase
    end
end
endmodule