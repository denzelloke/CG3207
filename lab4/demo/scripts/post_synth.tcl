# A functional simulation of the generated synthesized netlist (not timing sim).
# Requires a Vivado installation that can launch XSim and resolve unisims_ver.
set script_dir [file dirname [file normalize [info script]]]
set demo [file normalize "$script_dir/.."]
set out [file normalize [lindex $argv 0]]
if {![file exists "$out/fpga/neon_synth.v"]} {error "Run build.tcl synth or bitstream first"}
create_project -force neon_post "$out/post_synth" -part xc7a100tcsg324-1
add_files -norecurse "$out/fpga/neon_synth.v"
add_files -norecurse "$out/game.mem"
add_files -fileset sim_1 -norecurse "$demo/tests/test_board.v"
set_property top test_board [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
launch_simulation
run all
close_sim
