/*
 * led.h
 *
 *  Created on: Mar 21, 2026
 *      Author: anton
 */

#ifndef INC_LED_H_
#define INC_LED_H_
#include "main.h"
#define LED_COUNT 20
#include "stm32l4xx_hal.h"
#include "stm32l4xx_hal_spi.h"
extern SPI_HandleTypeDef hspi1;

typedef enum {
	LED_Init=0,
	LED_Ready, //green for a 1 or 2 seconds
	LED_Moving, //led is turned off
	LED_Slow, //dim light blue
	LED_Frozen, //bright blue
	LED_Recovering, //blue gets dimmer
	LED_Capture // red
} JerryLEDState;

 void StartFrame(void);
 void EndFrame(void);
 void SendLED(uint8_t brightness, uint8_t r, uint8_t g, uint8_t b);
 void ShowAll(uint8_t brightness, uint8_t r, uint8_t g, uint8_t b, uint16_t count);

 void SetState(JerryLEDState state);

 void BreathingStep(uint16_t count);
 void RecoveryStep(uint16_t count, uint8_t start_brightness, uint8_t end_brightness, uint32_t total_ms, uint32_t elapsed_ms);


#endif /* INC_LED_H_ */
