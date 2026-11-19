## Arty A7-100T constraints for arty_top.sv
## Pins checked against Digilent's Arty-A7-100-Master.xdc (digilent-xdc repository).
## uart_rx = uart_txd_in (A9, FPGA input); uart_tx = uart_rxd_out (D10, FPGA output):
## Digilent names these from the PC's point of view.

## clock and reset
set_property -dict {PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports clk100]
create_clock -period 10.000 -name sys_clk -waveform {0 5} [get_ports clk100]
set_property -dict {PACKAGE_PIN C2  IOSTANDARD LVCMOS33} [get_ports reset_n]

## GPIO: switches SW0-SW3
set_property -dict {PACKAGE_PIN A8  IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]
## GPIO: buttons BTN0-BTN3
set_property -dict {PACKAGE_PIN D9  IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN C9  IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN B9  IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN B8  IOSTANDARD LVCMOS33} [get_ports {btn[3]}]
## GPIO: green LEDs LD4-LD7
set_property -dict {PACKAGE_PIN H5  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN J5  IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## UART: USB-UART bridge
set_property -dict {PACKAGE_PIN A9  IOSTANDARD LVCMOS33} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_tx]

## SPI: Pmod JA (pin 1 = SS0, 2 = MOSI, 3 = MISO, 4 = SCLK, 7 = SS1)
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports ja_ss0_n]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports ja_mosi]
set_property -dict {PACKAGE_PIN A11 IOSTANDARD LVCMOS33} [get_ports ja_miso]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33} [get_ports ja_sclk]
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports ja_ss1_n]

## I2C: shield header SCL / SDA (open drain) + pull-up enables
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports ck_scl]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports ck_sda]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports scl_pup]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVCMOS33} [get_ports sda_pup]

## PWM: RGB LEDs LD0 / LD1 (channels 0-5) and Pmod JD pins 1-2 (channels 6-7)
set_property -dict {PACKAGE_PIN G6  IOSTANDARD LVCMOS33} [get_ports led0_r]
set_property -dict {PACKAGE_PIN F6  IOSTANDARD LVCMOS33} [get_ports led0_g]
set_property -dict {PACKAGE_PIN E1  IOSTANDARD LVCMOS33} [get_ports led0_b]
set_property -dict {PACKAGE_PIN G3  IOSTANDARD LVCMOS33} [get_ports led1_r]
set_property -dict {PACKAGE_PIN J4  IOSTANDARD LVCMOS33} [get_ports led1_g]
set_property -dict {PACKAGE_PIN G4  IOSTANDARD LVCMOS33} [get_ports led1_b]
set_property -dict {PACKAGE_PIN D4  IOSTANDARD LVCMOS33} [get_ports {jd[0]}]
set_property -dict {PACKAGE_PIN D3  IOSTANDARD LVCMOS33} [get_ports {jd[1]}]

## asynchronous inputs: synchronized inside the design
set_false_path -from [get_ports {reset_n sw[*] btn[*] uart_rx ja_miso ck_scl ck_sda}]
