`timescale 1ns / 1ps
// Eregister Module for Pipeline


module ERegister (
    input CLK,
    input FLUSH,
    input STALL,
    input [2:0] func3D,
    input [1:0] PCSD,
    input RegWriteD, MemtoRegD, MemWriteD,
    input [3:0] ALUControlD,
    input [1:0] ALUSrcAD, ALUSrcBD,
    input [31:0] RD1D, RD2D,
    input [31:0] ExtImmD,
    input [4:0] rdD,
    input [31:0] PCD,
    output reg [2:0] func3E,
    output reg [1:0] PCSE,
    output reg RegWriteE, MemtoRegE, MemWriteE,
    output reg [3:0] ALUControlE,
    output reg [1:0] ALUSrcAE, ALUSrcBE,
    output reg [31:0] RD1E, RD2E,
    output reg [31:0] ExtImmE,
    output reg [4:0] rdE,
    output reg [31:0] PCE
);

always @(posedge CLK) begin 
    if (FLUSH) begin 
        func3E <= 3'b0;
        PCSE <= 2'b0
        RegWriteE <= 0;
        MemtoRegE <= 0;
        MemWriteE <= 0;
        ALUControlE <= 4'b0;
        ALUSrcAE <= 2'b0;
        ALUSrcBE <= 2'b0;
        RD1E <= 4'b0;
        RD2E <= 4'b0;
        ExtImmE <= 32'b0;
        rdE <= 4'b0;
        PCE <= 32'b0;
    end else if (!STALL) begin
        func3E     <= func3D;
        PCSE       <= PCSD;
        RegWriteE  <= RegWriteD;
        MemtoRegE  <= MemtoRegD;
        MemWriteE  <= MemWriteD;
        ALUControlE <= ALUControlD;
        ALUSrcAE   <= ALUSrcAD;
        ALUSrcBE   <= ALUSrcBD;
        RD1E       <= RD1D;
        RD2E       <= RD2D;
        ExtImmE    <= ExtImmD;
        rdE        <= rdD;
        PCE        <= PCD;
    end
end

endmodule