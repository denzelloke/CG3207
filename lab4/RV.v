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
    input [31:0] Instr_F,
    input [31:0] ReadData_M,  // Name mangled to support lb/lbu/lh/lhu
    output MemRead,
    output [3:0] MemWrite_out,  // Column-wise write enable to support sb/sw. Each column is a byte.
    output [31:0] PC_F,
    output reg [31:0] ALUResult_M,
    output [31:0] WriteData_out  // Name mangled to support sb/sw
);



    // FETCH STAGE ================================================================================

    // programcounter signals
    wire        WE_PC;  // global
    reg  [31:0] PC_IN;
    wire        Busy;
    assign WE_PC = ~Busy;

    always @(*) begin
        case (PCSrc_E)
            2'b00:   PC_IN = PC_F + 32'd4;  // non-control
            2'b01:   PC_IN = PC_E + ExtImm_E;  // jal
            2'b11:   PC_IN = (RD1_E + ExtImm_E) & ~32'd1;  // jalr
            default: PC_IN = PC_F + 32'd4;  // default case
        endcase
    end

    // DECODE STAGE ===============================================================================

    reg [31:0] PC_D;

    // decode stage register
    reg [31:0] Instr_D;
    always @(posedge CLK) begin
        if (RESET) begin
            Instr_D <= 32'h00000013; // nop instr
            PC_D    <= 0;
        end
        else if (!Busy) begin
            Instr_D <= Instr_F;
            PC_D    <= PC_F;
        end
    end

    // decoder signals
    wire [6:0] Opcode;
    wire [2:0] Funct3_D;
    wire [6:0] Funct7;
    wire [1:0] PCS_D;
    wire       RegWrite_D;
    wire       MemWrite_D;
    wire       MemtoReg_D;
    wire [3:0] ALUControl_D;
    wire [1:0] MCycleOp_D;
    wire [1:0] ALUSrcA_D;
    wire [1:0] ALUSrcB_D;
    assign Funct3_D = Instr_D[14:12];
    assign Opcode   = Instr_D[6:0];
    assign Funct7   = Instr_D[31:25];

    // regfile signals
    wire        WE;
    wire [ 4:0] rs1;
    wire [ 4:0] rs2;
    wire [ 4:0] rd_D;
    wire [31:0] WD;
    wire [31:0] RD1_D;
    wire [31:0] RD2_D;
    reg         RegWrite_W;
    reg  [ 3:0] ALUControl_W;

    assign rs1  = Instr_D[19:15];
    assign rs2  = Instr_D[24:20];
    assign rd_D = Instr_D[11:7];


    // extend module signals
    wire [ 2:0] ImmSrc;
    wire [31:0] ExtImm_D;
    wire [24:0] InstrImm;
    assign InstrImm = Instr_D[31:7];


    // EXECUTE STAGE ==============================================================================

    reg  [ 1:0] PCS_E;
    reg         RegWrite_E;
    reg         MemtoReg_E;
    reg         MemWrite_E;
    reg  [ 3:0] ALUControl_E;
    reg  [ 1:0] ALUSrcA_E;
    reg  [ 1:0] ALUSrcB_E;
    reg  [31:0] RD1_E;
    reg  [31:0] RD2_E;
    reg  [31:0] ExtImm_E;
    reg  [ 4:0] rd_E;
    reg  [ 2:0] Funct3_E;
    reg  [31:0] PC_E;
    wire [31:0] ALUResult_E;
    reg  [ 1:0] MCycleOp_E;


    always @(posedge CLK) begin
        if (RESET) begin
            RegWrite_E   <= 0;
            MemtoReg_E   <= 0;
            MemWrite_E   <= 0;
            ALUControl_E <= 0;
            ALUSrcA_E    <= 0;
            ALUSrcB_E    <= 0;
            RD1_E        <= 0;
            RD2_E        <= 0;
            ExtImm_E     <= 0;
            rd_E         <= 0;
            Funct3_E     <= 0;
            PC_E         <= 0;
            PCS_E        <= 0;
            MCycleOp_E   <= 0;
        end
        else if (!Busy) begin
            RegWrite_E   <= RegWrite_D;
            MemtoReg_E   <= MemtoReg_D;
            MemWrite_E   <= MemWrite_D;
            ALUControl_E <= ALUControl_D;
            ALUSrcA_E    <= ALUSrcA_D;
            ALUSrcB_E    <= ALUSrcB_D;
            RD1_E        <= RD1_D;
            RD2_E        <= RD2_D;
            ExtImm_E     <= ExtImm_D;
            rd_E         <= rd_D;
            Funct3_E     <= Funct3_D;
            PC_E         <= PC_D;
            PCS_E        <= PCS_D;
            MCycleOp_E   <= MCycleOp_D;
        end
    end

    // multicycle signals
    wire Start;
    assign Start = (ALUControl_E == 4'b1111) && !RESET;

    // alu signals
    reg [31:0] Src_A;
    reg [31:0] Src_B;
    always @(*) begin
        Src_A = RD1_E;
        Src_B = RD2_E;
        case (ALUSrcA_E)
            2'b00, 2'b10: Src_A = RD1_E;  // DP Reg (incl mcycle), DP Imm, load, store, branch
            2'b11: Src_A = PC_E;  // jal, auipc, jalr
            2'b01: Src_A = 32'b0;  //lui
        endcase
        case (ALUSrcB_E)
            2'b00, 2'b10: Src_B = RD2_E;  // DP Reg (incl mcycle), branch
            2'b11:        Src_B = ExtImm_E;  // DP Imm, load, store, auipc, lui
            2'b01:        Src_B = 32'd4;  // jal, jalr
        endcase
    end

    // pc_logic signals
    wire [ 2:0] ALUFlags;
    wire [ 1:0] PCSrc_E;


    // MEMORY STAGE ===============================================================================

    reg         RegWrite_M;
    reg         MemtoReg_M;
    reg         MemWrite_M;
    reg  [31:0] WriteData_M;
    reg  [ 4:0] rd_M;

    always @(posedge CLK) begin
        if (RESET) begin
            RegWrite_M  <= 0;
            MemtoReg_M  <= 0;
            MemWrite_M  <= 0;
            ALUResult_M <= 0;
            WriteData_M <= 0;
            rd_M        <= 0;
        end
        else if (!Busy) begin
            RegWrite_M  <= RegWrite_E;
            MemtoReg_M  <= MemtoReg_E;
            MemWrite_M  <= MemWrite_E;
            ALUResult_M <= ALUResult_E;
            WriteData_M <= RD2_E;
            rd_M        <= rd_E;
        end

    end

    assign WriteData_out = WriteData_M;  // Change datapath as appropriate if supporting sb/sh
    assign MemWrite_out  = {4{MemWrite_M && !Busy && !RESET}};


    // WRITEBACK STAGE ===============================================================================

    reg        MemtoReg_W;
    reg [31:0] ALUResult_W;
    reg [31:0] ReadData_W;
    reg [ 4:0] rd_W;

    always @(posedge CLK) begin
        if (RESET) begin
            RegWrite_W  <= 0;
            MemtoReg_W  <= 0;
            ReadData_W  <= 0;
            ALUResult_W <= 0;
            rd_W        <= 0;
        end
        else if (!Busy) begin
            RegWrite_W  <= RegWrite_M;
            MemtoReg_W  <= MemtoReg_M;
            ReadData_W  <= ReadData_M;
            ALUResult_W <= ALUResult_M;
            rd_W        <= rd_M;
        end

    end

    // regfile signals (write)
    assign WD = (MemtoReg_W) ? ReadData_W : ALUResult_W;
    assign WE = RegWrite_W && WE_PC && !RESET; // regfile doesnt stall even if we_pc = 0. cos regfile writes on posedge & we=1

    assign MemRead = MemtoReg_M && !Busy && !RESET; // This is needed for the proper functionality of some devices such as UART CONSOLE

    // MISCELLANEOUS SIGNALS ======================================================================

    wire [2:0] SizeSel;  //to support lb/lbu/lh/lhu/sb/sh 
    assign SizeSel = 3'b010;             // Change this to be generated by the Decoder (control) as appropriate if 
                                         // supporting lb/sb/lbu/lh/sh/lhu/lw/sw. Hint: funct3





    // FETCH ================

    ProgramCounter #(
        .PC_INIT(PC_INIT)
    ) ProgramCounter1 (
        CLK,
        RESET,
        WE_PC,
        PC_IN,
        PC_F
    );

    // DECODE ===============

    Decoder Decoder1 (
        Opcode,
        Funct3_D,
        Funct7,
        PCS_D,
        RegWrite_D,
        MemWrite_D,
        MemtoReg_D,
        ALUSrcA_D,
        ALUSrcB_D,
        ImmSrc,
        ALUControl_D,
        MCycleOp_D
    );

    RegFile RegFile1 (
        CLK,
        WE,
        rs1,
        rs2,
        rd_W,
        WD,
        RD1_D,
        RD2_D
    );

    Extend Extend1 (
        ImmSrc,
        InstrImm,
        ExtImm_D
    );

    // EXECUTE ==============

    ALU ALU1 (
        CLK,
        RESET,
        Start,
        MCycleOp_E,
        Busy,
        Src_A,
        Src_B,
        ALUControl_E,
        Funct3_E,
        ALUResult_E,
        ALUFlags
    );

    PC_Logic PC_Logic1 (
        PCS_E,
        Funct3_E,
        ALUFlags,
        PCSrc_E
    );


endmodule
