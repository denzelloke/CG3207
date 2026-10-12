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

module test_MCycle;

    reg CLK = 0;
    reg RESET = 0;
    reg Start = 0;
    reg [1:0] MCycleOp = 0;
    reg [31:0] Operand1 = 0;
    reg [31:0] Operand2 = 0;

    wire [31:0] Result1;
    wire [31:0] Result2;
    wire Busy;

    integer tests = 0;
    integer failures = 0;

    MCycle #(.width(32)) dut (
        .CLK(CLK),
        .RESET(RESET),
        .Start(Start),
        .MCycleOp(MCycleOp),
        .Operand1(Operand1),
        .Operand2(Operand2),
        .Result1(Result1),
        .Result2(Result2),
        .Busy(Busy)
    );

    always #5 CLK = ~CLK;

    // Each call applies operands, waits for completion,
    // and checks both result halves.
    task check_operation;
        input [1:0] operation;
        input [31:0] operand_a;
        input [31:0] operand_b;
        input [31:0] expected_result1;
        input [31:0] expected_result2;
        begin
            MCycleOp = operation;
            Operand1 = operand_a;
            Operand2 = operand_b;
            Start = 1'b1;

            wait (Busy === 1'b1);
            wait (Busy === 1'b0);
            #1;

            tests = tests + 1;

            if ((Result1 === expected_result1) &&
                (Result2 === expected_result2)) begin
                $display(
                    "PASS %0d: op=%b A=%h B=%h Result1=%h Result2=%h",
                    tests, operation, operand_a, operand_b,
                    Result1, Result2
                );
            end
            else begin
                failures = failures + 1;
                $display(
                    "FAIL %0d: op=%b A=%h B=%h",
                    tests, operation, operand_a, operand_b
                );
                $display(
                    "  Expected: Result1=%h Result2=%h",
                    expected_result1, expected_result2
                );
                $display(
                    "  Actual:   Result1=%h Result2=%h",
                    Result1, Result2
                );
            end
        end
    endtask

    initial begin
        RESET = 1'b1;
        Start = 1'b0;
        repeat (2) @(negedge CLK);
        RESET = 1'b0;

        // Arguments:
        // operation, Operand1, Operand2, expected Result1, expected Result2

        // SIGNED MULTIPLICATION
        // Result1 = low 32 bits; Result2 = high 32 bits.

        // -1 * -1 = 1
        check_operation(2'b00, 32'hFFFFFFFF, 32'hFFFFFFFF,
                              32'h00000001, 32'h00000000);

        // -2 * -1 = 2
        check_operation(2'b00, 32'hFFFFFFFE, 32'hFFFFFFFF,
                              32'h00000002, 32'h00000000);

        // -7 * 3 = -21
        check_operation(2'b00, 32'hFFFFFFF9, 32'd3,
                              32'hFFFFFFEB, 32'hFFFFFFFF);

        // 7 * -3 = -21
        check_operation(2'b00, 32'd7, 32'hFFFFFFFD,
                              32'hFFFFFFEB, 32'hFFFFFFFF);

        // Minimum signed value * 1
        check_operation(2'b00, 32'h80000000, 32'd1,
                              32'h80000000, 32'hFFFFFFFF);

        // Minimum signed value * -1 = +2147483648
        check_operation(2'b00, 32'h80000000, 32'hFFFFFFFF,
                              32'h80000000, 32'h00000000);

        // Minimum signed value squared
        check_operation(2'b00, 32'h80000000, 32'h80000000,
                              32'h00000000, 32'h40000000);

        // Maximum signed value squared
        check_operation(2'b00, 32'h7FFFFFFF, 32'h7FFFFFFF,
                              32'h00000001, 32'h3FFFFFFF);

        // Zero product
        check_operation(2'b00, 32'd0, 32'hFFFFFFFF,
                              32'd0, 32'd0);

        // UNSIGNED MULTIPLICATION

        // 15 * 15 = 225
        check_operation(2'b01, 32'd15, 32'd15,
                              32'd225, 32'd0);

        // 14 * 15 = 210
        check_operation(2'b01, 32'd14, 32'd15,
                              32'd210, 32'd0);

        // Maximum unsigned value squared
        check_operation(2'b01, 32'hFFFFFFFF, 32'hFFFFFFFF,
                              32'h00000001, 32'hFFFFFFFE);

        // Exercise high bit of multiplier
        check_operation(2'b01, 32'd2, 32'h80000000,
                              32'h00000000, 32'h00000001);

        // Maximum unsigned value * 1
        check_operation(2'b01, 32'hFFFFFFFF, 32'd1,
                              32'hFFFFFFFF, 32'h00000000);

        // UNSIGNED DIVISION
        // Result1 = quotient; Result2 = remainder.

        check_operation(2'b11, 32'd13, 32'd3,
                              32'd4, 32'd1);

        check_operation(2'b11, 32'd2, 32'd7,
                              32'd0, 32'd2);

        check_operation(2'b11, 32'd0, 32'd3,
                              32'd0, 32'd0);

        check_operation(2'b11, 32'd15, 32'd15,
                              32'd1, 32'd0);

        // Maximum unsigned value / 1
        check_operation(2'b11, 32'hFFFFFFFF, 32'd1,
                              32'hFFFFFFFF, 32'd0);

        // Maximum unsigned value / 2
        check_operation(2'b11, 32'hFFFFFFFF, 32'd2,
                              32'h7FFFFFFF, 32'd1);

        // Large divisor with its top bit set
        check_operation(2'b11, 32'hFFFFFFFF, 32'h80000000,
                              32'd1, 32'h7FFFFFFF);

        // SIGNED DIVISION

        // +7 / +3 = +2 remainder +1
        check_operation(2'b10, 32'd7, 32'd3,
                              32'd2, 32'd1);

        // -7 / +3 = -2 remainder -1
        check_operation(2'b10, 32'hFFFFFFF9, 32'd3,
                              32'hFFFFFFFE, 32'hFFFFFFFF);

        // +7 / -3 = -2 remainder +1
        check_operation(2'b10, 32'd7, 32'hFFFFFFFD,
                              32'hFFFFFFFE, 32'd1);

        // -7 / -3 = +2 remainder -1
        check_operation(2'b10, 32'hFFFFFFF9, 32'hFFFFFFFD,
                              32'd2, 32'hFFFFFFFF);

        // -8 / 1 = -8 remainder 0
        check_operation(2'b10, 32'hFFFFFFF8, 32'd1,
                              32'hFFFFFFF8, 32'd0);

        // Minimum signed value / 1
        check_operation(2'b10, 32'h80000000, 32'd1,
                              32'h80000000, 32'd0);

        // Signed overflow case: quotient retains minimum bit pattern.
        check_operation(2'b10, 32'h80000000, 32'hFFFFFFFF,
                              32'h80000000, 32'd0);

        // Minimum signed value / itself
        check_operation(2'b10, 32'h80000000, 32'h80000000,
                              32'd1, 32'd0);

        // +7 / minimum signed value = 0 remainder 7
        check_operation(2'b10, 32'd7, 32'h80000000,
                              32'd0, 32'd7);

        // -2 / 7 = 0 remainder -2
        check_operation(2'b10, 32'hFFFFFFFE, 32'd7,
                              32'd0, 32'hFFFFFFFE);

        // Zero / negative divisor
        check_operation(2'b10, 32'd0, 32'hFFFFFFFD,
                              32'd0, 32'd0);

        Start = 1'b0;

        $display("----------------------------------------");
        $display("Tests: %0d, Passed: %0d, Failed: %0d",
                 tests, tests - failures, failures);

        if (failures != 0)
            $fatal(1, "Some MCycle tests failed");

        $display("ALL TESTS PASSED");
        #10;
        $finish;
    end

    // Stop rather than hang if Busy never completes.
    initial begin
        #100000;
        $fatal(1, "TIMEOUT: MCycle test sequence did not finish");
    end

endmodule