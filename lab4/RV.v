`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------------
-- Company: NUS	
-- Engineer: (c) Rajesh Panicker  
-- 
-- Create Date: 09/22/2020 06:49:10 PM
-- Module Name: RV
-- Project Name: CG3207 Project
-- Target Devices: Nexys 4 / Basys 3
-- Tool Versions: Vivado 2019.2
-- Description: RISC-V Processor Module
-- 
-- Dependencies: NIL
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: The interface SHOULD NOT be modified (except making output reg) unless you modify Wrapper.v/vhd too. 
                        The implementation can be modified.
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

module RV #(
    parameter PC_INIT = 32'h00400000
) (
    input CLK,
    input RESET,
    //input Interrupt,      // for optional future use.
    input [31:0] Instr,
    input [31:0] ReadData_in,  // Name mangled to support lb/lbu/lh/lhu
    output MemRead,
    output [3:0] MemWrite_out,  // Column-wise write enable to support sb/sw. Each column is a byte.
    output [31:0] PC,
    output [31:0] ALUResult,
    output [31:0] WriteData_out  // Name mangled to support sb/sw
);

    // Please read Lab 4 Enhancement: Implementing additional instructions on how to support lb/lbu/lh/lhu/sb/sh

    //RV Signals
    wire [ 2:0] SizeSel;  //to support lb/lbu/lh/lhu/sb/sh
    wire [31:0] ReadData;
    wire [31:0] WriteData;
    wire        MemWrite;

    // RegFile signals
    wire        WE;
    wire [ 4:0] rs1;
    wire [ 4:0] rs2;
    wire [ 4:0] rd;
    wire [31:0] WD;
    wire [31:0] R15;
    wire [31:0] RD1;
    wire [31:0] RD2;
    wire [31:0] Result;
    wire        RegWrite;
    wire [ 3:0] ALUControl;
    assign WE = RegWrite && WE_PC && !RESET; // regfile doesnt stall even if we_pc = 0. cos regfile writes on posedge & we=1
    assign rs1 = Instr[19:15];
    assign rs2 = Instr[24:20];
    assign rd  = Instr[11:7];
    reg [31:0] MCycle_res;
    assign Result = (ALUControl == 4'b1111) ? MCycle_res : ALUResult;
    wire MemtoReg;
    assign WD = (MemtoReg) ? ReadData : Result;

    // Extend Module signals
    wire [ 2:0] ImmSrc;
    wire [24:0] InstrImm;
    wire [31:0] ExtImm;
    assign InstrImm = Instr[31:7];

    // Decoder signals
    wire [6:0] Opcode;
    wire [2:0] Funct3;
    wire [6:0] Funct7;
    wire [1:0] PCS;
    wire [1:0] ALUSrcA;
    wire [1:0] ALUSrcB;
    assign Funct3 = Instr[14:12];
    assign Opcode = Instr[6:0];
    assign Funct7 = Instr[31:25];

    // PC_Logic signals
    wire [ 2:0] ALUFlags;
    wire [ 1:0] PCSrc;

    // ALU signals
    reg  [31:0] Src_A;
    reg  [31:0] Src_B;

    // ProgramCounter signals
    wire        WE_PC;
    reg  [31:0] PC_IN;
    wire        Busy;
    assign WE_PC = ~Busy;
    always @(*) begin
        case (PCSrc)
            2'b00:   PC_IN = PC + 32'd4;  //non-control
            2'b01:   PC_IN = PC + ExtImm;  //jal
            2'b11:   PC_IN = (RD1 + ExtImm) & ~32'd1;  //jalr
            default: PC_IN = PC + 32'd4;  //default case
        endcase
    end

    // Data Memory signals
    assign WriteData = RD2;

    // ALU signals
    always @(*) begin
        Src_A = RD1;
        Src_B = RD2;
        case (ALUSrcA)
            2'b00, 2'b10: Src_A = RD1;  // DP Reg, DP Imm, load, store, branch
            2'b11:        Src_A = PC;  // jal, auipc, jalr
            2'b01:        Src_A = 32'b0;  //lui
        endcase
        case (ALUSrcB)
            2'b00, 2'b10: Src_B = RD2;  // DP Reg, branch
            2'b11:        Src_B = ExtImm;  // DP Imm, load, store, auipc, lui
            2'b01:        Src_B = 32'd4;  // jal, jalr
        endcase
    end

    // Other internal signals here
    // wire [31:0] PC_Offset;
    // wire [31:0] PC_Target; 
    // wire [31:0] PCSrc_B;  
    assign MemRead = MemtoReg; // This is needed for the proper functionality of some devices such as UART CONSOLE
    assign ReadData = ReadData_in;  // Change datapath as appropriate if supporting lb/lbu/lh/lhu
    assign WriteData_out = WriteData;  // Change datapath as appropriate if supporting sb/sh
    assign MemWrite_out = {4{MemWrite}};  // Change datapath as appropriate if supporting sb/sh
    assign SizeSel = 3'b010;             // Change this to be generated by the Decoder (control) as appropriate if 
                                         // supporting lb/sb/lbu/lh/sh/lhu/lw/sw. Hint: funct3
    // multicycle signals
    wire Start;
    wire [1:0] MCycleOp;
    wire [31:0] Operand1;
    wire [31:0] Operand2;
    wire [31:0] Result1;
    wire [31:0] Result2;
    assign Start = (ALUControl == 4'b1111);
    assign Operand1 = RD1;
    assign Operand2 = RD2;
    always @(*) begin
        if (Funct3 == 3'h0 || Funct3 == 3'h4 || Funct3 == 3'h5)
            MCycle_res = Result1;  // lsw or quotient

        else MCycle_res = Result2;  // hsw / remainder
    end
    
    MCycle MCycle1 (
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

    RegFile RegFile1 (
        CLK,
        WE,
        rs1,
        rs2,
        rd,
        WD,
        RD1,
        RD2
    );

    Extend Extend1 (
        ImmSrc,
        InstrImm,
        ExtImm
    );

    Decoder Decoder1 (
        Opcode,
        Funct3,
        Funct7,
        PCS,
        RegWrite,
        MemWrite,
        MemtoReg,
        ALUSrcA,
        ALUSrcB,
        ImmSrc,
        ALUControl,
        MCycleOp
    );

    PC_Logic PC_Logic1 (
        PCS,
        Funct3,
        ALUFlags,
        PCSrc
    );

    ALU ALU1 (
        Src_A,
        Src_B,
        ALUControl,
        Funct3,
        ALUResult,
        ALUFlags
    );

    ProgramCounter #(
        .PC_INIT(PC_INIT)
    ) ProgramCounter1 (
        CLK,
        RESET,
        WE_PC,
        PC_IN,
        PC
    );
endmodule
