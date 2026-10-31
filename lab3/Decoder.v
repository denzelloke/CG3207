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
    output reg [1:0] PCS,
    output reg RegWrite,		
    output reg MemWrite, 
    output reg MemtoReg,  
    output reg [1:0] ALUSrcA, 	
    output reg [1:0] ALUSrcB,		
    output reg [2:0] ImmSrc,  
    output reg [3:0] ALUControl	,
    output reg [1:0] MCycleOp,
    output reg Start,
    output reg [1:0] ResultMux
);
  // Change wire to reg if assigned inside a procedural (always) block. However, where it is easy enough, use assign instead of always.
  // A 2-1 multiplexing can be done easily using an assign with a ternary operator
  // For multiplexing with number of inputs > 2, a case construct within an always block is a natural fit. DO NOT to use nested ternary assignment operator as it hampers the readability of your code.

  // Decoder implementation is as follows:
  always @(*) begin
    ResultMux = 2'b00;
    Start = 1'b0;
    MCycleOp = 2'b00;
    case (Opcode)
      7'h33: begin  // DP Reg
        PCS        = 2'b00;
        MemtoReg   = 0;
        RegWrite   = 1;
        MemWrite   = 0;
        ALUSrcA    = 2'b00;
        ALUSrcB    = 2'b00;
        ImmSrc     = 3'b000;  //R type; 000 is an arbitrary default value
        ALUControl = {Funct3, Funct7[5]};
        //check for M, override
        if(Funct7 == 7'b0000001) begin
          //usigned Muli
          case (Funct3) 
            3'h0: begin // mul SIGNED
                MCycleOp  = 2'b00;
                Start     = 1'b1;
                ResultMux = 2'b10;
            end
            3'h1: begin // mulh SIGNED
                MCycleOp  = 2'b00;
                Start     = 1'b1;
                ResultMux = 2'b11;
            end
            // 3'h2: begin // mulhsu
            //     MCycleOp  = 2'b00;
            //     Start     = 1'b1;
            //     ResultMux = 1'b1;
            // end
            3'h3: begin // mulhu
                MCycleOp  = 2'b01;
                Start     = 1'b1;
                ResultMux = 2'b11;
            end
            3'h4: begin // div
                MCycleOp  = 2'b10;
                Start     = 1'b1;
                ResultMux = 2'b10;
            end
            3'h5: begin // divu
                MCycleOp  = 2'b11;
                Start     = 1'b1;
                ResultMux = 2'b10;
            end
            3'h6: begin // rem
                MCycleOp  = 2'b10;
                Start     = 1'b1;
                ResultMux = 2'b11;
            end
            3'h7: begin // remu
                MCycleOp  = 2'b11;
                Start     = 1'b1;
                ResultMux = 2'b11;
            end
            default: MCycleOp = 2'b00;
          endcase
        end
      end
      7'h13: begin  // DP Imm
        PCS = 2'b00;
        MemtoReg = 0;
        RegWrite = 1;
        MemWrite = 0;
        ALUSrcA = 2'b00;
        ALUSrcB = 2'b11;
        ImmSrc = 3'b011;  // I type
        ALUControl[3:1] = Funct3;
        ALUControl [0] = (Funct3 == 3'h5) ? Funct7[5] : 1'b0;   //alucontrol[0] is funct7[5] when funct3 = 0x5 ie srli/srai operations; funct7[5] is technically the immediate 
      end
      7'h03: begin  // load 
        PCS        = 2'b00;
        MemtoReg   = 1;
        RegWrite   = 1;
        MemWrite   = 0;
        ALUSrcA    = 2'b00;
        ALUSrcB    = 2'b11;
        ImmSrc     = 3'b011;  // I type
        ALUControl = 4'b0000;  // add
      end
      7'h23: begin  // store 
        PCS        = 2'b00;
        MemtoReg   = 0;
        RegWrite   = 0;
        MemWrite   = 1;
        ALUSrcA    = 2'b00;
        ALUSrcB    = 2'b11;
        ImmSrc     = 3'b110;  // S type
        ALUControl = 4'b0000;  // add
      end
      7'h63: begin  // branch 
        PCS        = 2'b01;
        MemtoReg   = 0;
        RegWrite   = 0;
        MemWrite   = 0;
        ALUSrcA    = 2'b00;
        ALUSrcB    = 2'b00;
        ImmSrc     = 3'b111;  // B type
        ALUControl = 4'b0001;  // sub
      end
      7'h6F: begin  // jal 
        PCS        = 2'b10;
        MemtoReg   = 0;
        RegWrite   = 1;
        MemWrite   = 0;
        ALUSrcA    = 2'b11;
        ALUSrcB    = 2'b01;
        ImmSrc     = 3'b010;  // J type
        ALUControl = 4'b0000;  // add
      end
      7'h17: begin  // auipc 
        PCS        = 2'b00;
        MemtoReg   = 0;
        RegWrite   = 1;
        MemWrite   = 0;
        ALUSrcA    = 2'b11;
        ALUSrcB    = 2'b11;
        ImmSrc     = 3'b000;  // U type
        ALUControl = 4'b0000;  // add
      end
      7'h37: begin  // lui 
        PCS        = 2'b00;
        MemtoReg   = 0;
        RegWrite   = 1;
        MemWrite   = 0;
        ALUSrcA    = 2'b01;
        ALUSrcB    = 2'b11;
        ImmSrc     = 3'b000;  // U type
        ALUControl = 4'b0000;  // add
      end
      7'h67: begin  // jalr 
        PCS        = 2'b11;
        MemtoReg   = 0;
        RegWrite   = 1;
        MemWrite   = 0;
        ALUSrcA    = 2'b11;
        ALUSrcB    = 2'b01;
        ImmSrc     = 3'b011;  // I type
        ALUControl = 4'b0000;  // add
      end
      default: begin
        PCS        = 2'b00;
        MemtoReg   = 0;
        RegWrite   = 0;
        MemWrite   = 0;
        ALUSrcA    = 2'b00;
        ALUSrcB    = 2'b00;
        ImmSrc     = 3'b011;  // I type
        ALUControl = 4'b0000;  // add
      end
    endcase
  end
endmodule



