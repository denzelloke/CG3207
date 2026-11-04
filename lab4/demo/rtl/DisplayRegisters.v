`timescale 1ns / 1ps
// Single clock domain: immutable transfer payload while commit is pending.
// A commit takes effect at the start of vertical blank. Writes while busy are
// ignored. Software must wait for busy=0 before modifying shadow state.
module DisplayRegisters (
    input clk,
    reset,
    frame_boundary,
    input write_hud,
    write_object,
    commit,
    input [5:0] word_index,
    input [31:0] write_data,
    output reg busy,
    output reg [31:0] frame_sequence,
    output [2047:0] objects,
    output [511:0] hud
);
    reg [31:0] shadow_object[0:63], active_object[0:63];
    reg [31:0] shadow_hud[0:15], active_hud[0:15];
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            busy <= 0;
            frame_sequence <= 0;
            for (i = 0; i < 64; i = i + 1) begin
                shadow_object[i] <= 0;
                active_object[i] <= 0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                shadow_hud[i] <= 0;
                active_hud[i] <= 0;
            end
        end
        else begin
            if (!busy) begin
                if (write_object) shadow_object[word_index] <= write_data;
                if (write_hud) shadow_hud[word_index[3:0]] <= write_data;
                if (commit) busy <= 1;
            end
            if (busy && frame_boundary) begin
                for (i = 0; i < 64; i = i + 1) active_object[i] <= shadow_object[i];
                for (i = 0; i < 16; i = i + 1) active_hud[i] <= shadow_hud[i];
                busy <= 0;
                frame_sequence <= frame_sequence + 1'b1;
            end
        end
    end
    genvar n;
    generate
        for (n = 0; n < 64; n = n + 1) begin : obj_out
            assign objects[n*32+:32] = active_object[n];
        end
        for (n = 0; n < 16; n = n + 1) begin : hud_out
            assign hud[n*32+:32] = active_hud[n];
        end
    endgenerate
endmodule
