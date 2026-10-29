`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------------
-- Company: NUS	
-- Engineer: (c) Rajesh Panicker  
-- 
-- Create Date: 09/22/2020 06:49:10 PM
-- Module Name: Decoder
-- Project Name: CG3207 Project
-- Target Devices: Nexys 4 / Basys 3
-- Tool Versions: Vivado 2019.2
-- Description: RISC-V Processor Decoder Module
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
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate anyone's intellectual property.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh<dot>panicker<at>ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(vi) retain this notice in this file as well as any files derived from this.
----------------------------------------------------------------------------------
*/

module Decoder (
    input [6:0] Opcode,
    input [2:0] Funct3,
    input [6:0] Funct7,
    output reg [1:0] PCS,  // 00non-control, 01 conditional branch, 10 jal, 11 jalr
    output reg RegWrite,		// Asserted only by instructions which write to register file (load, auipc, lui, DPImm, DPReg);
    output reg MemWrite,  // Asserted only by store (sw)
    output reg MemtoReg,  // Asserted only by load (lw)
    output reg [1:0] ALUSrcA, 	// Needed lui, auipic. Refer to the microarchitecture its use. Uncomment wire and port map in RV.v as well
    output reg [1:0] ALUSrcB,		// Asserted by all instructions which use an immediate (load, store, lui, auipc, DPImm). Needs to be expanded to a 2-bit signal to support link functionality jal, jalr. Change wire width in RV.v as well
    output reg [2:0] ImmSrc,  // 000 U, 010 UJ, 011 I, 110 S, 111 SB.
    output reg [3:0] ALUControl,	// 0000 add, 0001 sub, 1110 and, 1100 or, 0010 sll, 1010 srl, 1011 sra, 0001 branch, 0000 all others.
    output reg [1:0] MCycleOp, // 00 signed multiplication, 01 unsigned multiplication, 10 signed division, 11 unsigned division.
    // Note that the most significant 3 bits are Funct3 all DP instrns. LSB is the same as Funct7[5] DPReg type and DPImm_shifts. For other DPImms, Funct7[5] is 0.
    // It is the same as sub branches, and add all others not mentioned in the line above.
    output reg [2:0] SizeSel // 0 byte || 1 halfword (S) || 2 word || 4 byte || 5 halfword (U) || ill use 7 as "not memory operation" || 3 is for doubleword, not supported
);


    always @(*) begin
        if (ALUControl == 4'b1111) begin
            case (Funct3)
                3'h0: MCycleOp = 2'b00;  // mul

                3'h1: MCycleOp = 2'b00;  // mulh

                // 3'h2: MCycleOp = 2'b01;  // mulhsu

                3'h3: MCycleOp = 2'b01;  // mulhu

                3'h4: MCycleOp = 2'b10;  // div

                3'h5: MCycleOp = 2'b11;  // divu

                3'h6: MCycleOp = 2'b10;  // rem

                3'h7: MCycleOp = 2'b11;  // remu 

                default: MCycleOp = 2'b00;
            endcase
        end

        else MCycleOp = 2'b00;
    end

    always @(*) begin
        case (Opcode)

            // DP Reg
            7'h33: begin
                PCS      = 2'b00;
                MemtoReg = 0;
                RegWrite = 1;
                MemWrite = 0;
                ALUSrcA  = 2'b00;
                ALUSrcB  = 2'b00;
                ImmSrc   = 3'b000;
                if (Funct7 == 7'b0000001) ALUControl = 4'b1111;
                else ALUControl = {Funct3, Funct7[5]};
                SizeSel = 3'b111;
            end

            // DP Imm
            7'h13: begin
                PCS = 2'b00;
                MemtoReg = 0;
                RegWrite = 1;
                MemWrite = 0;
                ALUSrcA = 2'b00;
                ALUSrcB = 2'b11;
                ImmSrc = 3'b011;  // I type
                ALUControl[3:1] = Funct3;
                ALUControl[0] = (Funct3 == 3'h5) ? Funct7[5] : 1'b0;
                SizeSel = 3'b111;
            end

            // branch 
            7'h63: begin
                PCS        = 2'b01;
                MemtoReg   = 0;
                RegWrite   = 0;
                MemWrite   = 0;
                ALUSrcA    = 2'b00;
                ALUSrcB    = 2'b00;
                ImmSrc     = 3'b111;  // B type
                ALUControl = 4'b0001;  // sub
                SizeSel    = 3'b111;
            end

            // jal 
            7'h6F: begin
                PCS        = 2'b10;
                MemtoReg   = 0;
                RegWrite   = 1;
                MemWrite   = 0;
                ALUSrcA    = 2'b11;
                ALUSrcB    = 2'b01;
                ImmSrc     = 3'b010;  // J type
                ALUControl = 4'b0000;  // add
                SizeSel    = 3'b111;
            end

            // auipc 
            7'h17: begin
                PCS        = 2'b00;
                MemtoReg   = 0;
                RegWrite   = 1;
                MemWrite   = 0;
                ALUSrcA    = 2'b11;
                ALUSrcB    = 2'b11;
                ImmSrc     = 3'b000;  // U type
                ALUControl = 4'b0000;  // add
                SizeSel    = 3'b111;
            end

            // lui 
            7'h37: begin
                PCS        = 2'b00;
                MemtoReg   = 0;
                RegWrite   = 1;
                MemWrite   = 0;
                ALUSrcA    = 2'b01;
                ALUSrcB    = 2'b11;
                ImmSrc     = 3'b000;  // U type
                ALUControl = 4'b0000;  // add
                SizeSel    = 3'b111;
            end

            // jalr
            7'h67: begin
                PCS        = 2'b11;
                MemtoReg   = 0;
                RegWrite   = 1;
                MemWrite   = 0;
                ALUSrcA    = 2'b11;
                ALUSrcB    = 2'b01;
                ImmSrc     = 3'b011;  // I type
                ALUControl = 4'b0000;  // add
                SizeSel    = 3'b111;
            end

            // load 
            7'h03: begin
                PCS = 2'b00;
                MemtoReg = 1;
                RegWrite = (Funct3 == 3'h0 || Funct3 == 3'h1 || Funct3 == 3'h2 || Funct3 == 3'h4 || Funct3 == 3'h5) ? 1 : 0;
                MemWrite = 0;
                ALUSrcA = 2'b00;
                ALUSrcB = 2'b11;
                ImmSrc = 3'b011;  // I type
                ALUControl = 4'b0000;  // add
                SizeSel    = (Funct3 == 3'h0 || Funct3 == 3'h1 || Funct3 == 3'h2 || Funct3 == 3'h4 || Funct3 == 3'h5) ? Funct3 : 3'b111;
                // 0 byte || 1 halfword (S) || 2 word || 4 byte (U) || 5 halfword (U) || ill use 7 as "not memory operation"
            end

            // store 
            7'h23: begin
                PCS = 2'b00;
                MemtoReg = 0;
                RegWrite = 0;
                MemWrite = (Funct3 == 3'h0 || Funct3 == 3'h1 || Funct3 == 3'h2) ? 1 : 0;
                ALUSrcA = 2'b00;
                ALUSrcB = 2'b11;
                ImmSrc = 3'b110;  // S type
                ALUControl = 4'b0000;  // add
                SizeSel = (Funct3 == 3'h0 || Funct3 == 3'h1 || Funct3 == 3'h2) ? Funct3 : 3'b111;
                // 0 byte || 1 halfword (S) || 2 word || ill use 7 as "not memory operation"
            end

            // default
            default: begin
                PCS        = 2'b00;
                MemtoReg   = 0;
                RegWrite   = 0;
                MemWrite   = 0;
                ALUSrcA    = 2'b00;
                ALUSrcB    = 2'b00;
                ImmSrc     = 3'b000;
                ALUControl = 4'b0000;
                SizeSel    = 3'b111;
            end
        endcase
    end
endmodule


