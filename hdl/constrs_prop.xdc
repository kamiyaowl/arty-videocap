create_clock -period 10.000 -name clk_src_raw [get_ports clk_src_raw]
set_property IODELAY_GROUP tmds_rx [get_cells -filter {NAME=~ */*InputSERDES_X/InputDelay} -hier]
set_property IODELAY_GROUP tmds_rx [get_cells pt/idc]
set_false_path -to [get_pins -filter {NAME =~ */*sas*/sync_rst_src_b*/D} -hier]


