`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// This module should contain the corresponding Memory data generated from Hex2ROM
// and choose the memory data to be displayed based on enable signal  
// Fill in the blank to complete this module 
// (c) Gu Jing, ECE, NUS
//////////////////////////////////////////////////////////////////////////////////


module Get_MEM(
    input sysclk,					// fundamental clock 100MHz
	input enable,				// enable signal to read the next content
	output [31:0] data,			// 32 bits memory contents for 7-segments display
    output upper_lower);      	// 1-bit signal rerequied for LEDs, indicating which half of the Memory data is displaying on LEDs
								// upper_lower = 1 to display upper half of the Memory data on LEDs
    
// declare IROM and DMEM
reg [31:0] IROM [0:127];
reg [31:0] DMEM [0:127];

// declare indics of IROM and DMEM
reg [8:0] addr = 0;

initial
begin	
	// Load the instruction memory from the memory file "IROM.mem"
	$readmemh("IROM.mem", IROM);

	// Load the data memory from the memory file "DMEM.mem"
	$readmemh("DMEM.mem", DMEM);

end

// determine upper_lower by corresponding input
assign upper_lower = addr[0];


// determine corresponding memory data that should be displayed on 7-segments
// addr[8] chooses instruction or data memory
assign data = (addr[8] == 0) ? IROM[addr[7:1]] : DMEM[addr[7:1]];

// determine memory index "addr" accordingly
// Please see towards the end of Lab 1 manual for more info/hints on how to use enable
always @(posedge sysclk) begin
    if (enable) addr <= addr + 1;
end
	
endmodule
