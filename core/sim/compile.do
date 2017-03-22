vlog +define+PIPE+OPT_OUT+PIPE_MUL+PIPE_MUL_PRE +incdir+../rtl ../rtl/*.sv
#vlog +define+SMIC40LL +incdir+../rtl ../rtl/*.sv

#vlog +define+SMIC40LL ../../stdcore/rtl/*.sv
vlog +incdir+../../stdcore/rtl ../../stdcore/rtl/*.sv

#set srams [glob -tails -directory ../../sram dp_* rf_2p_*]
#foreach sram $srams {vlog +notimingchecks +nospecify ../../sram/$sram/$sram.v}

vlog +incdir+../tb ../tb/*.sv
