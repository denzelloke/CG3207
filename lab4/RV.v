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

//TODO: WE_PC need to change to active low?
//TODO: 1. add suffixes for wires, ports and regs
//TODO: 2. add pipelining regs
//TODO: 3. add mux for PC_E and PC_F which PCSrcE controls
//TODO: 4. make sure connections between datapaths are correct (such as ALUControl_D going thru E register, etc.)

module RV #(
    parameter PC_INIT = 32'h00400000
) (
    input CLK,
    input RESET,
    //input Interrupt,      // for optional future use.
    input [31:0] Instr_F,
    input [31:0] ReadData_in_F,  // Name mangled to support lb/lbu/lh/lhu
    output MemRead_M,           // assigned to MemtoReg_D 
    output [3:0] MemWrite_out_M,  // Column-wise write enable to support sb/sw. Each column is a byte.
    output [31:0] PC_F,
    output [31:0] ALUResult_E,
    output [31:0] WriteData_out_M  // Name mangled to support sb/sw
);

    // Please read Lab 4 Enhancement: Implementing additional instructions on how to support lb/lbu/lh/lhu/sb/sh

    //RV Signals
    wire [ 2:0] SizeSel;  //to support lb/lbu/lh/lhu/sb/sh
    wire [31:0] ReadData_F;
    wire [31:0] WriteData_M;
    wire        MemWrite_D;

    //Decode Stage Signals
    reg [31:0] Instr_D;
    reg [31:0] PC_D;
    reg [31:0] rd_D;        //delayed until writeback stage
    assign rd_D = Instr_D[11:7];

    //Encode Stage Signals
    reg [31:0] rd_E;
    reg [31:0] PC_E;
    reg [31:0] ExtImm_E;
    reg [31:0] RD1_E;
    reg [31:0] RD2_E;
    reg [1:0] PCS_E;
    reg RegWrite_E;
    reg MemtoReg_E;
    reg MemWrite_E;
    reg [3:0] ALUControl_E;
    reg ALUSrcB_E;


    // RegFile signals
    wire        WE_D;
    wire [ 4:0] rs1_D;
    wire [ 4:0] rs2_D;
    wire [ 4:0] rd_W;
    wire [31:0] WD_W;
    wire [31:0] R15;        //TODO: what is this for???
    wire [31:0] RD1_D;
    wire [31:0] RD2_D;
    wire [31:0] Result_W;
    wire        RegWrite_D;
    wire [ 3:0] ALUControl_D;
    assign WE_D = RegWrite_D && WE_PC && !RESET; // regfile doesnt stall even if we_pc = 0. cos regfile writes on posedge & we=1
    assign rs1_D = Instr_D[19:15];
    assign rs2_D = Instr_D[24:20];
    //assign rd_W  = Instr_D[11:7];     //TODO: assign rd_W based on rd_W from W reg
    reg [31:0] MCycle_res;          //TODO: change suffix?
    assign Result_W = (ALUControl_D == 4'b1111) ? MCycle_res : ALUResult_E;
    wire MemtoReg_D;
    assign WD_W = (MemtoReg_D) ? ReadData_F : Result_W;

    // Extend Module signals
    wire [ 2:0] ImmSrc_D;
    wire [24:0] InstrImm_D;
    wire [31:0] ExtImm_D;
    assign InstrImm_D = Instr_D[31:7];

    // Decoder signals
    wire [6:0] Opcode_D;
    wire [2:0] Funct3_D;
    wire [6:0] Funct7_D;
    wire [1:0] PCS_D;
    wire [1:0] ALUSrcA_D;         //TODO: becomes Forwarding muxA
    wire [1:0] ALUSrcB_D;         //TODO: need to add Forwarding muxB on top of this
    assign Funct3_D = Instr_D[14:12];
    assign Opcode_D = Instr_D[6:0];
    assign Funct7_D = Instr_D[31:25];

    // PC_Logic signals
    wire [ 2:0] ALUFlags_E;
    wire [ 1:0] PCSrc_E;

    // ALU signals
    reg  [31:0] Src_A_E;
    reg  [31:0] Src_B_E;

    // ProgramCounter signals
    wire        WE_PC;          //TODO: to change suffix? this is assigned by MCycle
    reg  [31:0] PC_IN_F;
    wire        Busy;
    assign WE_PC = ~Busy;
    always @(*) begin
        case (PCSrc_E)
            2'b00:   PC_IN_F = PC_F + 32'd4;  //non-control
            2'b01:   PC_IN_F = PC_F + ExtImm_E;  //jal
            2'b11:   PC_IN_F = (RD1_D + ExtImm_E) & ~32'd1;  //jalr
            default: PC_IN_F = PC_F + 32'd4;  //default case
        endcase
    end

    // Data Memory signals
    assign WriteData_M = RD2_D;

    // ALU signals
    always @(*) begin
        Src_A_E = RD1_D;
        Src_B_E = RD2_D;
        case (ALUSrcA_D)
            2'b00, 2'b10: Src_A_E = RD1_D;  // DP Reg, DP Imm, load, store, branch
            2'b11:        Src_A_E = PC_F;  // jal, auipc, jalr
            2'b01:        Src_A_E = 32'b0;  //lui
        endcase
        case (ALUSrcB_D)
            2'b00, 2'b10: Src_B_E = RD2_D;  // DP Reg, branch
            2'b11:        Src_B_E = ExtImm_E;  // DP Imm, load, store, auipc, lui
            2'b01:        Src_B_E = 32'd4;  // jal, jalr
        endcase
    end

    // Other internal signals here
    // wire [31:0] PC_Offset;
    // wire [31:0] PC_Target; 
    // wire [31:0] PCSrc_B;  
    assign MemRead_M = MemtoReg_D; // This is needed for the proper functionality of some devices such as UART CONSOLE
    assign ReadData_F = ReadData_in_F;  // Change datapath as appropriate if supporting lb/lbu/lh/lhu
    assign WriteData_out_M = WriteData_M;  // Change datapath as appropriate if supporting sb/sh
    assign MemWrite_out_M = {4{MemWrite_D}};  // Change datapath as appropriate if supporting sb/sh
    assign SizeSel = 3'b010;             // Change this to be generated by the Decoder (control) as appropriate if 
                                         // supporting lb/sb/lbu/lh/sh/lhu/lw/sw. Hint: funct3
    // multicycle signals
    //TODO: see if need to change anything?
    wire Start;
    wire [1:0] MCycleOp;
    wire [31:0] Operand1;
    wire [31:0] Operand2;
    wire [31:0] Result1;
    wire [31:0] Result2;
    assign Start = (ALUControl_D == 4'b1111);
    assign Operand1 = RD1_D;
    assign Operand2 = RD2_D;
    always @(*) begin
        if (Funct3_D == 3'h0 || Funct3_D == 3'h4 || Funct3_D == 3'h5)
            MCycle_res = Result1;  // lsw or quotient

        else MCycle_res = Result2;  // hsw / remainder
    end

    //change from combinational logic to clocked logic
    //F to D Stage
    always @ (*) begin
        Instr_D <= Instr_F;
        PC_D <= PC_F;
    end

    //D to E Stage
    always @ (*) begin
        rd_E <= rd_D;
        PC_E <= PC_D;
        ExtImm_E <= ExtImm_D;
        RD1_E <= RD1_D;
        RD2_E <= RD2_D;
        PCS_E <= PCS_D;
        RegWrite_E <= RegWrite_D;
        MemtoReg_E <= MemtoReg_D;
        MemWrite_E <= MemWrite_D;
        ALUControl_E <= ALUControl_D;
        ALUSrcB_E <= ALUSrcB_D;

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
        WE_D,
        rs1_D,
        rs2_D,
        rd_W,
        WD_W,
        RD1_D,
        RD2_D
    );

    Extend Extend1 (
        ImmSrc_D,
        InstrImm_D,
        ExtImm_D
    );

    Decoder Decoder1 (
        Opcode_D,
        Funct3_D,
        Funct7_D,
        PCS_D,
        RegWrite_D,
        MemWrite_D,
        MemtoReg_D,
        ALUSrcA_D,
        ALUSrcB_D,
        ImmSrc_D,
        ALUControl_D,
        MCycleOp
    );

    PC_Logic PC_Logic1 (
        PCS_D,
        Funct3_D,
        ALUFlags_E,
        PCSrc_E
    );

    ALU ALU1 (
        Src_A_E,
        Src_B_E,
        ALUControl_D,
        Funct3_D,
        ALUResult_E,
        ALUFlags_E
    );

    ProgramCounter #(
        .PC_INIT(PC_INIT)
    ) ProgramCounter1 (
        CLK,
        RESET,
        WE_PC,
        PC_IN_F,
        PC_F
    );
endmodule
