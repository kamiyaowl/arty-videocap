
create_clock -period 40.000 -name eth_tx_clk -waveform {0.000 20.000} [get_ports eth_tx_clk]
set_property CLOCK_DEDICATED_ROUTE TRUE [get_nets pt/clocking_des/inst/clk_out2]

set_false_path -from [get_clocks -of_objects [get_pins pt/clocking_des/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks eth_tx_clk]
set_false_path -from [get_pins pt/sas_g/rst_reg/C] -to [get_pins {be2e/af/rrst_reg[0]/D}]
set_false_path -from [get_clocks -of_objects [get_pins pt/clocking_des/inst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins pt/bufr_ser/O]]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 12 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
