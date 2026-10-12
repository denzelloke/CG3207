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
    reg [3:0] Operand1 = 0 ;
    reg [3:0] Operand2 = 0 ;

    // DECLARE OUTPUT SIGNALs
    wire [3:0] Result1 ;
    wire [3:0] Result2 ;
    wire Busy ;
    
    // INSTANTIATE DEVICE/UNIT UNDER TEST (DUT/UUT)
    MCycle dut( 
        CLK, 
        RESET, 
        Start, 
        MCycleOp, 
        Operand1, 
        Operand2, 
        Result1, 
        Result2, 
        Busy
        ) ;
    
    // STIMULI
    initial begin
        RESET = 1'b1;
        Start = 1'b0;
        #10;
        RESET = 1'b0;

        //signed Multi
        MCycleOp = 2'b00 ;
        Operand1 = 4'b1111 ;
        Operand2 = 4'b1111 ;
        Start = 1'b1 ; // Start is asserted continously(Operations are performed back to back). To try a non-continous Start, you can uncomment the commented lines.    

        $display("Starting first test at %0t", $time);
        
        wait(Busy);
        $display("Busy became 1 at %0t", $time);
        
        wait(~Busy);
        $display("Finished at %0t: Result1=%h Result2=%h",
                 $time, Result1, Result2);

        #1;
        if ({Result2, Result1} == 8'h01)
                $display("PASS: signed -1 * -1 = 1");
        else
                $display("FAIL: signed -1 * -1: result=%h", {Result2, Result1});

        //signed multi -2 * -1 = 2
        Operand1 = 4'b1110 ;
        Operand2 = 4'b1111 ;
//        Start = 1'b1 ;
        
        wait(Busy) ; 
        wait(~Busy) ;
        #1;
        if ({Result2, Result1} === 8'h02)
                $display("PASS: signed -2 * -1 = 2");
        else
                $display("FAIL: signed -2 * -1: result=%h",
                        {Result2, Result1});
//        #10 ;
//        Start = 1'b0 ;
//        #10 ;
        //unsigned Multi
        MCycleOp = 2'b01 ;
        Operand1 = 4'b1111 ;
        Operand2 = 4'b1111 ;
//        Start = 1'b1 ;

        wait(Busy) ; 
        wait(~Busy) ; 
        #1;
        if ({Result2, Result1} === 8'hE1)
                $display("PASS: unsigned 15 * 15 = 225");
        else
                $display("FAIL: unsigned 15 * 15: result=%h",
                        {Result2, Result1});
//        #10 ;
//        Start = 1'b0 ;
//        #10 ;
        // Unsigned multiplication: 14 * 15 = 210
        Operand1 = 4'b1110 ;
        Operand2 = 4'b1111 ;
//        Start = 1'b1 ;

        wait(Busy) ; 
        wait(~Busy) ; 
        #1;
        if ({Result2, Result1} === 8'hD2)
                $display("PASS: unsigned 14 * 15 = 210");
        else
                $display("FAIL: unsigned 14 * 15: result=%h",
                        {Result2, Result1});

        // Unsigned division: 13 / 3 = 4 remainder 1
        MCycleOp = 2'b11;
        Operand1 = 4'd13;
        Operand2 = 4'd3;

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'd4 && Result2 === 4'd1)
                $display("PASS: unsigned 13 / 3 = 4 remainder 1");
        else
                $display("FAIL: unsigned 13 / 3: Q=%d R=%d",
                        Result1, Result2);

        // Unsigned division: dividend smaller than divisor
        Operand1 = 4'd2;
        Operand2 = 4'd7;

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'd0 && Result2 === 4'd2)
                $display("PASS: unsigned 2 / 7 = 0 remainder 2");
        else
                $display("FAIL: unsigned 2 / 7: Q=%d R=%d",
                        Result1, Result2);

        // Unsigned division: zero dividend
        Operand1 = 4'd0;
        Operand2 = 4'd3;

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'd0 && Result2 === 4'd0)
                $display("PASS: unsigned 0 / 3 = 0 remainder 0");
        else
                $display("FAIL: unsigned 0 / 3: Q=%d R=%d",
                        Result1, Result2);

        // Unsigned division: exact division, high-bit divisor
        Operand1 = 4'd15;
        Operand2 = 4'd15;

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'd1 && Result2 === 4'd0)
                $display("PASS: unsigned 15 / 15 = 1 remainder 0");
        else
                $display("FAIL: unsigned 15 / 15: Q=%d R=%d",
                        Result1, Result2);

        // Signed division: +7 / +3 = +2 remainder +1
        MCycleOp = 2'b10;
        Operand1 = 4'b0111;
        Operand2 = 4'b0011;

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'b0010 && Result2 === 4'b0001)
                $display("PASS: signed 7 / 3 = 2 remainder 1");
        else
                $display("FAIL: signed 7 / 3: Q=%d R=%d",
                        $signed(Result1), $signed(Result2));

        // Signed division: -7 / +3 = -2 remainder -1
        Operand1 = 4'b1001; // -7
        Operand2 = 4'b0011; // +3

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'b1110 && Result2 === 4'b1111)
                $display("PASS: signed -7 / 3 = -2 remainder -1");
        else
                $display("FAIL: signed -7 / 3: Q=%d R=%d",
                        $signed(Result1), $signed(Result2));

        // Signed division: +7 / -3 = -2 remainder +1
        Operand1 = 4'b0111; // +7
        Operand2 = 4'b1101; // -3

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'b1110 && Result2 === 4'b0001)
                $display("PASS: signed 7 / -3 = -2 remainder 1");
        else
                $display("FAIL: signed 7 / -3: Q=%d R=%d",
                        $signed(Result1), $signed(Result2));

        // Signed division: -7 / -3 = +2 remainder -1
        Operand1 = 4'b1001; // -7
        Operand2 = 4'b1101; // -3

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'b0010 && Result2 === 4'b1111)
                $display("PASS: signed -7 / -3 = 2 remainder -1");
        else
                $display("FAIL: signed -7 / -3: Q=%d R=%d",
                        $signed(Result1), $signed(Result2));

        // Signed division: minimum value / +1
        Operand1 = 4'b1000; // -8
        Operand2 = 4'b0001; // +1

        wait(Busy);
        wait(~Busy);
        #1;
        if (Result1 === 4'b1000 && Result2 === 4'b0000)
                $display("PASS: signed -8 / 1 = -8 remainder 0");
        else
                $display("FAIL: signed -8 / 1: Q=%d R=%d",
                        $signed(Result1), $signed(Result2));

        Start = 1'b0;
        $display("Test sequence finished.");
        #10;
        $finish;
    end
     
    // GENERATE CLOCK       
    always begin 
        #5 CLK = ~CLK ; 
        // invert CLK every 5 time units 
    end
    
endmodule