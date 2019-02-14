
create_clock -period 40.000 -name eth_tx_clk -waveform {0.000 20.000} [get_ports eth_tx_clk]
set_property CLOCK_DEDICATED_ROUTE TRUE [get_nets {pt/clk5x_des_nb}]
