#ifndef MOTORS_H
#define MOTORS_H

#include "main.h"

 void Motor_Init(void);
 void Motor_Stop(void);
 void Motor_Forward(uint16_t speed);
 void Motor_Reverse(uint16_t speed);
 void Motor_Left(uint16_t speed);
 void Motor_Right(uint16_t speed);
 
 extern TIM_HandleTypeDef htim4;
#endif