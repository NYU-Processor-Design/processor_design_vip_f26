// smoke test: .data, .rodata, .bss, stack, function calls, byte/half access, software mul/div (libgcc)
#define IO ((volatile unsigned *)0xC0000000u)
static int bss_var;                       // must be zero
volatile int data_var = 1234;               // preloaded
volatile const char msg[] = "chu";          // .rodata
volatile unsigned short half[2] = {0xBEEF, 0x1234};
static unsigned fib(unsigned n){ return n<2?n:fib(n-1)+fib(n-2); }
int main(void){
    int ok = 1;
    ok &= (bss_var == 0);
    ok &= (data_var == 1234);
    ok &= (msg[0]=='c' && msg[2]=='u');
    ok &= (half[0]==0xBEEF && half[1]==0x1234);
    ok &= (fib(10) == 55);
    volatile unsigned a = 1234, b = 7;
    ok &= (a*b == 8638) && (a/b == 176) && (a%b == 2);   // needs libgcc routines
    IO[0] = ok ? 1 : 0x2;                 // verdict register
    for(;;);
}
