/*
 * xbee.h
 *
 *  Created on: Apr 14, 2026
 *      Author: liujosh
 */

#ifndef INC_XBEE_H_
#define INC_XBEE_H_

#include "main.h"
#include <stdint.h>

typedef struct {
	float x1;
	float y1;
	float x2;
	float y2;
} CamData;

void XBee_Init(UART_HandleTypeDef *huart);
void XBee_StartRecv(void);
void XBee_SendString(const char *s);
CamData XBee_GetCamData(void);
uint8_t XBee_CamReady(void);
void XBee_ClearCamReady(void);
void XBee_ErrCallBack(UART_HandleTypeDef *huart);
void XBee_RXCallBack(UART_HandleTypeDef *huart);

#endif /* INC_XBEE_H_ */
