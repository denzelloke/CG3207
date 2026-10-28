`timescale 1ns / 1ps
// Wregister Module for Pipeline


module WRegister (
    input CLK,
    input RegWriteM, MemtoRegM,
    input [31:0] ReadDataM,
    input [31:0] ALUResultM,
    input [4:0] rdM,
    output reg RegWriteW, MemtoRegW,
    output reg [31:0] ReadDataW,
    output reg [31:0] ALUResultW,
    output reg [4:0] rdW
);

always @(posedge CLK) begin 
    RegWriteW <= RegWriteM;
    MemtoRegW <= MemtoRegM;
    ALUResultW <= ALUResultM;
    ReadDataW <= ReadDataM;
    rdW <= rdM;
end

endmodule