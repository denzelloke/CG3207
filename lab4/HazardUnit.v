`timescale 1ns / 1ps
// Hazard Unit to control Stall, Flush and Forwarding


module HazardUnit (
input [4:0] rs1D, rs2D,
input [4:0] rs1E, rs2E, rdE,
input [4:0] rs2M, rdM,
input [4:0] rdW,
input MemtoRegE,
input [1:0] PCSrcE,
input RegWriteM, MemWriteM,
input RegWriteW, MemtoRegW,
input UsesRs1D, UsesRs2D,
input MCYCLESTALL,
output StallF, StallD, StallE,
output FlushD, FlushE, FlushM,
output Forward1D, Forward2D,
output reg [1:0] ForwardBE, ForwardAE,
output ForwardM
);

wire LwStall;
wire RedirectE;

always @(*) begin 
    ForwardAE = 2'b00;
    ForwardBE = 2'b00;
    //Data Forwarding 
    //source 1
    //if M to E stage
    if ((rs1E == rdM) & RegWriteM & (rdM != 0)) ForwardAE= 2'b10;
    //else W to E stage
    else if ((rs1E == rdW) & RegWriteW & (rdW != 0)) ForwardAE = 2'b01;
    //else normal operation
    else ForwardAE = 2'b00;

    //source 2
    //if M to E stage
    if ((rs2E == rdM) & RegWriteM && (rdM != 0)) ForwardBE= 2'b10;
    //else W to E stage
    else if ((rs2E == rdW) & RegWriteW && (rdW != 0)) ForwardBE = 2'b01;
    //else normal operation
    else ForwardBE = 2'b00;

end

//Memory to Memory Forwarding
//if sw register destination (rs2) same as previous writeback rdM
assign ForwardM = ((rs2M == rdW) & MemWriteM & MemtoRegW & (rdW != 0) & RegWriteW);

//Stalling Circuit
//register needed in decode stage same as destination reg of lw before
assign LwStall = ((((rs1D == rdE) & UsesRs1D) | ((rs2D == rdE) & UsesRs2D)) & MemtoRegE & (rdE != 0));

assign Forward1D = ((rs1D == rdW) & RegWriteW & (rdW != 0));
assign Forward2D = ((rs2D == rdW) & RegWriteW & (rdW != 0));

assign RedirectE = (PCSrcE != 2'b00) && !MCYCLESTALL;

assign StallF = LwStall || MCYCLESTALL;
assign StallD = LwStall || MCYCLESTALL;
assign StallE = MCYCLESTALL;
assign FlushE = !MCYCLESTALL && (LwStall || RedirectE);
// A load-use stall must preserve the instruction in D.
assign FlushD = RedirectE;
assign FlushM = MCYCLESTALL;



endmodule