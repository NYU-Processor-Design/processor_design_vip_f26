// fpro_cores.h : one include for every driver.
//   #include "fpro/fpro_cores.h"    gives you all the classes below, plus the
//   two system objects `uart` and `sys_timer` (defined in fpro_init.cpp).
#ifndef FPRO_CORES_H
#define FPRO_CORES_H

#include "fpro_map.h"
#include "fpro_io.h"
#include "scratch_core.h"   // finished example
#include "gpio_core.h"      // assignment
#include "timer_core.h"     // assignment
#include "uart_core.h"      // assignment
#include "spi_core.h"       // assignment
#include "i2c_core.h"       // assignment
#include "pwm_core.h"       // assignment

extern UartCore  uart;          // console on slot S1_UART
extern TimerCore sys_timer;     // system time on slot S0_SYS_TIMER

unsigned long now_us();
unsigned long now_ms();
void sleep_us(unsigned long us);
void sleep_ms(unsigned long ms);

#endif
