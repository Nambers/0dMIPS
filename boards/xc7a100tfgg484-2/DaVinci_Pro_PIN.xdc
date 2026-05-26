#时序约束
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]

#IO引脚约束
#------------------------------系统时钟和复位-----------------------------------
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS15} [get_ports sys_clk]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS15} [get_ports sys_rst_n]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sys_clk]

#----------------------------------触摸按键-------------------------------------
set_property -dict {PACKAGE_PIN V8 IOSTANDARD LVCMOS15} [get_ports touch_key]

#----------------------------------按键-----------------------------------------
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS15} [get_ports {key[0]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS15} [get_ports {key[1]}]
set_property -dict {PACKAGE_PIN R6 IOSTANDARD LVCMOS15} [get_ports {key[2]}]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS15} [get_ports {key[3]}]

#-----------------------------------LED-----------------------------------------
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS15} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN Y8 IOSTANDARD LVCMOS15} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS15} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS15} [get_ports {led[3]}]

#-----------------------------------蜂鸣器--------------------------------------
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS15} [get_ports beep]

#-----------------------------------TF卡----------------------------------------
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports sd_miso]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports sd_mosi]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports sd_clk]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports sd_cs]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports sd_cd]

#-----------------------------------UART----------------------------------------
set_property -dict {PACKAGE_PIN E14 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports uart_txd]

#-----------------------------------RS485----------------------------------------
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports rs485_uart_rxd]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports rs485_uart_txd]

#-----------------------------------CAN----------------------------------------
set_property -dict {PACKAGE_PIN AA19 IOSTANDARD LVCMOS33} [get_ports can_rx]
set_property -dict {PACKAGE_PIN TR18 IOSTANDARD LVCMOS33} [get_ports can_tx]

#---------------------------------EEPROM----------------------------------------
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports iic_scl]
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS33} [get_ports iic_sda]

#---------------------------------RTC----------------------------------------
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports iic1_scl]
set_property -dict {PACKAGE_PIN A19 IOSTANDARD LVCMOS33} [get_ports iic1_sda]

#---------------------------------ATK MODULE----------------------------------------
set_property -dict {PACKAGE_PIN D16 IOSTANDARD LVCMOS33} [get_ports uart2_txd]
set_property -dict {PACKAGE_PIN E13 IOSTANDARD LVCMOS33} [get_ports uart2_rxd]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVCMOS33} [get_ports gbc_key]
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports gbc_led]

#---------------------------------OLED&CAMERA----------------------------------------
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33} [get_ports cmos_scl]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports cmos_sda]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports cmos_vsync]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports cmos_href]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports cmos_reset]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports cmos_d0]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports cmos_d1]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports cmos_d2]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports cmos_d3]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports cmos_d4]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports cmos_d5]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33} [get_ports cmos_d6]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports cmos_d7]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports cmos_pclk]
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD LVCMOS33} [get_ports cmos_pwdn]
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD LVCMOS33} [get_ports cmos_xclk]

#--------------------------------HDMI_A-----------------------------------------
set_property PACKAGE_PIN L19 [get_ports hdmi_clk_in]
create_clock -period 6.000 [get_ports hdmi_clk_in]
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets hdmi_clk_in]
set_property PACKAGE_PIN N19 [get_ports hdmi_rst_n_out]
set_property PACKAGE_PIN M21 [get_ports hdmi_de_in]
set_property PACKAGE_PIN M15 [get_ports hdmi_vs_in]
set_property PACKAGE_PIN M22 [get_ports hdmi_hs_in]
set_property PACKAGE_PIN H13 [get_ports {hdmi_data_in[0]}]
set_property PACKAGE_PIN G13 [get_ports {hdmi_data_in[1]}]
set_property PACKAGE_PIN J19 [get_ports {hdmi_data_in[2]}]
set_property PACKAGE_PIN H19 [get_ports {hdmi_data_in[3]}]
set_property PACKAGE_PIN G16 [get_ports {hdmi_data_in[4]}]
set_property PACKAGE_PIN G15 [get_ports {hdmi_data_in[5]}]
set_property PACKAGE_PIN G18 [get_ports {hdmi_data_in[6]}]
set_property PACKAGE_PIN G17 [get_ports {hdmi_data_in[7]}]
set_property PACKAGE_PIN L15 [get_ports {hdmi_data_in[8]}]
set_property PACKAGE_PIN K13 [get_ports {hdmi_data_in[9]}]
set_property PACKAGE_PIN K14 [get_ports {hdmi_data_in[10]}]
set_property PACKAGE_PIN J16 [get_ports {hdmi_data_in[11]}]
set_property PACKAGE_PIN J15 [get_ports {hdmi_data_in[12]}]
set_property PACKAGE_PIN H15 [get_ports {hdmi_data_in[13]}]
set_property PACKAGE_PIN J14 [get_ports {hdmi_data_in[14]}]
set_property PACKAGE_PIN H14 [get_ports {hdmi_data_in[15]}]
set_property PACKAGE_PIN M16 [get_ports {hdmi_data_in[16]}]
set_property PACKAGE_PIN L16 [get_ports {hdmi_data_in[17]}]
set_property PACKAGE_PIN K16 [get_ports {hdmi_data_in[18]}]
set_property PACKAGE_PIN K18 [get_ports {hdmi_data_in[19]}]
set_property PACKAGE_PIN K19 [get_ports {hdmi_data_in[20]}]
set_property PACKAGE_PIN M13 [get_ports {hdmi_data_in[21]}]
set_property PACKAGE_PIN L13 [get_ports {hdmi_data_in[22]}]
set_property PACKAGE_PIN L14 [get_ports {hdmi_data_in[23]}]

