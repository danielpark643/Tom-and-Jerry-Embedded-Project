/*
 * motor.c
 *
 *  Created on: Mar 18, 2026
 *      Author: anton
 */


#include "motors.h"
	//Jerry: GPIO Pin0 = Right. GPIO Pin1 = Left
 void Motor_Init(void) {
	HAL_TIM_PWM_Start(&htim4, TIM_CHANNEL_3); //pb6 -> enB
	HAL_TIM_PWM_Start(&htim4, TIM_CHANNEL_4); //pb7 -> enA

	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_3, 0); //duty cycle to 0 - motor off
	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_4, 0);
}

 void Motor_Stop(void) {
	HAL_GPIO_WritePin(GPIOA, GPIO_PIN_3, GPIO_PIN_RESET); // set IN1 low
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_0, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_1, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_3, GPIO_PIN_RESET);

	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_3, 0); //duty cycle to 0 - motor off
	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_4, 0);
}

 void Motor_Left(uint16_t speed) {

	HAL_GPIO_WritePin(GPIOA, GPIO_PIN_3, GPIO_PIN_SET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_0, GPIO_PIN_RESET);

	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_1, GPIO_PIN_SET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_3, GPIO_PIN_RESET);

	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_3, speed);
	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_4, speed);
}

// Max speed is 2000
 void Motor_Right(uint16_t speed) {
	HAL_GPIO_WritePin(GPIOA, GPIO_PIN_3, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_0, GPIO_PIN_SET);

	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_1, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_3, GPIO_PIN_SET);

	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_3, speed);
	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_4, speed);
}

 void Motor_Reverse(uint16_t speed) {
	// Left Wheel
	HAL_GPIO_WritePin(GPIOA, GPIO_PIN_3, GPIO_PIN_SET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_0, GPIO_PIN_RESET);

	// Right Wheel
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_1, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_3, GPIO_PIN_SET);

	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_3, speed);
	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_4, speed);
}

 void Motor_Forward(uint16_t speed) {
	HAL_GPIO_WritePin(GPIOA, GPIO_PIN_3, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_0, GPIO_PIN_SET);

	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_1, GPIO_PIN_SET);
	HAL_GPIO_WritePin(GPIOC, GPIO_PIN_3, GPIO_PIN_RESET);

	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_3, speed);
	__HAL_TIM_SET_COMPARE(&htim4, TIM_CHANNEL_4, speed);
}

// void Motor_Brake(void){
//	 Motor_Reverse(1500);
//	 HAL_Delay(50);
//	 Motor_Stop();
//
// }
