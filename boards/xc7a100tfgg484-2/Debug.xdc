# DEBUG -- [optional]

set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets cpu_clk]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 63 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {core/IF_regs[fetch_pc][1]} {core/IF_regs[fetch_pc][2]} {core/IF_regs[fetch_pc][3]} {core/IF_regs[fetch_pc][4]} {core/IF_regs[fetch_pc][5]} {core/IF_regs[fetch_pc][6]} {core/IF_regs[fetch_pc][7]} {core/IF_regs[fetch_pc][8]} {core/IF_regs[fetch_pc][9]} {core/IF_regs[fetch_pc][10]} {core/IF_regs[fetch_pc][11]} {core/IF_regs[fetch_pc][12]} {core/IF_regs[fetch_pc][13]} {core/IF_regs[fetch_pc][14]} {core/IF_regs[fetch_pc][15]} {core/IF_regs[fetch_pc][16]} {core/IF_regs[fetch_pc][17]} {core/IF_regs[fetch_pc][18]} {core/IF_regs[fetch_pc][19]} {core/IF_regs[fetch_pc][20]} {core/IF_regs[fetch_pc][21]} {core/IF_regs[fetch_pc][22]} {core/IF_regs[fetch_pc][23]} {core/IF_regs[fetch_pc][24]} {core/IF_regs[fetch_pc][25]} {core/IF_regs[fetch_pc][26]} {core/IF_regs[fetch_pc][27]} {core/IF_regs[fetch_pc][28]} {core/IF_regs[fetch_pc][29]} {core/IF_regs[fetch_pc][30]} {core/IF_regs[fetch_pc][31]} {core/IF_regs[fetch_pc][32]} {core/IF_regs[fetch_pc][33]} {core/IF_regs[fetch_pc][34]} {core/IF_regs[fetch_pc][35]} {core/IF_regs[fetch_pc][36]} {core/IF_regs[fetch_pc][37]} {core/IF_regs[fetch_pc][38]} {core/IF_regs[fetch_pc][39]} {core/IF_regs[fetch_pc][40]} {core/IF_regs[fetch_pc][41]} {core/IF_regs[fetch_pc][42]} {core/IF_regs[fetch_pc][43]} {core/IF_regs[fetch_pc][44]} {core/IF_regs[fetch_pc][45]} {core/IF_regs[fetch_pc][46]} {core/IF_regs[fetch_pc][47]} {core/IF_regs[fetch_pc][48]} {core/IF_regs[fetch_pc][49]} {core/IF_regs[fetch_pc][50]} {core/IF_regs[fetch_pc][51]} {core/IF_regs[fetch_pc][52]} {core/IF_regs[fetch_pc][53]} {core/IF_regs[fetch_pc][54]} {core/IF_regs[fetch_pc][55]} {core/IF_regs[fetch_pc][56]} {core/IF_regs[fetch_pc][57]} {core/IF_regs[fetch_pc][58]} {core/IF_regs[fetch_pc][59]} {core/IF_regs[fetch_pc][60]} {core/IF_regs[fetch_pc][61]} {core/IF_regs[fetch_pc][62]} {core/IF_regs[fetch_pc][63]}]]
connect_debug_port u_ila_0/clk [get_nets [list cpu_clk]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 6 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {core/inst_req[mem_addr][0]} {core/inst_req[mem_addr][1]} {core/inst_req[mem_addr][2]} {core/inst_req[mem_addr][3]} {core/inst_req[mem_addr][4]} {core/inst_req[mem_addr][5]}]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 6 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {data_mem/data_seg_xpm/addrb[0]} {data_mem/data_seg_xpm/addrb[1]} {data_mem/data_seg_xpm/addrb[2]} {data_mem/data_seg_xpm/addrb[3]} {data_mem/data_seg_xpm/addrb[4]} {data_mem/data_seg_xpm/addrb[5]}]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 6 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {mem_bus_req[mem_addr][0]} {mem_bus_req[mem_addr][1]} {mem_bus_req[mem_addr][2]} {mem_bus_req[mem_addr][3]} {mem_bus_req[mem_addr][4]} {mem_bus_req[mem_addr][5]}]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list core/d_valid]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list data_mem/data_seg_xpm/enb]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list core/flush]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list core/stall3]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list reset]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 26 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {core/IF_regs[inst][0]} {core/IF_regs[inst][1]} {core/IF_regs[inst][2]} {core/IF_regs[inst][3]} {core/IF_regs[inst][4]} {core/IF_regs[inst][5]} {core/IF_regs[inst][6]} {core/IF_regs[inst][7]} {core/IF_regs[inst][8]} {core/IF_regs[inst][9]} {core/IF_regs[inst][10]} {core/IF_regs[inst][11]} {core/IF_regs[inst][12]} {core/IF_regs[inst][13]} {core/IF_regs[inst][14]} {core/IF_regs[inst][15]} {core/IF_regs[inst][16]} {core/IF_regs[inst][17]} {core/IF_regs[inst][18]} {core/IF_regs[inst][19]} {core/IF_regs[inst][20]} {core/IF_regs[inst][21]} {core/IF_regs[inst][22]} {core/IF_regs[inst][23]} {core/IF_regs[inst][24]} {core/IF_regs[inst][25]}]]
