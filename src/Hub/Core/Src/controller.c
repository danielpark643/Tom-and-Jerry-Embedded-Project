/*
 * controller.c
 *
 *  Created on: Mar 24, 2026
 *      Author: tiffsc
 */
#include "controller.h"
#include "xbee.h"
#include "vga.h"
#include "addresses.h"
#include <math.h>
#include <string.h>

#define PS2_ANALOG_MID  128
#define PS2_THRESHOLD   50
#define SPEED_MAX       2000
#define PS2_CS_PORT     GPIOA
#define PS2_CS_PIN      GPIO_PIN_4

uint8_t ps2_rx[9];
uint8_t ps2_tx[9] = {
    0x01, // header
    0x42, // request data
    0x00, // idle
    0x00, // motor1
    0x00, // motor2
    0x00, 0x00, 0x00, 0x00 // padding for analog
};

uint8_t enter_config[] = {0x01, 0x43, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00};
uint8_t set_analog[]   = {0x01, 0x44, 0x00, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00};
uint8_t exit_config[]  = {0x01, 0x43, 0x00, 0x00, 0x5A, 0x5A, 0x5A, 0x5A, 0x5A};

extern SPI_HandleTypeDef  hspi1;
extern UART_HandleTypeDef huart2;

static uint8_t rx_temp[9];


void PS2_Poll(uint8_t *tx, uint8_t *rx, uint8_t len)
{
    HAL_GPIO_WritePin(PS2_CS_PORT, PS2_CS_PIN, GPIO_PIN_RESET);
    for (int d = 0; d < 500; d++) __NOP(); // CS setup time ~15us

    for (uint8_t i = 0; i < len; i++) {
        HAL_SPI_TransmitReceive(&hspi1, &tx[i], &rx[i], 1, 100);
        for (int d = 0; d < 500; d++) __NOP(); // inter-byte delay
    }

    for (int d = 0; d < 500; d++) __NOP(); // CS hold time
    HAL_GPIO_WritePin(PS2_CS_PORT, PS2_CS_PIN, GPIO_PIN_SET);
}

// force analog
void PS2_Init_Analog(void)
{
	HAL_GPIO_WritePin(PS2_CS_PORT, PS2_CS_PIN, GPIO_PIN_SET);
	HAL_Delay(50);  // let controller settle first

	// Wake up the controller first with a few normal polls
	for (int i = 0; i < 5; i++) {
		PS2_Poll(ps2_tx, rx_temp, 9);
		HAL_Delay(10);
	}

    PS2_Poll(enter_config, rx_temp, 9);
    HAL_Delay(10);
    PS2_Poll(set_analog, rx_temp, 9);
    HAL_Delay(10);
    PS2_Poll(exit_config, rx_temp, 9);
    HAL_Delay(10);
}

int16_t GetPixelCords(float x) {
	return (int16_t)((x+1.22) / 2.44f * 303);
}

static uint8_t gameStart = 0;
static uint32_t lastCirclePress = 0;

static uint8_t tri_prev = 0;
static uint8_t circle_prev = 0;
static uint8_t x_prev = 0;
static uint8_t sq_prev = 0;

#define DPAD_DEBOUNCE_MS 80
static uint8_t d_prev = 0;
static uint32_t lastDpadPress = 0;

static uint32_t freezeTime = 0;
static uint8_t frozen = 0;

static uint8_t arrow_input[NUM_ARROWS];
static uint32_t arrow_idx = 0;
static uint8_t won = 0;

static char last_sent_cmd = 'S'; // Keep track of Tom's current state

static uint32_t RunAwayTime = 0;

void RunAway() {
	RunAwayTime = HAL_GetTick() + 5000;
}

uint8_t Jer_Frozen() {
	return frozen;
}

void Jer_Unfreeze() {
	frozen = 0;
}

uint32_t Jer_FreezeTime() {
	return freezeTime;
}

/* -----------------------------------------------------------------------
 * PS2_Control
 * Main control loop — call this repeatedly from your while(1).
 * 1. Polls controller
 * 2. Sends XBee packet
 * 3. Handles Start toggle, R2 e-stop, and left-stick motor drive
 * ----------------------------------------------------------------------- */
