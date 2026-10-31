`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------------
--	(c) Rajesh Panicker
--	License terms :
--		(i) DO NOT post it on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate any intellectual property of ARM Holdings or other entities.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(vi) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

/* // The following prompt was used with Claude Sonnet 4 with the following prompt, and the non-self-checking code, as in test_Wrapper_DIP_to_LED.v 
I am writing a testbench for a single-cycle RISC-V processor. 
I want to make the testbench below self-checking, without modifying the existing code substantially. Please have it in pure Verilog, adding the code for monitoring, scoreboarding, and message printing. 
Sample DIP[7:0] at the end of the cycle where LED_PC = 0x07 (i.e., at the positive clock edge when it transitions to 0x08) and see if it is reflected in LED_OUT[7:0] exactly 1 cycle later, i.e., at the positive clock edge when LED_PC transitions from 0x08 to 0x09. This has to be done on a continuous basis, i.e., LED_PC could become 0x07 over and over every few cycles.
LED_PC displays the PC bits [8:2]; it is 0x07 for lw instruction to read DIP, and is 0x08 for sw to write to LED_OUT. Parameterise 0x07 and 0x08 as the bits [6:2] of LW_DIP_PC_ADDRESS and SW_LED_PC_ADDRESS (the addresses being 9 bit values), and the number of cycles in between LW_SW_CYCLES which is 0 by default.
*/

module test_Wrapper #(
	   parameter N_LEDs_OUT	= 8,					
	   parameter N_DIPs		= 16,
	   parameter N_PBs		= 3,
	   parameter LW_DIP_PC_ADDRESS = 9'h01C,    // Address for lw instruction (bits [8:2] = 0x07)
	   parameter SW_LED_PC_ADDRESS = 9'h020,    // Address for sw instruction (bits [8:2] = 0x08)
	   parameter LW_SW_CYCLES = 0                // Number of cycles between lw and sw (default 0)
	)
	(
	);
	
	// Signals for the Unit Under Test (UUT)
	reg  [N_DIPs-1:0] DIP = 0;		
	reg  [N_PBs-1:0] PB = 0;			
	wire [N_LEDs_OUT-1:0] LED_OUT;
	wire [6:0] LED_PC;			
	wire [31:0] SEVENSEGHEX;	
	wire [7:0] UART_TX;
	reg  UART_TX_ready = 0;
	wire UART_TX_valid;
	reg  [7:0] UART_RX = 0;
	reg  UART_RX_valid = 0;
	wire UART_RX_ack;
	wire OLED_Write;
	wire [6:0] OLED_Col;
	wire [5:0] OLED_Row;
	wire [23:0] OLED_Data;
	reg [31:0] ACCEL_Data;
	wire ACCEL_DReady;			
	reg  RESET = 0;	
	reg  CLK = 0;

	// Self-checking variables
	localparam LW_PC_VALUE = LW_DIP_PC_ADDRESS[8:2];  // Extract bits [6:2] from address
	localparam SW_PC_VALUE = SW_LED_PC_ADDRESS[8:2];  // Extract bits [6:2] from address
	
	reg [7:0] sampled_dip = 8'h00;
	reg [7:0] expected_led = 8'h00;
	reg dip_sampled = 1'b0;
	reg checking_enabled = 1'b0;
	integer test_count = 0;
	integer pass_count = 0;
	integer fail_count = 0;
	
	// Instantiate UUT
    Wrapper dut(DIP, PB, LED_OUT, LED_PC, SEVENSEGHEX, UART_TX, UART_TX_ready, UART_TX_valid, UART_RX, UART_RX_valid, UART_RX_ack, OLED_Write, OLED_Col, OLED_Row, OLED_Data, ACCEL_Data, ACCEL_DReady, RESET, CLK) ;

	// Self-checking logic - Monitor and Scoreboard
	always @(posedge CLK) begin
		if (RESET) begin
			sampled_dip <= 8'h00;
			expected_led <= 8'h00;
			dip_sampled <= 1'b0;
			checking_enabled <= 1'b0;
			test_count <= 0;
			pass_count <= 0;
			fail_count <= 0;
		end
		else begin
			// Sample DIP when LED_PC transitions from LW_PC_VALUE to SW_PC_VALUE
			if (LED_PC == LW_PC_VALUE) begin
				sampled_dip <= DIP[7:0];
				dip_sampled <= 1'b1;
				expected_led <= DIP[7:0];
				$display("[%0t] INFO: Sampling DIP at PC=0x%02X, DIP[7:0]=0x%02X", 
					$time, LED_PC, DIP[7:0]);
			end
			
			// Check LED_OUT when LED_PC transitions from SW_PC_VALUE (accounting for LW_SW_CYCLES)
			if (dip_sampled && (LED_PC == (SW_PC_VALUE + LW_SW_CYCLES + 1))) begin
				checking_enabled <= 1'b1;
				test_count <= test_count + 1;
				
				if (LED_OUT == expected_led) begin
					pass_count <= pass_count + 1;
					$display("[%0t] PASS: Test #%0d - Expected LED_OUT=0x%02X, Got=0x%02X", 
						$time, test_count + 1, expected_led, LED_OUT);
				end
				else begin
					fail_count <= fail_count + 1;
					$display("[%0t] FAIL: Test #%0d - Expected LED_OUT=0x%02X, Got=0x%02X", 
						$time, test_count + 1, expected_led, LED_OUT);
				end
				
				// Reset for next test
				dip_sampled <= 1'b0;
				checking_enabled <= 1'b0;
			end
		end
	end
	
	// Monitor PC transitions for debugging
	reg [6:0] prev_led_pc = 7'h00;
	always @(posedge CLK) begin
		if (!RESET) begin
			if (LED_PC != prev_led_pc) begin
				$display("[%0t] DEBUG: PC transition from 0x%02X to 0x%02X", 
					$time, prev_led_pc, LED_PC);
			end
			prev_led_pc <= LED_PC;
		end
	end
	
	// Final test summary
	always @(posedge CLK) begin
		if (!RESET && test_count > 0 && $time > 1000) begin  // Print summary after some time
			if ((test_count % 10) == 0) begin  // Print summary every 10 tests
				$display("\n[%0t] === TEST SUMMARY ===", $time);
				$display("Total Tests: %0d", test_count);
				$display("Passed: %0d", pass_count);
				$display("Failed: %0d", fail_count);
				$display("Pass Rate: %0.1f%%", (pass_count * 100.0) / test_count);
				$display("========================\n");
			end
		end
	end
	
	// Note: This testbench is for DIP_to_LED program. Other assembly programs require appropriate modifications.
	// STIMULI
    initial
    begin
	RESET = 1; #10; RESET = 0; //hold reset state for 10 ns.
	
	$display("[%0t] Starting self-checking testbench", $time);
	$display("LW PC Value: 0x%02X", LW_PC_VALUE);
	$display("SW PC Value: 0x%02X", SW_PC_VALUE);
	$display("LW-SW Cycles: %0d", LW_SW_CYCLES);

        DIP = 16'hFFFF; // Set all DIP switches to ON
        #220;			
        DIP = 16'hAAAA; // Set all DIP switches to alternate on-off pattern
		// This is pressing DIP during the lw instruction that reads it. It is good not to be able to read it so 'promptly'; 
		// better to sychronise using an FF (in TOP) before being read by the processor. However, not doing that for now.
        #160;
        DIP = 16'h5555; // Set all DIP switches to flipped alternate on-off pattern
			// Changes during sw, can't capture it as lw has passed.
        #120;
			// 16'h5555 is lost as it doesn't stay until lw instruction.
        DIP = 16'h0000; // Set all DIP switches to OFF
	#150;
		
		// Additional test patterns for more comprehensive checking
		DIP = 16'h00FF; #150;
		DIP = 16'hFF00; #150;
		DIP = 16'h0F0F; #150;
		DIP = 16'hF0F0; #150;
		DIP = 16'h1234; #150;
		DIP = 16'h5678; #150;
		DIP = 16'h9ABC; #150;
		DIP = 16'hDEF0; #150;
		
		// Final summary
		#100;
		$display("\n[%0t] === FINAL TEST SUMMARY ===", $time);
		$display("Total Tests: %0d", test_count);
		$display("Passed: %0d", pass_count);
		$display("Failed: %0d", fail_count);
		if (test_count > 0) begin
			$display("Pass Rate: %0.1f%%", (pass_count * 100.0) / test_count);
			if (fail_count == 0) begin
				$display("*** ALL TESTS PASSED! ***");
			end else begin
				$display("*** %0d TESTS FAILED ***", fail_count);
			end
		end else begin
			$display("*** NO TESTS EXECUTED ***");
		end
		$display("=============================\n");
		
		$finish;
		//insert rest of the stimuli here
    end
	
	// GENERATE CLOCK       
    always          
    begin
       #5 CLK = ~CLK ; // invert clk every 5 time units 
    end
    
    integer i;
    integer tests = 0;
    integer failures = 0;
    reg [31:0] expected [0:7];
    
    // Encode ADDI.
    function [31:0] enc_addi;
        input [4:0] rd;
        input [4:0] rs1;
        input [11:0] imm;
        begin
            enc_addi = {imm, rs1, 3'b000, rd, 7'b0010011};
        end
    endfunction
    
    // Encode an M-extension instruction.
    // funct3: 000=mul, 100=div, 101=divu
    function [31:0] enc_m;
        input [2:0] funct3;
        input [4:0] rd;
        input [4:0] rs1;
        input [4:0] rs2;
        begin
            enc_m = {7'b0000001, rs2, rs1, funct3,
                     rd, 7'b0110011};
        end
    endfunction
    
    // Encode: sw rs2, 0x80(x31)
    // x31 holds MMIO_BASE, so this writes the seven-segment register.
    function [31:0] enc_display;
        input [4:0] rs2;
        begin
            enc_display = {7'b0000100, rs2, 5'd31,
                           3'b010, 5'b00000, 7'b0100011};
        end
    endfunction
    
    initial begin
        RESET = 1'b1;
        DIP = 0;
        PB = 0;
        UART_TX_ready = 1'b1;
        UART_RX_valid = 1'b0;
    
        expected[0] = 32'd60;          // 20 * 3
        expected[1] = 32'hFFFFFFC4;    // -20 * 3 = -60
        expected[2] = 32'hFFFFFFFE;    // unsigned FFFFFFFF * 2, low word
        expected[3] = 32'd6;           // signed 20 / 3
        expected[4] = 32'hFFFFFFFA;    // signed -20 / 3 = -6
        expected[5] = 32'd6;           // unsigned 20 / 3
        expected[6] = 32'h7FFFFFFF;    // unsigned FFFFFFFF / 2
        expected[7] = 32'd20;          // dependent mul then div, rd=rs1
    
        // Wait until Wrapper's time-zero memory loading has finished.
        #1;
    
        // Replace the simulated IROM with this test program.
        // These changes affect simulation only.
        for (i = 0; i < 64; i = i + 1)
            dut.IROM[i] = 32'h00000013; // NOP
    
        // lui x31, 0xFFFF0 -> MMIO base 0xFFFF0000
        dut.IROM[0] = 32'hFFFF0FB7;
    
        // 1. Positive multiplication: 20 * 3 = 60
        dut.IROM[1] = enc_addi(5'd1, 5'd0, 12'd20);
        dut.IROM[2] = enc_addi(5'd2, 5'd0, 12'd3);
        dut.IROM[3] = enc_m(3'b000, 5'd3, 5'd1, 5'd2);
        dut.IROM[4] = enc_display(5'd3);
    
        // 2. Negative multiplication: -20 * 3 = -60
        dut.IROM[5] = enc_addi(5'd1, 5'd0, 12'hFEC); // -20
        dut.IROM[6] = enc_m(3'b000, 5'd3, 5'd1, 5'd2);
        dut.IROM[7] = enc_display(5'd3);
    
        // 3. Unsigned interpretation: FFFFFFFF * 2 -> FFFFFFFE
        dut.IROM[8]  = enc_addi(5'd1, 5'd0, 12'hFFF); // FFFFFFFF
        dut.IROM[9]  = enc_addi(5'd2, 5'd0, 12'd2);
        dut.IROM[10] = enc_m(3'b000, 5'd3, 5'd1, 5'd2);
        dut.IROM[11] = enc_display(5'd3);
    
        // 4. Signed positive division: 20 / 3 = 6
        dut.IROM[12] = enc_addi(5'd1, 5'd0, 12'd20);
        dut.IROM[13] = enc_addi(5'd2, 5'd0, 12'd3);
        dut.IROM[14] = enc_m(3'b100, 5'd3, 5'd1, 5'd2);
        dut.IROM[15] = enc_display(5'd3);
    
        // 5. Signed negative division: -20 / 3 = -6
        dut.IROM[16] = enc_addi(5'd1, 5'd0, 12'hFEC);
        dut.IROM[17] = enc_m(3'b100, 5'd3, 5'd1, 5'd2);
        dut.IROM[18] = enc_display(5'd3);
    
        // 6. Unsigned division: 20 / 3 = 6
        dut.IROM[19] = enc_addi(5'd1, 5'd0, 12'd20);
        dut.IROM[20] = enc_m(3'b101, 5'd3, 5'd1, 5'd2);
        dut.IROM[21] = enc_display(5'd3);
    
        // 7. Unsigned high-bit case: FFFFFFFF / 2 = 7FFFFFFF
        dut.IROM[22] = enc_addi(5'd1, 5'd0, 12'hFFF);
        dut.IROM[23] = enc_addi(5'd2, 5'd0, 12'd2);
        dut.IROM[24] = enc_m(3'b101, 5'd3, 5'd1, 5'd2);
        dut.IROM[25] = enc_display(5'd3);
    
        // 8. Back-to-back operations, destination also a source:
        // mul x1, x1, x2 -> x1 = 60
        // div x1, x1, x2 -> x1 = 20
        dut.IROM[26] = enc_addi(5'd1, 5'd0, 12'd20);
        dut.IROM[27] = enc_addi(5'd2, 5'd0, 12'd3);
        dut.IROM[28] = enc_m(3'b000, 5'd1, 5'd1, 5'd2);
        dut.IROM[29] = enc_m(3'b100, 5'd1, 5'd1, 5'd2);
        dut.IROM[30] = enc_display(5'd1);
    
        // jal x0, 0: stay here indefinitely.
        dut.IROM[31] = 32'h0000006F;
    
        repeat (3) @(negedge CLK);
        RESET = 1'b0;
    end
    
    // Check each store to the seven-segment MMIO register.
    // These internal signal names match your supplied Wrapper.
    always @(posedge CLK) begin
        if (!RESET &&
            dut.MemWrite_out === 4'b1111 &&
            dut.ALUResult === 32'hFFFF0080) begin
    
            if (tests >= 8) begin
                $fatal(1, "Unexpected additional display write");
            end
            else begin
                if (dut.WriteData_out === expected[tests])
                    $display("PASS %0d: CPU stored %h",
                             tests + 1, dut.WriteData_out);
                else begin
                    failures = failures + 1;
                    $display("FAIL %0d: expected=%h actual=%h",
                             tests + 1, expected[tests],
                             dut.WriteData_out);
                end
    
                // Let the MMIO output register update.
                #1;
                if (SEVENSEGHEX !== expected[tests]) begin
                    failures = failures + 1;
                    $display("FAIL: seven-segment register=%h expected=%h",
                             SEVENSEGHEX, expected[tests]);
                end
    
                tests = tests + 1;
    
                if (tests == 8) begin
                    if (failures == 0) begin
                        $display("ALL 8 CPU INTEGRATION TESTS PASSED");
                        $finish;
                    end
                    else
                        $fatal(1, "CPU tests completed with %0d failures",
                               failures);
                end
            end
        end
    end
    
    initial begin
        #100000;
        $fatal(1, "TIMEOUT: only %0d of 8 tests completed", tests);
    end
    
endmodule
