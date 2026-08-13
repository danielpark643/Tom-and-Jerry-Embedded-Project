/*
 * controller.h
 *
 *  Created on: Mar 24, 2026
 *      Author: tiffsc
 */
#ifndef INC_CONTROLLER_H_
#define INC_CONTROLLER_H_

#include "stm32l4xx_hal.h"

void PS2_Init_Analog(void);
void PS2_Control(void);
void PS2_Poll(uint8_t *tx, uint8_t *rx, uint8_t len);
int16_t GetPixelCords(float x);
uint8_t Jer_Frozen(void);
void Jer_Unfreeze(void);
uint32_t Jer_FreezeTime(void);
void RunAway(void);

extern uint8_t ps2_rx[9];
extern uint8_t ps2_tx[9];


#endif /* INC_CONTROLLER_H_ */
