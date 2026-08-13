/*
 * controller.h
 *
 *  Created on: Mar 24, 2026
 *      Author: tiffsc
 */

#ifndef INC_CONTROLLER_H_
#define INC_CONTROLLER_H_

#include "motors.h"

// force analog mode
void PS2_Init_Analog(void);

//initializes the PS2 driver
//poll the controller, call this once per iteration
void PS2_Poll(uint8_t *tx, uint8_t *rx, uint8_t len);
void PS2_Buttons(void);
void PS2_Control(void);

void PS2_GetJoystick(uint8_t *lx, uint8_t *ly);


#endif /* INC_CONTROLLER_H_ */