set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[17]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[20]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[21]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[22]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_data_in[23]}]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_clk_in]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_rst_n_out]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_de_in]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_vs_in]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_hs_in]

set_property PACKAGE_PIN L21 [get_ports hdmi_scl]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_scl]

set_property PACKAGE_PIN N18 [get_ports hdmi_sda]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_sda]

#--------------------------------HDMI_B----------------------------------------
set_property IOSTANDARD TMDS_33 [get_ports tmds_clk_n]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD TMDS_33} [get_ports tmds_clk_p]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[0]}]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[1]}]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {tmds_data_n[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {tmds_data_n[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {tmds_data_n[2]}]

#--------------------------------PCIe----------------------------------------
#PCIe reference clock 100MHz
set_property PACKAGE_PIN F6  [get_ports {pcie_ref_clk_p[0]}]

# PCIe MGT interface
set_property PACKAGE_PIN D9  [get_ports {pcie_mgt_rxp[0]}]
set_property PACKAGE_PIN B10 [get_ports {pcie_mgt_rxp[1]}]
set_property PACKAGE_PIN D7  [get_ports {pcie_mgt_txp[0]}]
set_property PACKAGE_PIN B6  [get_ports {pcie_mgt_txp[1]}]

# PCIe rst signal
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports pcie_rst_n]

#SPI 相关设置用于程序固化
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

#--------------------------------RGB LCD------------------------------------------
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[7]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[6]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[5]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[4]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[3]}]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[2]}]
set_property -dict {PACKAGE_PIN L13 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[1]}]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[0]}]

set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[15]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[14]}]
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[13]}]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[12]}]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[11]}]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[10]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[9]}]
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[8]}]

set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[16]}]
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[17]}]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[18]}]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[19]}]
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[20]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[21]}]
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[22]}]
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS33} [get_ports {lcd_rgb[23]}]

set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS33} [get_ports lcd_hs]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports lcd_vs]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports lcd_de]
set_property -dict {PACKAGE_PIN W9 IOSTANDARD LVCMOS15} [get_ports lcd_bl]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports lcd_pclk]
set_property -dict {PACKAGE_PIN Y9 IOSTANDARD LVCMOS15} [get_ports lcd_rst]

#--------------------------------OV5640摄像头------------------------------------------
create_clock -period 40.000 -name cmos_pclk [get_ports cam_pclk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports cam_pclk]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports cam_rst_n]
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD LVCMOS33} [get_ports cam_pwdn]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {cam_data[0]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {cam_data[1]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {cam_data[2]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {cam_data[3]}]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {cam_data[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {cam_data[5]}]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33} [get_ports {cam_data[6]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {cam_data[7]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports cam_vsync]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports cam_href]
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33} [get_ports cam_scl]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports cam_sda]

#-----------------------------------以太网-----------------------------------------
#-----------------------------------核心板-----------------------------------------
create_clock -period 8.000 -name eth_rxc_1 [get_ports eth_rxc_1]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33} [get_ports eth_rst_n]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports eth_rxc_1]
set_property -dict {PACKAGE_PIN Y21 IOSTANDARD LVCMOS33} [get_ports eth_rx_ctl_1]
set_property -dict {PACKAGE_PIN Y22 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_1[0]}]
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_1[1]}]
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_1[2]}]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_1[3]}]

set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports eth_txc_1]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS33} [get_ports eth_tx_ctl_1]
set_property -dict {PACKAGE_PIN W22 IOSTANDARD LVCMOS33} [get_ports {eth_txd_1[0]}]
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVCMOS33} [get_ports {eth_txd_1[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33} [get_ports {eth_txd_1[2]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS33} [get_ports {eth_txd_1[3]}]

set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports eth_mdc]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33} [get_ports eth_mdio]

#-----------------------------------底板-----------------------------------------

create_clock -period 8.000 -name eth_rxc_0 [get_ports eth_rxc_0]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports eth_rxc_0]
set_property -dict {PACKAGE_PIN AA20 IOSTANDARD LVCMOS33} [get_ports eth_rx_ctl_0]
set_property -dict {PACKAGE_PIN AA21 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_0[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_0[1]}]
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_0[2]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS33} [get_ports {eth_rxd_0[3]}]

