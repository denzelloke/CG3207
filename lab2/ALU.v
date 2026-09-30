`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------------
-- Company: NUS	
-- Engineer: (c) Rajesh Panicker  
-- 
-- Create Date: 09/22/2020 06:49:10 PM
-- Module Name: ALU
-- Project Name: CG3207 Project
-- Target Devices: Nexys 4 / Basys 3
-- Tool Versions: Vivado 2019.2
-- Description: RISC-V Processor ALU Module
-- 
-- Dependencies: NIL
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: Interface and implementation can be modified.
-- 
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post it on any public repository;
--		(iii) accept the responsibility to ensure that your implementation does not violate anyone's intellectual property.
--		(ii) use it only for educational purposes;
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh<dot>panicker<at>ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(vi) retain this notice in this file as well as any files derived from this.
----------------------------------------------------------------------------------
*/

module ALU(
	input [31:0] Src_A,
	input [31:0] Src_B,
	input [3:0] ALUControl, // 0000 for add, 0001 for sub, 1110 for and, 1100 for or, 0010 for sll, 1010 for srl, 1011 for sra.
	output reg [31:0] ALUResult,
	output [2:0] ALUFlags //{eq, lt, ltu}
);
    
	// Shifter signals
	wire [1:0] Sh ;
	wire [4:0] Shamt5 ;
	wire [31:0] ShIn ;
	wire [31:0] ShOut ;
	
	// Other signals; 33-bits wide to accommodate the extra C_0 bit
	wire [32:0] S_wider ;
	reg [32:0] Src_A_comp ;
	reg [32:0] Src_B_comp ;
	reg [32:0] C_0 ;
	wire N, Z, C; 	// optional intermediate values to derive eq, lt, ltu
	reg V;
				// Hint: We need to care about V only for subtraction
	
	assign S_wider = Src_A_comp + Src_B_comp + C_0 ;
    
	always@(Src_A, Src_B, ALUControl, S_wider, ShOut) begin
        // default values; help avoid latches
		C_0 = 0 ; 
		Src_A_comp = {1'b0, Src_A} ;
		Src_B_comp = {1'b0, Src_B} ;
    
		case(ALUControl)
			4'b0000: ALUResult = S_wider[31:0] ;			//add; keep lower 32 bits; if carry is 1, there was no borrow ie postive result         
	            	4'b0001: begin							//sub
				C_0[0] = 1 ;  
				Src_B_comp = {1'b0, ~ Src_B} ;
				ALUResult = S_wider[31:0] ;					//keep lower 32 bits
			end
	            	4'b1110: ALUResult = Src_A & Src_B ;	// and
	            	4'b1100: ALUResult = Src_A | Src_B ; 	// or
	            
			// include cases for shifts		// shifts
			4'b0010, 4'b1010, 4'b1011: begin 
			        ALUResult = ShOut;      //SLL, SRL, SRA
			end
			default: ALUResult = 32'b0;
	        endcase
	    end
      

	// ALUFlags only for subtraction operations, specifically A-B (in this order)
	assign Z = (ALUResult == 0) ? 1'b1 : 1'b0 ;									//check result for zero
    assign N = ALUResult[31];												//check MSB for negativity
 	assign C = S_wider[32];													//check if carry bit is produced for unsigned arithmetic
	
	always @(*) begin
		if (ALUControl == 4'b0001) begin			//subtraction
			V = (Src_A[31] ^ ALUResult[31]) & (Src_A[31] ^ Src_B[31]);	
		end
		else if (ALUControl == 4'b0000) begin		//addition
			V = (Src_A[31] ^ ALUResult[31]) & ~(Src_A[31] ^ Src_B[31]);				
		
		end
		else begin
			V = 1'b0;	//no overflow for other operations
		end
	end

	assign ALUFlags = {Z, (N ^ V), ~C} ; 	//{eq, lt, ltu}; Complements of ALUFlags are {ne, ge, geu} 
    
	// Sh signals derived directly from the appropriate ALUControl bits
	assign Sh = {ALUControl[3], ALUControl[0]};
    assign ShIn = Src_A;
	assign Shamt5 = Src_B[4:0];

	// Instantiate Shifter        
	Shifter Shifter1(
                Sh,
        	Shamt5,
        	ShIn,
        	ShOut
        );
     
endmodule
