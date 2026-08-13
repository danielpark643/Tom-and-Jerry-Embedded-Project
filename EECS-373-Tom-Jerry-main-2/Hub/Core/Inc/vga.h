/*
 * vga.h
 *
 *  Created on: Apr 19, 2026
 *      Author: liujosh
 */

#ifndef INC_VGA_H_
#define INC_VGA_H_

#include "main.h"
#include <stdint.h>

uint8_t Vga_ArrowsReady(void);
void Vga_GetArrows(uint8_t*);
void Vga_Init(UART_HandleTypeDef *huart);
void Vga_StartRecv(void);
void Vga_SendData(CamData);
void Vga_Start(void);
void Vga_Stop(void);
void Vga_Win(void);
void Vga_Reset_Seq(void);
void Vga_RXCallBack(UART_HandleTypeDef *huart);

#endif /* INC_VGA_H_ */
