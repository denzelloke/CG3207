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
    wire [ 1:0] PCSrc_E;
    reg  [31:0] PC_E;
    reg  [31:0] ExtImm_E;
    reg  [31:0] RD1_E;

    always @(*) begin
        case (PCSrc_E)
            2'b00:   PC_IN = PC_F + 32'd4;  // non-control
            2'b01:   PC_IN = PC_E + ExtImm_E;  // jal
            2'b11:   PC_IN = (RD1_fwd + ExtImm_E) & ~32'd1;  // jalr
            default: PC_IN = PC_F + 32'd4;
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
    wire [ 4:0] rs1_D;
    wire [ 4:0] rs2_D;
    wire [ 4:0] rd_D;
    wire [31:0] WD;
    wire [31:0] RD1_D;
    wire [31:0] RD2_D;
    reg  [ 3:0] ALUControl_W;

    assign rs1_D = Instr_D[19:15];
    assign rs2_D = Instr_D[24:20];
    assign rd_D  = Instr_D[11:7];


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
    reg  [31:0] RD2_E;
    reg  [ 4:0] rd_E;
    reg  [ 2:0] Funct3_E;
    wire [31:0] ALUResult_E;
    reg  [ 1:0] MCycleOp_E;
    reg  [ 4:0] rs1_E;
    reg  [ 4:0] rs2_E;
    reg  [ 1:0] ForwardA_E;
    reg  [ 1:0] ForwardB_E;
    wire [31:0] Result_W;


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
            rs1_E        <= 0;
            rs2_E        <= 0;
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
            rs1_E        <= rs1_D;
            rs2_E        <= rs2_D;
        end
    end

    // multicycle signals
    wire Start;
    assign Start = (ALUControl_E == 4'b1111) && !RESET;

    // alu signals
    reg [31:0] Src_A;
    reg [31:0] Src_B;
    reg [31:0] RD1_fwd;
    reg [31:0] RD2_fwd;

    always @(*) begin
        // data fwd rd1
        case (ForwardA_E)
            2'b01:   RD1_fwd = Result_W;  // W->E data fwding
            2'b10:   RD1_fwd = ALUResult_M;  // M->E data fwding
            default: RD1_fwd = RD1_E;  // no fwding
        endcase

        // src A selection
        case (ALUSrcA_E)
            2'b01:   Src_A = 0;
            2'b11:   Src_A = PC_E;
            default: Src_A = RD1_fwd;
        endcase

        // data fwd rd2
        case (ForwardB_E)
            2'b01:   RD2_fwd = Result_W;  // W->E data fwding
            2'b10:   RD2_fwd = ALUResult_M;  // M->E data fwding
            default: RD2_fwd = RD2_E;  // no fwding
        endcase

        // src B selection
        case (ALUSrcB_E)
            2'b01:   Src_B = 32'd4;
            2'b11:   Src_B = ExtImm_E;
            default: Src_B = RD2_fwd;
        endcase
    end

    // pc_logic signals
    wire [ 2:0] ALUFlags;

    // MEMORY STAGE ===============================================================================

    reg         RegWrite_M;
    reg         MemtoReg_M;
    reg         MemWrite_M;
    reg  [31:0] WriteData_M;
    reg  [ 4:0] rd_M;
    reg  [ 4:0] rs2_M;



    always @(posedge CLK) begin
        if (RESET) begin
            RegWrite_M  <= 0;
            MemtoReg_M  <= 0;
            MemWrite_M  <= 0;
            ALUResult_M <= 0;
            WriteData_M <= 0;
            rd_M        <= 0;
            rs2_M       <= 0;
        end
        else if (!Busy) begin
            RegWrite_M  <= RegWrite_E;
            MemtoReg_M  <= MemtoReg_E;
            MemWrite_M  <= MemWrite_E;
            ALUResult_M <= ALUResult_E;
            WriteData_M <= RD2_fwd;
            rd_M        <= rd_E;
            rs2_M       <= rs2_E;
        end

    end

    wire Forward_M;
    assign WriteData_out = (Forward_M) ? Result_W : WriteData_M;  // mem-mem copy
    assign MemWrite_out  = {4{MemWrite_M && !Busy && !RESET}};


    // WRITEBACK STAGE ===============================================================================

    reg        RegWrite_W;
    reg        MemtoReg_W;
    reg [31:0] ReadData_W;
    reg [31:0] ALUResult_W;
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
    assign Result_W = (MemtoReg_W) ? ReadData_W : ALUResult_W;
    assign WD = Result_W;
    assign WE = RegWrite_W && WE_PC && !RESET; // regfile doesnt stall even if we_pc = 0. cos regfile writes on posedge & we=1

    assign MemRead = MemtoReg_M && !Busy && !RESET; // This is needed for the proper functionality of some devices such as UART CONSOLE

    // MISCELLANEOUS SIGNALS ======================================================================

    wire [2:0] SizeSel;  //to support lb/lbu/lh/lhu/sb/sh 
    assign SizeSel = 3'b010;             // Change this to be generated by the Decoder (control) as appropriate if 
                                         // supporting lb/sb/lbu/lh/sh/lhu/lw/sw. Hint: funct3


    // hazard control unit
    // ForwardA_E
    always @(*) begin
        if ((rs1_E == rd_M) && (RegWrite_M) && (rd_M != 0)) ForwardA_E = 2'b10;  // M->E fwding
        else if ((rs1_E == rd_W) && (RegWrite_W) && (rd_W != 0)) ForwardA_E = 2'b01;  // W->E fwding
        else ForwardA_E = 2'b00;  // no fwding
    end
    // ForwardB_E
    always @(*) begin
        if ((rs2_E == rd_M) && (RegWrite_M) && (rd_M != 0)) ForwardB_E = 2'b10;  // M->E fwding
        else if ((rs2_E == rd_W) && (RegWrite_W) && (rd_W != 0)) ForwardB_E = 2'b01;  // W->E fwding
        else ForwardB_E = 2'b00;  // no fwding
    end

    assign Forward_M = (rs2_M == rd_W) && (MemWrite_M) && (MemtoReg_W && RegWrite_W) && (rd_W != 0);
    // checks for clash (same reg), second operation is sw, first operation is lw, lw rd is not x0.

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
        rs1_D,
        rs2_D,
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