set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports eth_txc_0]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports eth_tx_ctl_0]
set_property -dict {PACKAGE_PIN T21 IOSTANDARD LVCMOS33} [get_ports {eth_txd_0[0]}]
set_property -dict {PACKAGE_PIN U21 IOSTANDARD LVCMOS33} [get_ports {eth_txd_0[1]}]
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS33} [get_ports {eth_txd_0[2]}]
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports {eth_txd_0[3]}]


#-----------------------------------usb2.0-------------------------------------------
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {usb_data[0]}]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS33} [get_ports {usb_data[1]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {usb_data[2]}]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {usb_data[3]}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS33} [get_ports {usb_data[4]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33} [get_ports {usb_data[5]}]
set_property -dict {PACKAGE_PIN F21 IOSTANDARD LVCMOS33} [get_ports {usb_data[6]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS33} [get_ports {usb_data[7]}]

create_clock -period 16.000 [get_ports usb_clk_60m]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports usb_clk_60m]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS33} [get_ports usb_siwu_n]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33} [get_ports usb_rd_n]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33} [get_ports usb_wr_n]
set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS33} [get_ports usb_rxf_n]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports usb_txe_n]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports usb_oe_n]

#------------------------------------光口-------------------------------------------
set_property IOSTANDARD LVCMOS15 [get_ports {sfp_tx_disable[*]}]
set_property PACKAGE_PIN Y6 [get_ports {sfp_tx_disable[0]}]
set_property PACKAGE_PIN V5 [get_ports {sfp_tx_disable[1]}]
set_property PACKAGE_PIN F6 [get_ports {GTREFCLK0P_I[0]}]
set_property BEL IBUFDS_GTE2 [get_cells u_example_ibert_7series_gtp_0/u_buf_q0_clk1]
set_property LOC IBUFDS_GTE2_X0Y1 [get_cells u_example_ibert_7series_gtp_0/u_buf_q0_clk1]
set_property PACKAGE_PIN F10 [get_ports {GTREFCLK1P_I[0]}]
set_property PACKAGE_PIN C9 [get_ports {RXN_I[3]}]
set_property PACKAGE_PIN A10 [get_ports {RXN_I[2]}]
set_property PACKAGE_PIN C11 [get_ports {RXN_I[1]}]
set_property PACKAGE_PIN A8 [get_ports {RXN_I[0]}]

#------------------------------------SPI-------------------------------------------
#SPI 相关设置
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]

#SPI 管脚分配
#set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports {qspi_flash_ss_io[0]}]
#set_property -dict {PACKAGE_PIN P22 IOSTANDARD LVCMOS33} [get_ports qspi_flash_io0_io]
#set_property -dict {PACKAGE_PIN R22 IOSTANDARD LVCMOS33} [get_ports qspi_flash_io1_io]
#set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVCMOS33} [get_ports qspi_flash_io2_io]
#set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVCMOS33} [get_ports qspi_flash_io3_io]




#set_property CLOCK_DEDICATED_ROUTE FALSE [get_pins u_example_ibert_7series_gtp_0/u_ibert_core/inst/SYSCLK_DIVIDER.U_GT_MMCM]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_pins u_example_ibert_7series_gtp_0/u_ibert_core/inst/SYSCLK_DIVIDER.U_GT_MMCM/CLKIN1]

#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets  gtrefclk1_i[0]]
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets  gtrefclk0_i[0]]

#set_property BEL MMCME2_ADV [get_cells u_example_ibert_7series_gtp_0/u_ibert_core/inst/SYSCLK_DIVIDER.U_GT_MMCM]
#set_property BEL GTPE2_COMMON [get_cells {u_example_ibert_7series_gtp_0/u_ibert_core/inst/QUAD[0].u_q/u_common/u_gtpe2_common}]
#set_property LOC MMCME2_ADV_X0Y1 [get_cells u_example_ibert_7series_gtp_0/u_ibert_core/inst/SYSCLK_DIVIDER.U_GT_MMCM]
#set_property LOC GTPE2_COMMON_X0Y0 [get_cells {u_example_ibert_7series_gtp_0/u_ibert_core/inst/QUAD[0].u_q/u_common/u_gtpe2_common}]
#set_property FIXED_ROUTE { { IBUFDS_GTPE2_1_O  { GTPE2_COMMON_REFCLK1 GTPE2_COMMON_GTREFCLK1 }  IBUFDS_GTPE2_1_MGTCLKOUT GTPE2_COMMON_MGT_CLK5 CLK_HROW_CK_MUX_OUT_L2 CLK_HROW_CK_HCLK_OUT_L2 CLK_HROW_CK_BUFHCLK_L2 <13>HCLK_LEAF_CLK_B_TOP0 GCLK_B0_EAST CLK1 CMT_R_TOP_UPPER_B_CLKINT_3 HCLK_CMT_MUX_OUT_FREQ_REF3 HCLK_CMT_FREQ_REF_NS3 MMCM_CLK_FREQ_BB_REBUF3_NS PLL_CLK_FREQ_BB3_NS CMT_R_LOWER_B_CLK_FREQ_BB0 CMT_LR_LOWER_B_MMCM_CLKIN1 }  } [get_nets u_example_ibert_7series_gtp_0/gtrefclk1_i]
