# -------------------------------------------------------------------------------
#  PROJECT: FPGA Brainfuck
# -------------------------------------------------------------------------------
#  AUTHORS: Pavel Benacek <pavel.benacek@gmail.com>
#  LICENSE: The MIT License (MIT), please read LICENSE file
#  WEBSITE: https://github.com/benycze/fpga-brainfuck/
# -------------------------------------------------------------------------------

# Load Quartus Prime Tcl Project package
package require ::quartus::project

# Check if we have a required variables from the environment
if {![info exists env(QUARTUS_PROJECT_NAME)]} {
	puts "Project name isn't set in the PROJECT_NAME env variable."
	exit 1
}

if {![info exists env(QUARTUS_OUTPUT_FOLDER) ] } {
	puts "Output folder isn't specified in the OUTPUT_FOLDER env variable."
	exit 1
}

set need_to_close_project 0
set make_assignments 1

set project_name $::env(QUARTUS_PROJECT_NAME)
set output_folder $::env(QUARTUS_OUTPUT_FOLDER)

# Check that the right project is open
if {[is_project_open]} {
	if {[string compare $quartus(project)  $project_name]} {
		puts "Project  $project_name is not open"
		set make_assignments 0
	}
} else {
	# Only open if not already open
	if {[project_exists  $project_name]} {
		project_open -revision  $project_name  $project_name
	} else {
		project_new -revision  $project_name  $project_name
	}
	set need_to_close_project 1
}

# Make assignments
if {$make_assignments} {

	set_global_assignment -name FAMILY "Cyclone 10 LP"
	set_global_assignment -name DEVICE 10CL025YU256C8G 
	set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
	set_global_assignment -name SYNCHRONIZER_IDENTIFICATION "FORCED IF ASYNCHRONOUS"
	set_global_assignment -name EDA_SIMULATION_TOOL "<None>"
	set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY  $output_folder
	set_global_assignment -name TOP_LEVEL_ENTITY fpga_top
	set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top
	# Source project files
	source project-settings.tcl
	source bcpu-sources.tcl

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
