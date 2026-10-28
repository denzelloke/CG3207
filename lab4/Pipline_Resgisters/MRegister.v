`timescale 1ns / 1ps
// Mregister Module for Pipeline


module MRegister (
    input CLK,
    input FlushM,
    input RegWriteE, MemtoRegE, MemWriteE,
    input [31:0] ALUResultE,
    input [31:0] WriteDataE,
    input [4:0] rdE,
    output reg RegWriteM, MemtoRegM, MemWriteM,
    output reg [31:0] ALUResultM, WriteDataM,
    output reg [4:0] rdM
);

always @(posedge CLK) begin 
    if (FlushM) begin 
        RegWriteM <= 1'b0;
        MemtoRegM <= 1'b0;
        MemWriteM <= 1'b0;
        ALUResultM <= 32'b0;
        WriteDataM <= 32'b0;
        rdM <= 5'b0;
    end else begin 
        RegWriteM <= RegWriteE;
        MemtoRegM <= MemtoRegE;
        MemWriteM <= MemWriteE;
        ALUResultM <= ALUResultE;
        WriteDataM <= WriteDataE;
        rdM <= rdE;
    end
end

endmodule