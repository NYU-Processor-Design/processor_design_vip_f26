// fpro_init.cpp : the two system-wide cores (timer and UART) and the time
// helpers built on them. Compile this file into programs that use them.
// (They only work once your TimerCore and UartCore drivers work.)
#include "fpro_cores.h"

UartCore  uart(get_slot_addr(BRIDGE_BASE, S1_UART));
TimerCore sys_timer(get_slot_addr(BRIDGE_BASE, S0_SYS_TIMER));

unsigned long now_us()              { return (unsigned long)sys_timer.read_time_us(); }
unsigned long now_ms()              { return (unsigned long)(sys_timer.read_time_us() / 1000u); }
void sleep_us(unsigned long us)     { sys_timer.sleep_us((uint32_t)us); }
void sleep_ms(unsigned long ms)     { while (ms--) sys_timer.sleep_us(1000u); }
