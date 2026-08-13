/*
 * lidar.h
 *
 *  Created on: Mar 19, 2026
 *      Author: anton
 */

#ifndef INC_LIDAR_H_
#define INC_LIDAR_H_
#include "main.h"
#include "vl53l0x_api.h"
void Lidar_Init(I2C_HandleTypeDef *hi2c);
void Lidar_SetDataReady(void);
void Lidar_Process(void);
uint16_t Lidar_GetDistanceMM(void);

#endif /* INC_LIDAR_H_ */
