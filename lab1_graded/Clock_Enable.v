//////////////////////////////////////////////////////////////////////////////////
// This module is to generate an enable signal for different display frequency based on pushbuttons
// Fill in the blank to complete this module 
// (c) Gu Jing, ECE, NUS
//////////////////////////////////////////////////////////////////////////////////

module Clock_Enable(
	input sysclk,			// fundamental clock 100 MHz
	input btnU,			// button BTNU for 4Hz speed
	input btnC,			// button BTNC for pause
	output reg enable);	// output signal used to enable the reading of next memory data

    // define reg threshold to allow 4hz or 1hz frequency
    localparam threshold4hz = 25'd24_999_999; // f=4hz; t=0.25s = 10ns * 25_000_000ticks
    localparam threshold1hz = 27'd99_999_999; // f=1hz' t=1s = 10ns * 100_000_000ticks
    
    // for sim
    // localparam threshold4hz = 2'd2;
    // localparam threshold1hz = 4'd8;

    // define reg counter to be able to count to certain threshold value
    reg [26:0] counter = 0;
    wire [26:0] counterthreshold;
	
	assign counterthreshold = (btnU) ? threshold4hz : threshold1hz;
	
    // complete this always block by determining the enable output by counter, threshold and buttons 
    always @(posedge sysclk) begin
	   if (btnC) begin
	       counter <= counter;
	       enable <= 0;
	   end
	   
	   else begin
	       counter <= (counter >= counterthreshold) ? 0 : counter + 1;
	       enable <= (counter == 0) ? 1 : 0;
	   end 
    end
	
endmodule


