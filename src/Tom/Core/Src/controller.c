/*
 * controller.c
 *
 *  Created on: Mar 24, 2026
 *      Author: tiffsc
 */


#include "controller.h"

#define PS2_ANALOG_MID 128
#define PS2_THRESHOLD 50
#define SPEED_MAX 2000
#define PS2_CS_PORT GPIOC
#define PS2_CS_PIN	GPIO_PIN_4

uint8_t ps2_rx[9];
uint8_t ps2_tx[9] = {
		0x01, // header
		0x42, // request data
		0x00, //idle
		0x00, //motor1
		0x00, //motor2
		0x00, 0x00, 0x00, 0x00//padding for analog
};

uint8_t enter_config[] = {0x01, 0x43, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00};
uint8_t set_analog[] = {0x01, 0x44, 0x00, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00};
uint8_t exit_config[] = {0x01, 0x43, 0x00, 0x00, 0x5A, 0x5A, 0x5A, 0x5A, 0x5A};

extern SPI_HandleTypeDef hspi1;

extern UART_HandleTypeDef hlpuart1;

static uint8_t rx_temp[9];


void PS2_Poll(uint8_t *tx, uint8_t *rx, uint8_t len) {
	HAL_GPIO_WritePin(PS2_CS_PORT,PS2_CS_PIN, GPIO_PIN_RESET); // CS is toggling for e
//	HAL_Delay(20);
	for (uint8_t i = 0; i < len; i++) {
	        HAL_SPI_TransmitReceive(&hspi1, &tx[i], &rx[i], 1, 100);
	        for(int delay=0; delay<500; delay++) __NOP(); // ~20-50us dela
	    }
	HAL_GPIO_WritePin(PS2_CS_PORT,PS2_CS_PIN, GPIO_PIN_SET);

//	ps2_send_cmd(ps2_tx, ps2_rx, 9);



}
// force analog
void PS2_Init_Analog(void) {
//	HAL_GPIO_WritePin(PS2_CS_PORT, PS2_CS_PIN, GPIO_PIN_SET);
//	HAL_Delay(100);

	PS2_Poll(enter_config, rx_temp, 9);
	HAL_Delay(10);

	PS2_Poll(set_analog, rx_temp, 9);
	HAL_Delay(10);

	PS2_Poll(exit_config, rx_temp, 9);
	HAL_Delay(10);

}



void PS2_Buttons(void) {

	//D-pad
	if(!(ps2_rx[3] & (1 << 4))) {
		HAL_UART_Transmit(&hlpuart1, (uint8_t*)"UP\r\n", 4, 100);
	}

	if(!(ps2_rx[3] & (1 << 6))) {
		HAL_UART_Transmit(&hlpuart1, (uint8_t*)"DOWN\r\n", 6, 100);
	}

	if(!(ps2_rx[3] & (1 << 7))) {
		HAL_UART_Transmit(&hlpuart1, (uint8_t*)"LEFT\r\n", 6, 100);
	}

	if(!(ps2_rx[3] & (1 << 5))) {
			HAL_UART_Transmit(&hlpuart1, (uint8_t*)"RIGHT\r\n", 7, 100);
	}



	if(!(ps2_rx[4] & (1 << 5))) {
		HAL_UART_Transmit(&hlpuart1, (uint8_t*)"FREEZE\r\n", 8, 100);
	} //circle



}

void PS2_GetJoystick(uint8_t *lx, uint8_t *ly) {
    *lx = ps2_rx[7];
    *ly = ps2_rx[8];
}



void Process_Remote_Movement(uint8_t lx, uint8_t ly) {
    int16_t dx = lx - PS2_ANALOG_MID;
    int16_t dy = ly - PS2_ANALOG_MID;

    int16_t abs_dx = (dx < 0) ? -dx : dx;
    int16_t abs_dy = (dy < 0) ? -dy : dy;

    if (abs_dy >= abs_dx && abs_dy > PS2_THRESHOLD) {
        uint16_t speed = (uint16_t)((uint32_t)abs_dy * SPEED_MAX / 128);
        if (dy < 0) Motor_Forward(speed);
        else        Motor_Reverse(speed);
    }
    else if (abs_dx > abs_dy && abs_dx > PS2_THRESHOLD) {
        uint16_t speed = (uint16_t)((uint32_t)abs_dx * SPEED_MAX / 128);
        if (dx < 0) Motor_Right(speed); // Note: verify if dx < 0 is Right or Left for your wiring
        else        Motor_Left(speed);
    }
    else {
        Motor_Stop();
    }
}





static uint8_t running = 0;
static uint8_t start_prev = 1;

void PS2_Control(void) {
	PS2_Poll(ps2_tx, ps2_rx, 9);
	PS2_Buttons();
	//PS2_Debug();

	if (ps2_rx[1] != 0x73 && ps2_rx[1] != 0x41) {
		Motor_Stop();
		return;
	}

	//start or stop the game using START button

	uint8_t start_now = ps2_rx[3] & (1 << 3);
	if(!start_now && start_prev) {
		running = !running;
	}
	start_prev = start_now;

	if(!running) {
		Motor_Stop();
		return;
	}



	//R2 = emergency stop
	if(!(ps2_rx[4] && (1 << 1))) {
		Motor_Brake();
		return;
	}


	uint8_t lx = ps2_rx[7];
	uint8_t ly = ps2_rx[8];

	int16_t dx = lx - PS2_ANALOG_MID;
	int16_t dy = ly - PS2_ANALOG_MID;

	int16_t abs_dx = (dx < 0) ? -dx : dx;
	int16_t abs_dy = (dy < 0) ? -dy : dy;

	if (abs_dy >= abs_dx && abs_dy > PS2_THRESHOLD){
		uint16_t speed = (uint16_t)((uint32_t)abs_dy * SPEED_MAX / 128);
		if (dy < 0) {
			Motor_Forward(speed);
		} else {
			Motor_Reverse(speed);
		}
	} else if (abs_dx > abs_dy && abs_dx > PS2_THRESHOLD){
		uint16_t speed = (uint16_t)((uint32_t)abs_dx * SPEED_MAX / 128);
		if (dx < 0) {
			Motor_Right(speed);
		} else {
			Motor_Left(speed);
		}
	} else {
		Motor_Stop();
	}
}

