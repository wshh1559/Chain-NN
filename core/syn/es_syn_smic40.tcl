#
# design compiler script using SMIC 40nm library
#

# define the top model
set top_model dcnn_top

#define the clock period
set clock_period 2500

set folder [clock format [clock seconds] -gmt false -format "%Y%m%d_top_down_$clock_period"]
if { ! [file exists $folder]} {
  file mkdir $folder
}

set source_directory {../rtl ../../stdcore/rtl}

#
# paths and libraries
#

set search_path {
  . \
  /home/shihao/lib/es65/CS202_SCIO_lay12_20110510/RDF/lib/dc/CS202/common/db \
  /eda/synopsys.syn.vI-2013.12-SP2/libraries/syn \
  ../../sram/db \
}

set search_path [concat $search_path $source_directory]

set LIBRARY_SLOW cs202snc_uc_core_s_p125_105v
set LIBRARY_SLOW_SCAN cs202snc_uc_nscan_s_p125_105v
set LIBRARY_FAST cs202snc_uc_core_f_m40_13v

set target_library "$LIBRARY_SLOW.db $LIBRARY_SLOW_SCAN.db"  
set link_library "$LIBRARY_SLOW.db $LIBRARY_SLOW_SCAN.db $LIBRARY_FAST.db"

#
# sram
#
#set srams [glob -tails -directory ../../sram dp_* rf_2p_* ]
#set ss _ss_0p99v_0p99v_125c
#set ff _ff_1p21v_1p21v_m40c
#foreach sram $srams {
#  set target_library [concat $target_library $sram$ss.db]
#}


#set link_library "$LIBRARY_SLOW.db $LIBRARY_FAST.db"
set link_library [concat * $target_library dw_foundation.sldb]
set symbol_library {}


set verilogout_no_tri true
set verilogout_show_unconnected_pins true
set bus_naming_style {%s[%d]}
define_name_rules myrules \
  -case_insensitive \
  -allowed {A-Za-z0-9_} \
  -first_restricted "0-9_" \
  -last_restricted "_" \
  -equal_ports_nets



set mydesign $top_model

set hdlin_vrlg_std 2005
#
# set acs_hdl_source $source_directory
# acs_read_hdl -recurse -format sverilog -verbose $mydesign -no_elaborate > $folder/$mydesign.acs.log
#
# #analyze -format verilog $mydesign
#
# elaborate $mydesign > $folder/$mydesign.elab.log
# uniquify


analyze -format sverilog -define {PIPE OPT_OUT PIPE_MUL PIPE_MUL_PRE} [glob ../rtl/*.sv] > $folder/$mydesign.analyze.log
analyze -format sverilog [glob ../../stdcore/rtl/*.sv] >> $folder/$mydesign.analyze.log
#analyze -format sverilog -define SMIC40LL [glob ../rtl/*.sv] > $folder/$mydesign.analyze.log
#analyze -format sverilog -define SMIC40LL [glob ../../stdcore/rtl/*.sv] > $folder/$mydesign.analyze.log

elaborate $mydesign > $folder/$mydesign.elab.log

link

uniquify

check_design > $folder/check_design.rep

current_design $mydesign



set_wire_load_mode top
#set_operating_conditions -min ff_typical_min_1p21v_m40c -max ss_typical_max_0p99v_125c -analysis_type bc_wc

set_min_library $LIBRARY_SLOW.db -min_version $LIBRARY_FAST.db

#
# clock definitions
#
# unit: ns
#

set  CLK_PERIOD $clock_period
set  CLK_NAME   clk

create_clock -period $CLK_PERIOD -name clk [get_ports $CLK_NAME]

set clock_ports [get_ports $CLK_NAME]

set_clock_uncertainty -setup 0.1 $CLK_NAME
set_propagated_clock $CLK_NAME
set_dont_touch_network $CLK_NAME
set_drive 0 $clock_ports

set_input_delay 0.1 -clock $CLK_NAME  [all_inputs]
set_output_delay 0.1 -clock $CLK_NAME  [all_outputs]
remove_input_delay [get_ports clk]

set_ideal_network arst_n
#set_ideal_network rst_n

#set_ultra_optimization true
set_boundary_optimization $mydesign true
set_fix_multiple_port_nets -feedthroughs -all -buffer_constants

#set_fix_hold [all_clocks]

#link
#check_design > $folder/check_design.rep

#set_host_options -max_cores 2
compile_ultra -no_autoungroup
#compile

#group -all -flatten
#remove_unconnected_ports [get_cells -h]
change_name -h -rules myrules

write -f verilog -h -o $folder/$mydesign.vnet
#write -h -o $folder/$mydesign.db
write_sdc $folder/$mydesign.sdc
write_sdf $folder/$mydesign.sdf
report_area > $folder/$mydesign.area.rep
report_timing > $folder/$mydesign.timing.rep
#report_timing -max_paths 100 > $folder/$mydesign.paths.rep
report_power > $folder/$mydesign.power.rep
report_qor > $folder/$mydesign.qor.rep

#set_svf -off
