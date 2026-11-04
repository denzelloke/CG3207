# Run after assemble.py. Example:
# vivado -mode batch -source lab4/demo/scripts/build.tcl -tclargs lab4/demo/build bitstream
set script_dir [file dirname [file normalize [info script]]]
set demo [file normalize "$script_dir/.."]
set lab [file normalize "$demo/.."]
set out [file normalize [lindex $argv 0]]
set stage [lindex $argv 1]
if {$stage eq ""} {set stage bitstream}
if {![file exists "$out/game.mem"]} {error "Run scripts/assemble.py --out $out first"}
file mkdir "$out/fpga"
cd $out
create_project -in_memory -part xc7a100tcsg324-1
set core {
    RV.v HazardUnit.v MCycle.v BranchPredictor.v Subword.v
    IRQHandler.v InterruptController.v Timer.v ButtonDebouncer.v
    Pipline_Resgisters/DRegister.v Pipline_Resgisters/ERegister.v
    Pipline_Resgisters/MRegister.v Pipline_Resgisters/WRegister.v
    old/ALU.v old/Decoder.v old/Extend.v old/PC_Logic.v
    old/ProgramCounter.v old/RegFile.v old/Shifter.v
}
foreach f $core {read_verilog "$lab/$f"}
foreach f {PerformanceCounters.v GameInputs.v DisplayRegisters.v GameSoC.v
           VgaTiming.v Font5x7.v GameRenderer.v NeonTop.v} {
    read_verilog "$demo/rtl/$f"
}
add_files -norecurse "$out/game.mem"
read_xdc "$demo/constraints/NeonTop.xdc"
set_property top NeonTop [current_fileset]
if {$stage eq "project"} {
    save_project_as neon "$out/project" -force
    puts "PROJECT READY: $out/project/neon.xpr"
    exit
}
synth_design -top NeonTop -part xc7a100tcsg324-1
write_checkpoint -force "$out/fpga/neon_synth.dcp"
write_verilog -force -mode funcsim "$out/fpga/neon_synth.v"
report_utilization -file "$out/fpga/utilization_synth.rpt"
report_timing_summary -file "$out/fpga/timing_synth.rpt"
if {$stage eq "synth"} {exit}
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force "$out/fpga/neon_routed.dcp"
report_timing_summary -report_unconstrained -file "$out/fpga/timing_routed.rpt"
report_utilization -file "$out/fpga/utilization_routed.rpt"
report_drc -file "$out/fpga/drc.rpt"
report_clock_interaction -file "$out/fpga/clock_interaction.rpt"
set worst [get_timing_paths -max_paths 1 -nworst 1]
if {[llength $worst]==0} {error "No timed paths found"}
set slack [get_property SLACK $worst]
if {$slack < 0} {error "Timing failed: WNS=$slack ns. See timing_routed.rpt"}
set hold_paths [get_timing_paths -delay_type min -max_paths 1 -nworst 1]
if {[llength $hold_paths]==0} {error "No hold paths found"}
set hold_slack [get_property SLACK $hold_paths]
if {$hold_slack < 0} {error "Hold timing failed: $hold_slack ns. See timing_routed.rpt"}
write_bitstream -force "$out/fpga/NeonTop.bit"
puts "BUILD PASS: $out/fpga/NeonTop.bit; setup slack $slack ns; hold slack $hold_slack ns"
