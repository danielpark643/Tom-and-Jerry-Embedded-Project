module uart_cmds(
    input        clk,
    input        reset,

    // Physical UART pins
    input        UART_RXD,   // PIN_AB22 - receives from STM
    output       UART_TXD,   // PIN_AC15 - sends to STM

    // Coordinate outputs (from STM)
    output reg [8:0] tom_x,
    output reg [8:0] tom_y,
    output reg [8:0] jerry_x,
    output reg [8:0] jerry_y,
    output reg       packet_ready,

    // Command outputs (from STM)
    output reg       game_start,
    output reg       game_stop,
	 output reg			game_win,

    // Arrow sequence input (to send to STM)
	 output reg		arrows_reset,
    input [79:0]  arrows,
    input        send_arrows,
    output       arrows_busy,
	 
	 output reg LED_DEBUG
);

// ── RX ──────────────────────────────────────────────────────
wire [7:0] rx_data;
wire       rx_valid;

uart_rx u_rx (
    .clk     (clk),
    .reset   (reset),
    .UART_RXD(UART_RXD),
    .data    (rx_data),
    .valid   (rx_valid)
);

// Packet collector
// Headers: 0xFF 0xFF = coordinate packet
//          0xFF 0xAA = game start
//          0xFF 0xBB = game stop
//          0xFF 0xCC = game win
//          0xFF 0xDD = reset arrows
reg [7:0] rx_buf [0:7];
reg [7:0] rx_idx = 0;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        rx_idx       <= 0;
        packet_ready <= 0;
        game_start   <= 0;
        game_stop    <= 0;
		  game_win 		<= 0;
		  arrows_reset <= 0;
        LED_DEBUG    <= 0;
    end else begin
        packet_ready <= 0;
        game_start   <= 0;
        game_stop    <= 0;
		  game_win 		<= 0;
		  arrows_reset <= 0;

        if (rx_valid) begin
			 if (rx_data == 8'hFF) begin
				  rx_idx   <= 8'hFF;  // sentinel: waiting for second byte
			 end else if (rx_idx == 8'hFF) begin
				  // second byte determines packet type
				  if (rx_data == 8'hEE) begin
						rx_idx <= 0;  // coordinate packet, start collecting
				  end else if (rx_data == 8'hAA) begin
						game_start <= 1;
						rx_idx     <= 0;
				  end else if (rx_data == 8'hBB) begin
						game_stop <= 1;
						rx_idx    <= 0;
				  end else if (rx_data == 8'hCC) begin
						game_win <= 1;
						rx_idx <= 0;
				  end else if (rx_data == 8'hDD) begin
						arrows_reset <= 1;
						rx_idx <= 0;
				  end else begin
						rx_idx <= 0;  // unrecognized, reset
				  end
			 end else if (rx_idx < 8) begin
				  rx_buf[rx_idx] <= rx_data;
				  rx_idx         <= rx_idx + 1;
				  if (rx_idx == 7) begin
						LED_DEBUG <= 1; //RX Debugging
						tom_x        <= {rx_buf[0], rx_buf[1]};
						tom_y        <= {rx_buf[2], rx_buf[3]};
						jerry_x      <= {rx_buf[4], rx_buf[5]};
						jerry_y      <= {rx_buf[6], rx_data};
						packet_ready <= 1;
						rx_idx       <= 0;
				  end
			 end
		 end
    end
end

// ── TX ──────────────────────────────────────────────────────
reg  [7:0] tx_data  = 0;
reg        tx_start = 0;
wire       tx_busy;

uart_tx u_tx (
    .clk     (clk),
    .reset   (reset),
    .data    (tx_data),
    .start   (tx_start),
    .UART_TXD(UART_TXD),
    .busy    (tx_busy)
);

reg [3:0] tx_idx = 0;

localparam TX_IDLE    = 2'd0;
localparam TX_SENDING = 2'd1;
localparam TX_WAIT    = 2'd2;

reg [1:0] tx_state = TX_IDLE;

assign arrows_busy = (tx_state != TX_IDLE);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        tx_state  <= TX_IDLE;
        tx_start  <= 0;
        tx_idx    <= 0;
    end else begin
        tx_start <= 0;
        case (tx_state)
            TX_IDLE: begin
                if (send_arrows) begin
                    tx_idx   <= 0;
                    tx_state <= TX_SENDING;
                end
            end
            TX_SENDING: begin
                if (!tx_busy) begin
                    tx_data  <= arrows[tx_idx*8 +: 8];
                    tx_start <= 1;
                    tx_state <= TX_WAIT;
                end
            end
            TX_WAIT: begin
                if (!tx_busy && !tx_start) begin
                    if (tx_idx == 9)
                        tx_state <= TX_IDLE;
                    else begin
                        tx_idx   <= tx_idx + 1;
                        tx_state <= TX_SENDING;
                    end
                end

            end
        endcase
    end
end

endmodule
