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
//TODO: add what flush and stall does to the processor
//TODO: check MCycle

module RV #(
    parameter PC_INIT = 32'h00400000
) (
    input CLK,
    input RESET,
    //input Interrupt,      // for optional future use.
    input [31:0] Instr_F,
    input [31:0] ReadData_in_M,  // Name mangled to support lb/lbu/lh/lhu
    output MemRead_D,           // assigned to MemtoReg_D 
    output [3:0] MemWrite_out_M,  // Column-wise write enable to support sb/sw. Each column is a byte.
    output [31:0] PC_F,
    output [31:0] ALUResult_E,
    output [31:0] WriteData_out_M  // Name mangled to support sb/sw
);

    // Please read Lab 4 Enhancement: Implementing additional instructions on how to support lb/lbu/lh/lhu/sb/sh

    //Hazard Unit Signals
        //for Load and Use Hazard (Stalling)
    wire Stall_F;
    wire Stall_D;
    wire CLK_Enable_F;  //used to assert a stall in F reg
    wire CLK_Enable_D;  //used to assert a stall in D reg
    wire lwStall;
    wire UsesRs1_D;
    wire UsesRs2_D;
    wire Flush_D;

        //
    wire Forward2_D;
    wire Forward1_D;
    wire Flush_E;

        //for Data Forwarding to ALU in E stage
    reg [1:0] ForwardB_E;    //ALU Source B forwarding mux
    reg [1:0] ForwardA_E;    //ALU Source A forwarding mux
    reg [4:0] rs1_E;   //needed for forwarding
    reg [4:0] rs2_E;   //needed for forwarding
    //reg RegWrite_M;   //already exists
    //reg MemtoReg_E;   //already exists
    //reg PCSrc_E;      //already exists

        //for Data Forwarding (Mem to Mem copy)
    wire Forward_M;     //The mux that forwards what to write to Data Memory
    reg [4:0] rs2_M;   //needed for forwarding
    
    //reg MemWrite_M;   //already exists
    //reg RegWrite_W;   //already exists; used in both data forwardings
    //reg MemtoReg_W;   //already exists     

    //RV Signals
    wire [ 2:0] SizeSel;  //to support lb/lbu/lh/lhu/sb/sh
    reg [31:0] WriteData_M;
    wire        MemWrite_D;

    //Decode Stage Signals
    reg [31:0] Instr_D;
    reg [31:0] PC_D;
    wire [4:0] rd_D;        //delayed until writeback stage
    assign rd_D = Instr_D[11:7];
    wire [31:0] RD1_D_Out;   //used in forwarding, just before E reg
    wire [31:0] RD2_D_Out;   //used in forwarding, just before E reg

    //Execute Stage Signals
    reg [4:0] rd_E;
    reg [31:0] PC_E;
    reg [31:0] ExtImm_E;
    reg [31:0] RD1_E;
    reg [31:0] RD2_E;
    reg [1:0] PCS_E;
    reg RegWrite_E;
    reg MemtoReg_E;
    reg MemWrite_E;
    reg [3:0] ALUControl_E;
    reg [1:0] ALUSrcA_E;
    reg [1:0] ALUSrcB_E;
    reg [31:0] WriteData_E;
    reg [2:0] Funct3_E;
    reg [31:0] RD1Fwd_E;
    wire [31:0] ALUResultRaw_E;
    assign ALUResult_E = ALUResult_M;    //double check what this does

    //Memory Stage Signals
    reg [31:0] ALUResult_M;
    //reg [31:0] WriteData_M;       //in RV Signals
    reg [4:0] rd_M;
    reg RegWrite_M;
    reg MemtoReg_M;
    reg MemWrite_M;
    wire [31:0] ReadData_M;

    //Writeback Stage Signals
    reg [31:0] ReadData_W;
    reg [31:0] ALUResult_W;
    reg [4:0] rd_W;
    reg RegWrite_W;
    reg MemtoReg_W;


    // RegFile signals
    wire        WE_regfile_D;
    wire [ 4:0] rs1_D;
    wire [ 4:0] rs2_D;
    wire [ 4:0] rd_regfile_W;
    wire [31:0] WD_regfile_W;
    wire [31:0] RD1_D;
    wire [31:0] RD2_D;
    wire [31:0] Result_W;
    wire       RegWrite_D;
    wire [3:0] ALUControl_D;
    assign WE_regfile_D = RegWrite_W && !RESET; // regfile doesnt stall even if we_pc = 0. cos regfile writes on posedge & we=1
    assign rs1_D = Instr_D[19:15];
    assign rs2_D = Instr_D[24:20];
    assign rd_regfile_W  = rd_W;
    reg [31:0] MCycle_res;          //TODO: change suffix?
    //assign ALUResult_E = (ALUControl_E == 4'b1111) ? MCycle_res : ALUResult_E;     //moved to M reg
    wire MemtoReg_D;
    assign Result_W = (MemtoReg_W) ? ReadData_W : ALUResult_W;
    assign WD_regfile_W = Result_W;

    // Extend Module signals
    wire [2:0] ImmSrc_D;
    wire [24:0] InstrImm_D;
    wire [31:0] ExtImm_D;
    assign InstrImm_D = Instr_D[31:7];

    // Decoder signals
    wire [6:0] Opcode_D;
    wire [2:0] Funct3_D;
    wire [6:0] Funct7_D;
    wire [1:0] PCS_D;
    wire [1:0] ALUSrcA_D;
    wire [1:0] ALUSrcB_D;         
    assign Funct3_D = Instr_D[14:12];
    assign Opcode_D = Instr_D[6:0];
    assign Funct7_D = Instr_D[31:25];

    // PC_Logic signals
    wire [2:0] ALUFlags_E;
    wire [2:0] PCSrc_E;

    // ALU signals
    reg  [31:0] Src_A_E;
    reg  [31:0] Src_B_E;

    // ProgramCounter signals
    wire        WE_PC;          //TODO: to change suffix? this is assigned by MCycle
    reg  [31:0] PC_IN_F;
    wire        Busy;
    assign WE_PC = ~Busy & ~Stall_F;
    always @(*) begin
        PC_IN_F = PC_F + 32'd4; //default case
        if (~Stall_F) begin
            case (PCSrc_E)
                3'b000: PC_IN_F = PC_F + 32'd4;                     //non-control
                3'b011, 3'b001: PC_IN_F = PC_E + ExtImm_E;                  //jal, branch
                3'b111: PC_IN_F = (RD1Fwd_E + ExtImm_E) & ~32'd1;    //jalr     
                default: PC_IN_F = PC_F + 32'd4;                    //default case
            endcase
        end
    end

    // ALU signals
    always @(*) begin
        //defaults
        Src_A_E = RD1_E;
        Src_B_E = RD2_E;
        RD1Fwd_E = RD1_E;
        WriteData_E = RD2_E;
        case(ForwardA_E)
            2'b00: RD1Fwd_E = RD1_E;
            2'b01: RD1Fwd_E = Result_W;
            2'b10: RD1Fwd_E = ALUResult_M; 
        endcase
        case (ALUSrcA_E)
            2'b00, 2'b10: Src_A_E = RD1Fwd_E;   //DP Reg, DP Imm, load, store, branch
            2'b11:        Src_A_E = PC_E;       //jal, auipc, jalr
            2'b01:        Src_A_E = 32'b0;      //lui
        endcase
        case (ForwardB_E)
            2'b00: WriteData_E = RD2_E;
            2'b01: WriteData_E = Result_W;
            2'b10: WriteData_E = ALUResult_M;
        endcase 
        case (ALUSrcB_E)
            2'b00, 2'b10: Src_B_E = WriteData_E;     // DP Reg, branch
            2'b11:        Src_B_E = ExtImm_E;       // DP Imm, load, store, auipc, lui
            2'b01:        Src_B_E = 32'd4;          // jal, jalr
        endcase
    end

    // Other internal signals here
    assign MemRead_D = MemtoReg_M && !RESET; // This is needed for the proper functionality of some devices such as UART CONSOLE
    assign ReadData_M = ReadData_in_M;  // Change datapath as appropriate if supporting lb/lbu/lh/lhu
        //affected by FowardM
    assign WriteData_out_M = (Forward_M) ? Result_W : WriteData_M;  // Change datapath as appropriate if supporting sb/sh
    assign MemWrite_out_M = {4{MemWrite_M && !RESET}};  // Change datapath as appropriate if supporting sb/sh
    assign SizeSel = 3'b010;             // Change this to be generated by the Decoder (control) as appropriate if 
                                         // supporting lb/sb/lbu/lh/sh/lhu/lw/sw. Hint: funct3
    // multicycle signals
    //TODO: see if need to change anything?
    wire Start;
    wire [1:0] MCycleOp_D;
    reg [1:0] MCycleOp_E;
    wire [31:0] Operand1;
    wire [31:0] Operand2;
    wire [31:0] Result1;
    wire [31:0] Result2;
    assign Start = (ALUControl_E == 4'b1111);
    assign Operand1 = RD1Fwd_E;
    assign Operand2 = WriteData_E;
    always @(*) begin
        if (Funct3_E == 3'h0 || Funct3_E == 3'h4 || Funct3_E == 3'h5)
            MCycle_res = Result1;  // lsw or quotient
        else MCycle_res = Result2;  // hsw / remainder
    end

    //change from combinational logic to clocked logic
    //F to D Stage
    always @ (posedge CLK) begin
        if (RESET) begin
            Instr_D <= 32'h00000013;    //insert NOP
            PC_D <= PC_INIT;
        end
        else if (Flush_D) begin
            Instr_D <= 32'h00000013;    //insert 1 NOP
        end
        else if (~Stall_D) begin
            Instr_D <= Instr_F;
            PC_D <= PC_F;
        end
        //else hold
    end

    //D to E Stage
    always @ (posedge CLK) begin
        if (RESET) begin
            PCS_E <= 1'b0;
            MemWrite_E <= 1'b0;
            RegWrite_E <= 1'b0;
            MemtoReg_E <= 1'b0;
            rd_E <= rd_E;
            PC_E <= PC_E;
            ExtImm_E <= ExtImm_E;
            RD1_E <= RD1_E;
            RD2_E <= RD2_E;
            ALUControl_E <= 4'b0000;
            ALUSrcA_E <= ALUSrcA_E;
            ALUSrcB_E <= ALUSrcB_E;
            Funct3_E <= Funct3_E;
            rs1_E <= rs1_E;
            rs2_E <= rs2_E;
            MCycleOp_E <= 2'b00;
        end
        else if (Busy) begin
            //hold while Mcycle active
        end
        else if (~Flush_E) begin        //normal clocking
            rd_E <= rd_D;
            PC_E <= PC_D;
            ExtImm_E <= ExtImm_D;
            RD1_E <= RD1_D_Out;
            RD2_E <= RD2_D_Out;
            PCS_E <= PCS_D;
            RegWrite_E <= RegWrite_D;
            MemtoReg_E <= MemtoReg_D;
            MemWrite_E <= MemWrite_D;
            ALUControl_E <= ALUControl_D;
            ALUSrcA_E <= ALUSrcA_D;
            ALUSrcB_E <= ALUSrcB_D;
            Funct3_E <= Funct3_D;
            rs1_E <= rs1_D;
            rs2_E <= rs2_D;
            MCycleOp_E <= MCycleOp_D;
        end
        else begin          //flush
            PCS_E <= 1'b0;
            MemWrite_E <= 1'b0;
            RegWrite_E <= 1'b0;
            MemtoReg_E <= 1'b0;

            ALUControl_E <= 1'b0;
            ALUSrcA_E <= 1'b0;
            ALUSrcB_E <= 1'b0;
            Funct3_E <= 1'b0;
            rs1_E <= 1'b0;
            rs2_E <= 1'b0;
            rd_E <= 1'b0;
            PC_E <= 1'b0;
            ExtImm_E <= 1'b0;
            RD1_E <= 1'b0;
            RD2_E <= 1'b0;
            PCS_E <= 1'b0;
            MCycleOp_E <= 2'b00;
        end
    end

    //E to M Stage
    always @ (posedge CLK) begin
        if (RESET || Busy) begin
            RegWrite_M  <= 1'b0;
            MemtoReg_M  <= 1'b0;
            MemWrite_M  <= 1'b0;
            ALUResult_M <= 32'b0;
            WriteData_M <= 32'b0;
            rd_M        <= 5'b0;
            rs2_M       <= 5'b0;
        end
        else begin
            ALUResult_M <= (ALUControl_E == 4'b1111) ? MCycle_res : ALUResultRaw_E;
            WriteData_M <= WriteData_E;
            rd_M <= rd_E;
            RegWrite_M <= RegWrite_E;
            MemtoReg_M <= MemtoReg_E;
            MemWrite_M <= MemWrite_E;
            rs2_M <= rs2_E;
        end
    end

    //M to W Stage
    always @ (posedge CLK) begin
        if (RESET) begin
            RegWrite_W <= 1'b0;
            MemtoReg_W <= 1'b0;
            ReadData_W <= ReadData_W;
            rd_W <= rd_W;
            ALUResult_W <= ALUResult_W;
        end
        else begin
            ReadData_W <= ReadData_M;
            rd_W <= rd_M;
            RegWrite_W <= RegWrite_M;
            MemtoReg_W <= MemtoReg_M;
            ALUResult_W <= ALUResult_M;
        end
    end

    //Hazard unit assignments
        //for Data Forwarding 
    always @ (*) begin
        //for ForwardA_E, ALU Source 1
        if ((rs1_E == rd_M) & RegWrite_M & (rd_M != 0)) begin       //M to E forwarding
            ForwardA_E = 2'b10;
        end
        else if ((rs1_E == rd_W) & RegWrite_W & (rd_W != 0)) begin  //W to E forwarding
            ForwardA_E = 2'b01;
        end
        else begin
            ForwardA_E = 2'b00;
        end
        //for ForwardB_E, ALU Source 2
        if ((rs2_E == rd_M) & RegWrite_M & (rd_M != 0)) begin       //M to E forwarding
            ForwardB_E = 2'b10;
        end
        else if ((rs2_E == rd_W) & RegWrite_W & (rd_W != 0)) begin  //W to E forwarding
            ForwardB_E = 2'b01;
        end
        else begin
            ForwardB_E = 2'b00;
        end
    end

        //for Data Forwarding (Mem to Mem copy)
    assign Forward_M = (rs2_M == rd_W) & MemWrite_M & MemtoReg_W & (rd_W != 0) & RegWrite_W;

        //for Load and Use Hazard: Stalling
    assign UsesRs1_D = ~(Opcode_D == 7'b0110111 | Opcode_D == 7'b0010111 | Opcode_D == 7'b1101111);  //Not LUI, AUIPC, JAL
    assign UsesRs2_D = (Opcode_D == 7'b0110011 | Opcode_D == 7'b1100011);  //Is R-Type or Branch
    assign lwStall = MemtoReg_E & (rd_E != 0) & ((rs1_D == rd_E) & UsesRs1_D | (rs2_D == rd_E) & UsesRs2_D);
    assign Stall_F = lwStall | Busy;
    assign Stall_D = lwStall | Busy;
    //assign Flush_E = lwStall;     //assigned below with flushing due to branch
    assign CLK_Enable_D = ~Stall_D;
    assign CLK_Enable_F = ~Stall_F;

        //for Flushing due to branch
    assign Flush_D = PCSrc_E[0];
    assign Flush_E = PCSrc_E[0] | lwStall;

        //for forwarding pipeline regs and reg file at same clock edge
    assign Forward1_D = (rs1_D == rd_W) & RegWrite_W & (rd_W != 0);
    assign Forward2_D = (rs2_D == rd_W) & RegWrite_W & (rd_W != 0);
    assign RD1_D_Out = (Forward1_D) ? Result_W : RD1_D;
    assign RD2_D_Out = (Forward2_D) ? Result_W : RD2_D;

    MCycle MCycle1 (
        CLK,
        RESET,
        Start,
        MCycleOp_E,
        Operand1,
        Operand2,
        Result1,
        Result2,
        Busy
    );

    RegFile RegFile1 (
        CLK,
        WE_regfile_D,
        rs1_D,
        rs2_D,
        rd_regfile_W,   //input
        WD_regfile_W,   //input
        RD1_D,  //output
        RD2_D   //output
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
        MCycleOp_D
    );

    PC_Logic PC_Logic1 (
        PCS_E,
        Funct3_E,
        ALUFlags_E,
        PCSrc_E
    );

    ALU ALU1 (
        Src_A_E,
        Src_B_E,
        ALUControl_E,
        Funct3_E,
        ALUResultRaw_E,
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
