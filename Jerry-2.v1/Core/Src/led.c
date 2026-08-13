/*
 * led.c
 *
 *  Created on: Mar 21, 2026
 *      Author: anton
 */

#include "led.h"



 void StartFrame(void){

	uint8_t start[4] = {0x00, 0x00, 0x00, 0x00}; //start frame of all zeros before led data is sent

	HAL_SPI_Transmit(&hspi1, start, 4, HAL_MAX_DELAY); // send 4 bit start data on spi1, pointer to start data buffer, 4 is amount of data sent, max delay waits until transmission is finished
}

 void EndFrame(void) {
	uint8_t end[4] = {0x00, 0x00, 0x00, 0x00};
	HAL_SPI_Transmit(&hspi1, end, 4, HAL_MAX_DELAY);
}

 void SendLED(uint8_t brightness, uint8_t r, uint8_t g, uint8_t b) {
	uint8_t frame[4];
	frame[0] = 0xE0 | brightness; // has to start 111
	frame[1] = b;
	frame[2] = g;
	frame[3] = r;

	HAL_SPI_Transmit(&hspi1, frame, 4, HAL_MAX_DELAY);
}

 void ShowAll(uint8_t brightness, uint8_t r, uint8_t g, uint8_t b, uint16_t count) {
	StartFrame();
	for (uint16_t i = 0; i < count; i++) {
		SendLED(brightness, r, g, b);
	}
	EndFrame();
}

 void SetState(JerryLEDState state) {
	switch (state) {
	case LED_Ready:
		ShowAll(12, 0, 255, 0, LED_COUNT); //green)
		break;
	case LED_Moving:
		ShowAll(0, 0, 0, 0, LED_COUNT); //led off
		break;
	case LED_Slow:
		ShowAll(4, 80, 180, 255, LED_COUNT); //dim light blue
		break;
	case LED_Frozen:
		ShowAll(20, 0, 80, 255, LED_COUNT); //blue
		break;
	case LED_Capture:
		ShowAll(16, 255, 0, 0, LED_COUNT); // red
		break;
	default:
		break;
	}
}



 void BreathingStep(uint16_t count) {
	 static uint32_t last_update;
	 static int brightness = 1;
	 static int dir = 1;

	 uint32_t now = HAL_GetTick();
	 if (now-last_update < 40) {
		 return;
	 }
	 last_update = now;

	 ShowAll((uint8_t)brightness, 255, 255, 255, count);

	 brightness += dir;
	 if (brightness >= 20) {
		 brightness = 20;
		 dir = -1;
	 }
	 else if (brightness <= 1) {
		 brightness = 1;
		 dir = 1;
	 }
 }

 void RecoveryStep(uint16_t count, uint8_t start_brightness, uint8_t end_brightness, uint32_t total_ms, uint32_t elapsed_ms) {
	 if (elapsed_ms >= total_ms) {
		 elapsed_ms = total_ms;
	 }
	 int delta = (int)end_brightness - (int)start_brightness;
	 uint8_t current = (uint8_t)(start_brightness + ((int32_t)delta * (int32_t)elapsed_ms) / (int32_t)total_ms);
	 ShowAll(current,0,80,255, count);
 }



