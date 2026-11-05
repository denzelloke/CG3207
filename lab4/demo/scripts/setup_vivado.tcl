# Source this from the Vivado Tcl Console after closing any unrelated project.
# Creates/opens the dedicated game project without modifying the old lab project.
# Paths are resolved from this script, not from Vivado's working directory.
set neon_demo [file normalize [file join [file dirname [info script]] ..]]
set neon_lab [file dirname $neon_demo]
set neon_build [file join $neon_demo build]
set neon_project_dir [file join $neon_build vivado Lab4_Neon]
set neon_xpr [file join $neon_project_dir Lab4_Neon.xpr]

set neon_sources {}
foreach f {
    RV.v HazardUnit.v MCycle.v BranchPredictor.v Subword.v
    IRQHandler.v InterruptController.v Timer.v ButtonDebouncer.v
    Pipline_Resgisters/DRegister.v Pipline_Resgisters/ERegister.v
    Pipline_Resgisters/MRegister.v Pipline_Resgisters/WRegister.v
    old/ALU.v old/Decoder.v old/Extend.v old/PC_Logic.v
    old/ProgramCounter.v old/RegFile.v old/Shifter.v
} {lappend neon_sources [file join $neon_lab $f]}
foreach f {
    PerformanceCounters.v GameInputs.v DisplayRegisters.v GameSoC.v
    VgaTiming.v Font5x7.v GameRenderer.v NeonTop.v
} {lappend neon_sources [file join $neon_demo rtl $f]}
set neon_xdc [file join $neon_demo constraints NeonTop.xdc]
foreach f [concat $neon_sources [list $neon_xdc]] {
    if {![file isfile $f]} {error "Missing required source: $f"}
}

# Do not close another open project or discard its unsaved work.
if {[current_project -quiet] ne ""} {
    set neon_current_dir [file normalize [get_property DIRECTORY [current_project]]]
    if {$neon_current_dir ne [file normalize $neon_project_dir]} {
        error "Another project is open. Save and close it, then source this script again. The game project will be $neon_xpr"
    }
}

set neon_python [auto_execok python]
if {$neon_python eq ""} {set neon_python [auto_execok python3]}
if {$neon_python eq ""} {error "Python is required to assemble software/game.asm; install Python or add it to PATH."}
puts "Assembling current game.asm (Java and the repository's RARS jar are required)..."
if {[catch {exec {*}$neon_python [file join $neon_demo scripts assemble.py] --out $neon_build 2>@1} neon_assembly]} {
    error "Game ROM assembly failed; project sources have not been changed.\n$neon_assembly"
}
set neon_mem [file join $neon_build game.mem]
if {![file isfile $neon_mem]} {error "Assembler did not create $neon_mem"}

if {[current_project -quiet] eq ""} {
    if {[file isfile $neon_xpr]} {
        open_project $neon_xpr
    } else {
        create_project Lab4_Neon $neon_project_dir -part xc7a100tcsg324-1
    }
}
set_property part xc7a100tcsg324-1 [current_project]
set_property target_language Verilog [current_project]

# Manage only this dedicated project's design and constraint filesets.
# remove_files removes project references; it does not delete source files.
set neon_old_sources [get_files -quiet -of_objects [get_filesets sources_1]]
if {[llength $neon_old_sources]} {remove_files -fileset sources_1 $neon_old_sources}
set neon_old_constraints [get_files -quiet -of_objects [get_filesets constrs_1]]
if {[llength $neon_old_constraints]} {remove_files -fileset constrs_1 $neon_old_constraints}
add_files -fileset sources_1 -norecurse [concat $neon_sources [list $neon_mem]]
set_property file_type {Memory Initialization Files} [get_files $neon_mem]
add_files -fileset constrs_1 -norecurse $neon_xdc
set_property top NeonTop [get_filesets sources_1]
# The production top must use its MMCM, not the testbench clock-divider branch.
set_property verilog_define {} [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "NEON PROJECT READY: $neon_xpr"
puts "Top: NeonTop; device: xc7a100tcsg324-1"
puts "Design: 28 Verilog sources plus $neon_mem"
puts "Constraints: $neon_xdc"
puts "No synthesis, implementation, bitstream generation or board programming has been run."
