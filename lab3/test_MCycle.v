`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NUS
// Engineer: Shahzor Ahmad, Rajesh C Panicker
// 
// Create Date: 27.09.2016 16:55:23
// Design Name: 
// Module Name: test_MCycle
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
/* 
----------------------------------------------------------------------------------
--	(c) Shahzor Ahmad, Rajesh C Panicker
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post it on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(iv) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(v) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

module test_MCycle(

    );
    
    // DECLARE INPUT SIGNALs
    reg CLK = 0 ;
    reg RESET = 0 ;
    reg Start = 0 ;
    reg [1:0] MCycleOp = 0 ;
    reg [31:0] Operand1 = 0 ;
    reg [31:0] Operand2 = 0 ;

    // DECLARE OUTPUT SIGNALs
    wire [31:0] Result1 ;
    wire [31:0] Result2 ;
    wire Busy ;
    
    // INSTANTIATE DEVICE/UNIT UNDER TEST (DUT/UUT)
    MCycle #(
    .width(32),
    .ENHANCED_MUL(1'b0)
    ) dut(
        CLK,
        RESET,
        Start,
        MCycleOp,
        Operand1,
        Operand2,
        Result1,
        Result2,
        Busy
    );
    
    // STIMULI
    initial begin
        // hold reset state for 100 ns.
        #10 ;    
        MCycleOp = 2'b00 ;  //signed mul
        Operand1 = 32'hFFFFFFFF ;   // -1
        Operand2 = 32'hFFFFFFFF ;   // -1
        Start = 1'b1 ; // Start is asserted continously(Operations are performed back to back). To try a non-continous Start, you can uncomment the commented lines.    

        wait(Busy) ; // suspend initial block till condition becomes true  ;
        wait(~Busy) ;
        #1;
        $display("Signed multiplication 1: Result1 = %h, Result2 = %h",
                 Result1, Result2);

//        #10 ;
//        Start = 1'b0 ;
//        #10 ;
        Operand1 = 32'hFFFFFFFE ;   // -2
        Operand2 = 32'hFFFFFFFF ;   // -1
//        Start = 1'b1 ;
        
        wait(Busy) ; 
        wait(~Busy) ;
        #1;
        $display("Signed multiplication 2: Result1 = %h, Result2 = %h",
                 Result1, Result2);

//        #10 ;
//        Start = 1'b0 ;
//        #10 ;
        MCycleOp = 2'b01 ;  //unsigned mul
        Operand1 = 32'hFFFFFFFF ;   // 4294967295
        Operand2 = 32'hFFFFFFFF ;   // 4294967295
//        Start = 1'b1 ;

        wait(Busy) ; 
        wait(~Busy) ; 
        #1;
        $display("Unsigned multiplication 1: Result1 = %h, Result2 = %h",
                 Result1, Result2);

//        #10 ;
//        Start = 1'b0 ;
//        #10 ;
        Operand1 = 32'hFFFFFFFE ;   // 4294967294
        Operand2 = 32'hFFFFFFFF ;   // 4294967295
//        Start = 1'b1 ;

        wait(Busy) ; 
        wait(~Busy) ; 
        #1;
        $display("Unsigned multiplication 2: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        MCycleOp = 2'b10 ;  //signed div
        Operand1 = 32'hFFFFFFEF ;   // -17
        Operand2 = 32'h00000005 ;   // 5
        Start = 1'b1 ;

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Signed division 1: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        // 17 / -5 = -3 remainder 2
        Operand1 = 32'h00000011 ;   // 17
        Operand2 = 32'hFFFFFFFB ;   // -5

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Signed division 2: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        // -17 / -5 = 3 remainder -2
        Operand1 = 32'hFFFFFFEF ;   // -17
        Operand2 = 32'hFFFFFFFB ;   // -5

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Signed division 3: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        // -8 / 2 = -4 remainder 0
        Operand1 = 32'hFFFFFFF8 ;   // -8
        Operand2 = 32'h00000002 ;   // 2

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Signed division 4: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        MCycleOp = 2'b11 ;  //unsigned div

        // 17 / 5 = 3 remainder 2
        Operand1 = 32'h00000011 ;   // 17
        Operand2 = 32'h00000005 ;   // 5

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Unsigned division 1: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        // 14 / 3 = 4 remainder 2
        Operand1 = 32'h0000000E ;   // 14
        Operand2 = 32'h00000003 ;   // 3

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Unsigned division 2: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        // 3 / 5 = 0 remainder 3
        Operand1 = 32'h00000003 ;   // 3
        Operand2 = 32'h00000005 ;   // 5

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Unsigned division 3: Result1 = %h, Result2 = %h",
                 Result1, Result2);

        // 0xFFFFFFEF / 5 = 0x3333332F remainder 4
        Operand1 = 32'hFFFFFFEF ;   // 4294967279 unsigned
        Operand2 = 32'h00000005 ;   // 5

        wait(Busy) ;
        wait(~Busy) ;
        #1;
        $display("Unsigned division 4: Result1 = %h, Result2 = %h",
                 Result1, Result2);
        
        Start = 1'b0 ;

        #10;
        $finish;
    end
     
    // GENERATE CLOCK       
    always begin 
        #5 CLK = ~CLK ; 
        // invert CLK every 5 time units 
    end
    
endmodule