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
    output [31:0] PCF,
    output [31:0] ALUResult,
    output [31:0] WriteData_out  // Name mangled to support sb/sw
);

    // -------------------------------------------------------------------------
    // Signal declarations
    // -------------------------------------------------------------------------

    // Fetch stage
    wire [31:0] InstrF;
    wire        WE_PC;
    reg  [31:0] PC_IN;

    // Decode stage: instruction fields and control
    wire [31:0] InstrD;
    wire [31:0] PCD;
    wire [6:0]  Opcode;
    wire [6:0]  Funct7;
    wire [2:0]  func3D;
    wire [4:0]  rs1D, rs2D, rdD;
    wire [24:0] InstrImm;
    wire [2:0]  ImmSrc;
    wire [31:0] ExtImmD;
    wire [1:0]  PCSD;
    wire        RegWriteD, MemtoRegD, MemWriteD;
    wire [3:0]  ALUControlD;
    wire [1:0]  ALUSrcAD, ALUSrcBD;
    wire [1:0]  MCycleOpD;
    wire        UsesRs1D, UsesRs2D;

    // Decode stage: register operands and W-to-D forwarding
    wire [31:0] RD1D, RD2D;
    wire [31:0] RD1D_P, RD2D_P;

    // Execute stage: pipelined control and operands
    wire [31:0] PCE;
    wire [2:0]  func3E;
    wire [1:0]  PCSE;
    wire        RegWriteE, MemtoRegE, MemWriteE;
    wire [3:0]  ALUControlE;
    wire [1:0]  ALUSrcAE, ALUSrcBE;
    wire [31:0] RD1E, RD2E;
    wire [31:0] ExtImmE;
    wire [4:0]  rdE;
    reg  [4:0]  rs1E, rs2E;
    reg  [1:0]  MCycleOpE;

    // Execute stage: forwarding, ALU, and branch datapath
    reg  [31:0] SrcA_tmp, SrcB_tmp;
    reg  [31:0] Src_A, Src_B;
    wire [31:0] RD1FwdE;
    wire [31:0] WriteDataE;
    wire [31:0] ALUResultE;
    wire [31:0] EREGResult;
    wire [2:0]  ALUFlags;
    wire [1:0]  PCSrcE;

    // Execute stage: multi-cycle multiply/divide
    wire        IsMCycleE;
    wire        Start;
    wire        Busy;
    wire        MCYCLESTALL;
    reg         MCycleStarted;
    wire [31:0] Operand1, Operand2;
    wire [31:0] Result1, Result2;
    reg  [31:0] MCycle_res;

    // Memory stage and external memory interface
    wire        RegWriteM, MemtoRegM, MemWriteM;
    wire [31:0] ALUResultM;
    wire [31:0] WriteDataM;
    wire [31:0] ReadDataM;
    wire [4:0]  rdM;
    reg  [4:0]  rs2M;
    wire [31:0] WriteData;
    wire [2:0]  SizeSel;  // Reserved for byte/half-word access support.

    // Write-back stage and register-file write port
    wire        RegWriteW, MemtoRegW;
    wire [31:0] ReadDataW;
    wire [31:0] ALUResultW;
    wire [31:0] ResultW;
    wire [4:0]  rdW;
    wire        WE;
    wire [31:0] WD;

    // Hazard control
    wire        StallF, StallD, StallE;
    wire        FlushD, FlushE, FlushM;
    wire        Forward1D, Forward2D;
    wire [1:0]  ForwardAE, ForwardBE;
    wire        ForwardM;

    // -------------------------------------------------------------------------
    // Fetch stage and next-PC selection
    // -------------------------------------------------------------------------

    assign InstrF = Instr;
    assign WE_PC  = !StallF;

    always @(*) begin
        case (PCSrcE)
            2'b00:   PC_IN = PCF + 32'd4;                 // Sequential execution
            2'b01:   PC_IN = PCE + ExtImmE;               // PC-relative target
            2'b11:   PC_IN = (RD1FwdE + ExtImmE) & ~32'd1; // jalr; clear bit 0
            default: PC_IN = PCF + 32'd4;
        endcase
    end

    // -------------------------------------------------------------------------
    // Decode stage: instruction fields and operand forwarding
    // -------------------------------------------------------------------------

    assign Opcode   = InstrD[6:0];
    assign func3D   = InstrD[14:12];
    assign Funct7   = InstrD[31:25];
    assign rs1D     = InstrD[19:15];
    assign rs2D     = InstrD[24:20];
    assign rdD      = InstrD[11:7];
    assign InstrImm = InstrD[31:7];

    assign RD1D_P = Forward1D ? ResultW : RD1D;
    assign RD2D_P = Forward2D ? ResultW : RD2D;

    // Source-register usage for hazard detection.
    assign UsesRs1D =
        (Opcode == 7'b0110011) ||  // Register ALU, including multiply/divide
        (Opcode == 7'b0010011) ||  // Immediate ALU
        (Opcode == 7'b0000011) ||  // Loads
        (Opcode == 7'b0100011) ||  // Stores: rs1 is the address base
        (Opcode == 7'b1100011) ||  // Conditional branches
        (Opcode == 7'b1100111);    // JALR

    assign UsesRs2D =
        (Opcode == 7'b0110011) ||  // Register ALU, including multiply/divide
        (Opcode == 7'b1100011);    // Conditional branches

    // -------------------------------------------------------------------------
    // Execute stage: forwarding and ALU operand selection
    // -------------------------------------------------------------------------

    always @(*) begin
        Src_A    = RD1E;
        Src_B    = RD2E;
        SrcA_tmp = RD1E;
        SrcB_tmp = RD2E;

        // Forward register operands from Memory or Write-back.
        case (ForwardAE)
            2'b00: SrcA_tmp = RD1E;
            2'b01: SrcA_tmp = ResultW;
            2'b10: SrcA_tmp = ALUResultM;
        endcase

        case (ForwardBE)
            2'b00: SrcB_tmp = RD2E;
            2'b01: SrcB_tmp = ResultW;
            2'b10: SrcB_tmp = ALUResultM;
        endcase

        // Select the final ALU inputs.
        case (ALUSrcAE)
            2'b00, 2'b10: Src_A = SrcA_tmp;
            2'b01:        Src_A = 32'b0;
            2'b11:        Src_A = PCE;
        endcase

        case (ALUSrcBE)
            2'b00, 2'b10: Src_B = SrcB_tmp;
            2'b01:        Src_B = 32'd4;
            2'b11:        Src_B = ExtImmE;
        endcase
    end

    assign WriteDataE = SrcB_tmp;
    assign RD1FwdE    = SrcA_tmp;
    assign EREGResult = (ALUControlE == 4'b1111) ? MCycle_res : ALUResultE;

    // -------------------------------------------------------------------------
    // Execute stage: multi-cycle multiply/divide control and result selection
    // -------------------------------------------------------------------------

    assign Operand1  = SrcA_tmp;
    assign Operand2  = SrcB_tmp;
    assign IsMCycleE = (ALUControlE == 4'b1111);

    // Issue Start only once for the instruction held in Execute.
    assign Start = IsMCycleE && !MCycleStarted && !RESET;

    // Stall on the launch cycle and while the unit is busy.
    assign MCYCLESTALL = IsMCycleE && (!MCycleStarted || Busy);

    always @(*) begin
        if (func3E == 3'h0 || func3E == 3'h4 || func3E == 3'h5)
            MCycle_res = Result1;  // Low product word or quotient
        else
            MCycle_res = Result2;  // High product word or remainder
    end

    always @(posedge CLK) begin
        if (RESET || FlushE)
            MCycleStarted <= 1'b0;
        else if (Start)
            MCycleStarted <= 1'b1;
        else if (!StallE)
            MCycleStarted <= 1'b0;
    end

    // -------------------------------------------------------------------------
    // Auxiliary pipeline registers for hazard and multi-cycle control
    // -------------------------------------------------------------------------

    always @(posedge CLK) begin
        if (FlushE) begin
            rs1E      <= 5'd0;
            rs2E      <= 5'd0;
            MCycleOpE <= 2'b00;
        end
        else if (!StallE) begin
            rs1E      <= rs1D;
            rs2E      <= rs2D;
            MCycleOpE <= MCycleOpD;
        end

        if (FlushM)
            rs2M <= 5'd0;
        else
            rs2M <= rs2E;
    end

    // -------------------------------------------------------------------------
    // Memory stage: external interface and W-to-M store-data forwarding
    // -------------------------------------------------------------------------

    // MemRead is required for devices such as the UART console.
    assign MemRead   = MemtoRegM;
    assign ALUResult = ALUResultM;
    assign WriteData = ForwardM ? ResultW : WriteDataM;

    // Current implementation supports word accesses only.
    // For lb/lbu/lh/lhu/sb/sh, derive SizeSel from the decoder (funct3), carry
    // it through the pipeline, and update load extension, store-data alignment,
    // and byte-write enables. See Lab 4 Enhancement: additional instructions.
    assign SizeSel       = 3'b010;
    assign ReadDataM     = ReadData_in;
    assign WriteData_out = WriteData;
    assign MemWrite_out  = {4{MemWriteM}};

    // -------------------------------------------------------------------------
    // Write-back stage
    // -------------------------------------------------------------------------

    assign ResultW = MemtoRegW ? ReadDataW : ALUResultW;
    assign WD      = ResultW;

    // Register-file writes are independent of the PC write enable.
    assign WE = RegWriteW && !RESET;

    DRegister DRegister1 (
        CLK,
        !StallD,
        FlushD,
        InstrF,
        PCF,
        PCD,
        InstrD
    );

    ERegister ERegister1 (
        CLK,
        FlushE,
        StallE,
        func3D,
        PCSD,
        RegWriteD,
        MemtoRegD,
        MemWriteD,
        ALUControlD,
        ALUSrcAD,
        ALUSrcBD,
        RD1D_P,
        RD2D_P,
        ExtImmD,
        rdD,
        PCD,
        func3E,
        PCSE,
        RegWriteE,
        MemtoRegE,
        MemWriteE,
        ALUControlE,
        ALUSrcAE,
        ALUSrcBE,
        RD1E,
        RD2E,
        ExtImmE,
        rdE,
        PCE
    );
    

    MRegister Mregister1 (
        CLK,
        FlushM,
        RegWriteE,
        MemtoRegE, 
        MemWriteE,
        EREGResult,
        WriteDataE,
        rdE,
        RegWriteM, 
        MemtoRegM, 
        MemWriteM,
        ALUResultM, 
        WriteDataM,
        rdM
    );

    WRegister  WRegister1(
        CLK,
        RegWriteM, 
        MemtoRegM,
        ReadDataM,
        ALUResultM,
        rdM,
        RegWriteW, 
        MemtoRegW,
        ReadDataW,
        ALUResultW,
        rdW
    );

    HazardUnit HazardUnit1 (
        rs1D, 
        rs2D, 
        rs1E,
        rs2E,
        rdE,
        rs2M,
        rdM,
        rdW,
        MemtoRegE,
        PCSrcE,
        RegWriteM,
        MemWriteM,
        RegWriteW,
        MemtoRegW,
        UsesRs1D,
        UsesRs2D,
        MCYCLESTALL,
        StallF,
        StallD,
        StallE,
        FlushD,
        FlushE,
        FlushM,
        Forward1D,
        Forward2D,
        ForwardBE,
        ForwardAE,
        ForwardM
    );

    
    MCycle MCycle1 (
        CLK,
        RESET,
        Start,
        MCycleOpE,
        Operand1,
        Operand2,
        Result1,
        Result2,
        Busy
    );

    RegFile RegFile1 (
        CLK,
        WE,
        rs1D,
        rs2D,
        rdW,
        WD,
        RD1D,
        RD2D
    );

    Extend Extend1 (
        ImmSrc,
        InstrImm,
        ExtImmD
    );

    Decoder Decoder1 (
        Opcode,
        func3D,
        Funct7,
        PCSD,
        RegWriteD,
        MemWriteD,
        MemtoRegD,
        ALUSrcAD,
        ALUSrcBD,
        ImmSrc,
        ALUControlD,
        MCycleOpD
    );

    PC_Logic PC_Logic1 (
        PCSE,
        func3E,
        ALUFlags,
        PCSrcE
    );

    ALU ALU1 (
        Src_A,
        Src_B,
        ALUControlE,
        func3E,
        ALUResultE,
        ALUFlags
    );

    ProgramCounter #(
        .PC_INIT(PC_INIT)
    ) ProgramCounter1 (
        CLK,
        RESET,
        WE_PC,
        PC_IN,
        PCF
    );
endmodule
