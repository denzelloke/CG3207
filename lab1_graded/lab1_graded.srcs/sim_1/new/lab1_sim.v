`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/30/2026 05:33:06 PM
// Design Name: 
// Module Name: lab1_sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module lab1_sim();

reg sysclk = 0;
reg btnU = 0;
reg btnC = 0;

// note to self: dont initialise output wires in sim [eg led = 0] 
// bcos the uut module alr does that and if the initial values arent the same it will evaluate to X. then glhf.  
wire [15:0] led;
wire dp;
wire [7:0] anode;
wire [6:0] cathode;

Top test0(sysclk, btnU, btnC, led, dp, anode, cathode);

    // sim threshold4hz = 2 ticks
    // sim threshold 1hz = 8 ticks
    
    always begin
        sysclk = ~sysclk;
        #5;    
    end
    
    initial begin
        #160;
        
        btnU = 1;
        btnC = 0;
        #160 ;
        
        btnU = 0;
        btnC = 1;
        #160
        
        btnU = 1;
        btnC = 1;
        #160
        $finish; 
    end

endmodule