void PS2_Control(void)
{
    PS2_Poll(ps2_tx, ps2_rx, 9);

    // No valid controller response
    if (ps2_rx[1] != 0x73 && ps2_rx[1] != 0x41) {
        return;
    }

    // Check buttons (active LOW, bit 5 of byte 4)
    uint8_t tri_pressed = !(ps2_rx[4] & (1 << 4));
    uint8_t circle_pressed = !(ps2_rx[4] & (1 << 5));
    uint8_t x_pressed = !(ps2_rx[4] & (1 << 6));
    uint8_t sq_pressed = !(ps2_rx[4] & (1 << 7));

    uint8_t d_up_pressed = !(ps2_rx[3] & (1 << 4));
	uint8_t d_right_pressed = !(ps2_rx[3] & (1 << 5));
	uint8_t d_down_pressed = !(ps2_rx[3] & (1 << 6));
	uint8_t d_left_pressed = !(ps2_rx[3] & (1 << 7));

    // Check joystick movement (either stick away from center)
    uint8_t lx = ps2_rx[7];
    uint8_t ly = ps2_rx[8];
    uint8_t rx = ps2_rx[5];
    uint8_t ry = ps2_rx[6];

    uint8_t joystick_moved = (lx < 78 || lx > 178 ||
							  ly < 78 || ly > 178 ||
							  rx < 78 || rx > 178 ||
							  ry < 78 || ry > 178);

    if (!gameStart) { // Game not started
    	if (tri_pressed && !tri_prev) { // Start
			gameStart = 1;
			Vga_Start();
			XBee_SendString("Jer F");
			HAL_GPIO_WritePin(GAME_START_LED, GAME_START_PIN, GPIO_PIN_SET);
		}
    } else if (sq_pressed && !sq_prev) { // Game Stop
    	lastCirclePress = 0;

    	tri_prev = 0;
    	circle_prev = 0;
    	x_prev = 0;
        sq_prev = 0;

		gameStart = 0;
		frozen = 0;
		last_sent_cmd = 'S';

		d_prev = 0;
		lastDpadPress = 0;

		freezeTime = 0;
		frozen = 0;

		arrow_idx = 0;
		won = 0;

		Vga_Stop();
		XBee_SendString("Jer R");
		HAL_GPIO_WritePin(GPIOC, GPIO_PIN_7, GPIO_PIN_RESET);
		HAL_GPIO_WritePin(GAME_START_LED, GAME_START_PIN, GPIO_PIN_RESET);
	} else if (frozen) {
    	// Use X to reset if seq messed up
    	if (x_pressed && !x_prev) {
    		arrow_idx = 0;
    	}

		// Key checks
		uint8_t d_active = 0;
		uint8_t d_dir = 0xFF;

		if      (d_up_pressed)    { d_active = 1; d_dir = 1; }
		else if (d_right_pressed) { d_active = 1; d_dir = 0; }
		else if (d_down_pressed)  { d_active = 1; d_dir = 3; }
		else if (d_left_pressed)  { d_active = 1; d_dir = 2; }

		// Rising edge + debounce guard
		if (d_active && !d_prev && (HAL_GetTick() - lastDpadPress >= DPAD_DEBOUNCE_MS)) {
		    arrow_input[arrow_idx++] = d_dir;
		    lastDpadPress = HAL_GetTick();
		}

		d_prev = d_active;

		if (arrow_idx == NUM_ARROWS) {
			uint8_t winSeq[NUM_ARROWS];
			while (Vga_ArrowsReady() == 0) {
				HAL_Delay(20);
			} // Wait until the arrows are ready to grab them for checking
			Vga_GetArrows(winSeq);

			// Assume win, change if sequence is wrong
			won = 1;
			for (int i = 0; i < NUM_ARROWS; ++i) {
				if (winSeq[i] != arrow_input[i]) {
					won = 0;
				}
			}

			if (won) {
				// Send win signal
				XBee_SendString("Jer C"); // Jerry captured
				Vga_Win();
				frozen = 0;
				HAL_GPIO_WritePin(GPIOB, GPIO_PIN_14, GPIO_PIN_SET);
			} else {
				Vga_Reset_Seq();
			}
			arrow_idx = 0;
		} // If (arrow_idx...)
    } else if (!won) { // Game started
    	char current_cmd = 'S'; // Default to Stop

    	if (joystick_moved) {
			int16_t dx = lx - PS2_ANALOG_MID;
			int16_t dy = ly - PS2_ANALOG_MID;
			int16_t abs_dx = (dx < 0) ? -dx : dx;
			int16_t abs_dy = (dy < 0) ? -dy : dy;

			if (abs_dy >= abs_dx && abs_dy > PS2_THRESHOLD) {
				current_cmd = (dy < 0) ? 'F' : 'B';
			}
			else if (abs_dx > abs_dy && abs_dx > PS2_THRESHOLD) {
				current_cmd = (dx < 0) ? 'L' : 'R';
			}
		}

		// ONLY send if the command has changed
		if (current_cmd != last_sent_cmd) {
			static char cmd_msg[] = "Tom  ";
			cmd_msg[4] = current_cmd;
			XBee_SendString(cmd_msg);
			last_sent_cmd = current_cmd;
		}

		if (circle_pressed && !circle_prev && HAL_GetTick() - lastCirclePress >= FREEZE_DELAY && ((int32_t)HAL_GetTick() - RunAwayTime >= 0)) { // Freeze
			 lastCirclePress = HAL_GetTick();
			 CamData camData = XBee_GetCamData();

			 int16_t x1 = GetPixelCords(camData.x1);
			 int16_t x2 = GetPixelCords(camData.x2);
			 int16_t y1 = GetPixelCords(camData.y1);
			 int16_t y2 = GetPixelCords(camData.y2);

			 float dx = (float)(x2 - x1);
			 float dy = (float)(y2 - y1);
			 int16_t dist_pixels = (int16_t)sqrtf(dx*dx + dy*dy);

			 // 38 pixels is 1ft
			 if (dist_pixels < 76) { // Freeze
				 frozen = 1;
				 freezeTime = HAL_GetTick();
				 HAL_GPIO_WritePin(GPIOC, GPIO_PIN_7, GPIO_PIN_SET);
				 XBee_SendString("Jer Z");
			 } else if (dist_pixels < 150) { // Slow
				 XBee_SendString("Jer L");
			 } // Otherwise don't send anything
		}
    }

    // Prev state tracking so only trigger XBee once per press
    tri_prev = tri_pressed;
    circle_prev = circle_pressed;
    x_prev = x_pressed;
    sq_prev = sq_pressed;
}
