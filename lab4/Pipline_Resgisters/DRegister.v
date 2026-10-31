`timescale 1ns / 1ps
// Dregister Module for Pipeline


module DRegister (
    input CLK,
    input STALL,
    input FLUSH,
    input [31:0] InstrF,
    input [31:0] PCF,
    output reg [31:0] PCD,
    output reg [31:0] InstrD
);

    always @(posedge CLK) begin
        if (FLUSH) begin
            InstrD <= 32'b0;
            PCD    <= 32'b0;
        end
        else if (!STALL) begin
            PCD    <= PCF;
            InstrD <= InstrF;
        end
    end

endmodule
