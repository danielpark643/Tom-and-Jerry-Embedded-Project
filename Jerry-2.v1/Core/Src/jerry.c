/*
 * jerry.c
 *
 *  Created on: Mar 24, 2026
 *      Author: danielpk
 */


#include "jerry.h"
#include "motors.h"
#include "led.h"
#include "lidar.h"
#include <stdlib.h>
#include <ctype.h>

#define WALL_CLOSE 325
#define SPEED 285
#define SLOW_SPEED 160
#define TURN_SPEED 250
#define TURN_90_MS 500 //time ms to turn 90 degrees
#define TURN_180_MS 750
//#define TURN_OVERSHOOT 80

#define SLOW_LIMIT_MS 1000U //stays slowed for 5s
#define RECOVERY_TIME_MS 7000U //recovery window is 15s
#define CAPTURE_SHOW_MS 2000U //capture state for 2s before resetting the game

static JerryState state = STATE_Init; //stores current state
static uint32_t state_enter_ms = 0; //remember when entered state
static uint32_t slow_start_ms = 0; //remember when first entered slow state
static uint32_t turn_cooldown_ms = 0;
static uint32_t turn_attempts = 0;
static uint32_t escape_ms = 0;
static uint32_t turn_start_ms = 0;
static uint8_t turn_direction = 0; //0 left, 1 right
static uint8_t blocked_count = 0;


static void Jerry_SetState(JerryState new_state)
{
    state = new_state;
    state_enter_ms = HAL_GetTick();

    if (new_state == STATE_Slow) {
        slow_start_ms = state_enter_ms;
    } else {
        slow_start_ms = 0;
    }
}

static void Jerry_RunAutonomous(uint16_t speed)
{
    uint16_t dist = Lidar_GetDistanceMM();

    if (dist == 0xFFFF) {
        Motor_Stop();
    }
    else if (dist > WALL_CLOSE) {
    	turn_attempts = 0;
        Motor_Forward(speed);
    }
    else {
        Motor_Stop();

        int choice = rand() % 10;
        if (choice < 7) {
            Motor_Left(TURN_SPEED);
            HAL_Delay(TURN_90_MS);
        } else {
            Motor_Right(TURN_SPEED);
            HAL_Delay(TURN_180_MS);
        }

        Motor_Stop();
        HAL_Delay(100);
    }
}

void Jerry_Init(void) {
	srand(HAL_GetTick()); //provide tick value in ms // every seed is different
	Jerry_SetState(STATE_Init);
}

void Jerry_Command(char cmd) {
	cmd = (char)toupper((unsigned char)cmd);
	switch (cmd) {
	case 'F':   // start/resume
	        Jerry_SetState(STATE_Moving);
	        break;

	    case 'L': //slow
	    	if (state == STATE_Moving || state == STATE_Turning || state == STATE_Slow) {
	    		if (state != STATE_Slow) {
	    			Jerry_SetState(STATE_Slow);
	    		}
	    	}
	        break;

	    case 'Z':   //frozen immedtaiely
	        Jerry_SetState(STATE_Frozen);
	        break;

	    case 'C':   //capture in recovery
	        if (state == STATE_Recovery) {
	            Jerry_SetState(STATE_Capture);
	        }
	        break;

	    case 'R':   //reset back to init / game restart
	        Jerry_SetState(STATE_Init);
	        break;

	    default:
	        break;

	}
}

void Jerry_Update(void) {
	uint16_t dist = Lidar_GetDistanceMM();
	switch (state) {
	case STATE_Init:
		Motor_Stop();
		BreathingStep(LED_COUNT);
		break;
	case STATE_Moving:
		SetState(LED_Moving);
		if ((int32_t)(HAL_GetTick() - escape_ms) < 0) {
		    Motor_Forward(SPEED);
		    break;
		}
		 if ((int32_t)(HAL_GetTick() - turn_cooldown_ms) < 0) {
		        Motor_Forward(SPEED);
		        break;
		    }
		if (dist == 0xFFFF) {
		    Motor_Stop();
		}
		else if (dist > WALL_CLOSE) {
		    blocked_count = 0;
		    turn_attempts = 0;
		    Motor_Forward(SPEED);
		}
		else {
		    blocked_count++;

		    if (blocked_count >= 2) {
		        blocked_count = 0;
		        Motor_Stop();
		        turn_start_ms = HAL_GetTick();
		        turn_direction = rand() % 2;
		        //turn_direction = 0;
		        Jerry_SetState(STATE_Turning);
		    } else {
		        Motor_Forward(SPEED);
		    }
		}
		break;
	case STATE_Turning:
	{
	    if (turn_direction == 0) {
	        Motor_Left(TURN_SPEED);
	    } else {
	        Motor_Right(TURN_SPEED);
	    }

	    //stop turning when no wall
	    if (dist != 0xFFFF && dist > WALL_CLOSE) {
//	        HAL_Delay(TURN_OVERSHOOT);
	        Motor_Stop();
	        HAL_Delay(130);
	        turn_attempts = 0;
	        turn_cooldown_ms = HAL_GetTick() + 200;
	        Jerry_SetState(STATE_Moving);
	        break;
	    }
	    if (HAL_GetTick() - turn_start_ms >= 1200) {
	        Motor_Stop();
	        HAL_Delay(100);

	        turn_attempts++;

	        if (turn_attempts >= 2) {
	            escape_ms = HAL_GetTick() + 500;
	            turn_attempts = 0;
	        }
	        turn_direction = !turn_direction;
	        Jerry_SetState(STATE_Moving);
	        break;
	    }
	    break;
	}
	case STATE_Slow:
		SetState(LED_Slow);
		Jerry_RunAutonomous(SLOW_SPEED);
		if ((HAL_GetTick() - slow_start_ms) >= SLOW_LIMIT_MS) {
			Jerry_SetState(STATE_Moving);
		}
		break;
	case STATE_Frozen:
		SetState(LED_Frozen);
		Motor_Stop();
		Jerry_SetState(STATE_Recovery);
		break;
	case STATE_Recovery:
		Motor_Stop();
		RecoveryStep(LED_COUNT, 20, 2, RECOVERY_TIME_MS, HAL_GetTick() - state_enter_ms);
		if ((HAL_GetTick() - state_enter_ms) >= RECOVERY_TIME_MS) {
			Jerry_SetState(STATE_Moving);
		}
		break;
	case STATE_Capture:
		SetState(LED_Capture);
		Motor_Stop();
		if ((HAL_GetTick() - state_enter_ms) >= CAPTURE_SHOW_MS) {
			Jerry_SetState(STATE_Init);
		}
		break;
	}

}



