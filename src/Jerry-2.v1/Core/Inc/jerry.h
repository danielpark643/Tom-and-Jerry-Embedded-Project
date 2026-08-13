/*
 * jerry.h
 *
 *  Created on: Mar 24, 2026
 *      Author: danielpk
 */

#ifndef INC_JERRY_H_
#define INC_JERRY_H_

#include <stdint.h>

typedef enum {
	STATE_Init,
	STATE_Ready,
	STATE_Moving,
	STATE_Turning,
	STATE_Slow,
	STATE_Frozen,
	STATE_Recovery,
	STATE_Capture
} JerryState;

void Jerry_Init(void);
void Jerry_Update(void);
void Jerry_Command(char cmd);

#endif /* INC_JERRY_H_ */
