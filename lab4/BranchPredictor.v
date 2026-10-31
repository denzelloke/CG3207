`timescale 1ns / 1ps
//Branch Prediction
// BTB, BHT and RAW


module BranchPredictor (
input CLK, RESET,
input [31:0] PCF, // PC address being fetched
input UpdateEnableE, //need to update table, after E comes back
input [31:0] PCE, // Which instruc is this for update
input ActualTakenE, //taken or not, deduce from E 
input [31:0] ActualTargetE, //where it would jump if taken
input isJumpE, // jal instructions only
output [31:0] PredictedNextPCF,
output predictedTakenF,
);

//BTB info 
//32 entry table
reg valid_table [0:31]; //check if entry is valid
reg [24:0] tag_table [0:31]; //store PC address
reg [31:0] target_table [0:31]; //store address to jump to
reg jump_table [0:31]; //if its a jump address, always taken

//BHT Taken or not taken
reg [1:0] counter_table [0:31];

// tmp terms
wire [4:0] indexF, indexE;
wire [24:0] tagF, tagE;
wire matched;

integer i;

//INSTRUC FETCH STAGE, CHECK TABLE TO SEE IF MATCH
//word aligned
assign indexF = PCF[6:2]; //this is the lower 5 bits of PC address
assign indexE = PCE[6:2];
assign tagF = PCF[31:7]; 
assign tagE = PCE[31:7];

//there is a match if the table has the index and the tag matches
assign matched = valid_table[indexF] && (tag_table[indexF] == tagF); 

//branch is taken if there is a matching entry and it is a jal or the weakly/strongly taken signal
assign predictedTakenF = !RESET && matched && (jump_table[indexF || counter_table[indexF][1]]);

//EXECUTE RETURN UPDATE STAGE
always @(CLK) begin
    if (RESET) begin
        for (i = 0; i <32; i++) begin
            valid_table[i] <= 1'b0;
            valid_table[i]   <= 1'b0;
            tag_table[i]     <= 25'd0;
            target_table[i]  <= 32'd0;
            jump_table[i]    <= 1'b0;
            counter_table[i] <= 2'b01; //weakly not taken
        end
    end else if (UpdateEnableE) begin //E returns with info
        valid_table[indexE] <= 1'b0;
        tag_table[indexE] <= tagE;
        target_table[indexE] <= ActualTargetE;
        jump_table[indexE] <= isJumpE;

        //initlaise a new entry with weakly taken or not taken
        if (!valid_table[indexE] || (tag_table[indexE] != tagE)) begin
            counter_table[indexE] <= ActualTakenE ? 2'b10 : 2'b01; 
        end

        //if not jump then update back on actual taken
        else if (!isJumpE) begin
            counter_table[indexE] <= ActualTakenE ? (counter_table[indexE] == 2'b11 ? 2'b11 : counter_table[indexE] + 1) 
                                                    : (counter_table[indexE] == 2'b00 ? 2'b00 : counter_table[indexE] - 1); 
        end
    end
end


endmodule