`timescale 1ns / 1ps
// CPU -> pixel bundled-data handshake. Shadow words stay immutable from commit
// until the pixel domain captures ALL words at vertical blank and ACK returns.
// Only request/ack toggles pass through synchronizers; the payload is held stable.
// Both resets must assert together (as NeonTop guarantees); release may differ.
// MMCM clocks remain related and payload paths remain timed in NeonTop.xdc.
module DisplayRegisters (
    input clk,
    reset,
    pixel_clk,
    pixel_reset,
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
    reg request_toggle, ack_toggle;
    (* ASYNC_REG="TRUE" *) reg request_meta, request_sync;
    (* ASYNC_REG="TRUE" *) reg ack_meta, ack_sync;
    integer i,j;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 0;
            frame_sequence <= 0;
            request_toggle <= 0;
            ack_meta <= 0;
            ack_sync <= 0;
            for (i = 0; i < 64; i = i + 1) begin
                shadow_object[i] <= 0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                shadow_hud[i] <= 0;
            end
        end
        else begin
            ack_meta <= ack_toggle;
            ack_sync <= ack_meta;
            if (!busy) begin
                if (write_object) shadow_object[word_index] <= write_data;
                if (write_hud) shadow_hud[word_index[3:0]] <= write_data;
                if (commit) begin
                    busy <= 1;
                    request_toggle <= ~request_toggle;
                end
            end
            if (busy && ack_sync == request_toggle) begin
                busy <= 0;
                frame_sequence <= frame_sequence + 1'b1;
            end
        end
    end
    always @(posedge pixel_clk or posedge pixel_reset) begin
        if (pixel_reset) begin
            request_meta <= 0;
            request_sync <= 0;
            ack_toggle <= 0;
            for (j = 0; j < 64; j = j + 1) active_object[j] <= 0;
            for (j = 0; j < 16; j = j + 1) active_hud[j] <= 0;
        end else begin
            request_meta <= request_toggle;
            request_sync <= request_meta;
            if (frame_boundary && request_sync != ack_toggle) begin
                for (j = 0; j < 64; j = j + 1) active_object[j] <= shadow_object[j];
                for (j = 0; j < 16; j = j + 1) active_hud[j] <= shadow_hud[j];
                ack_toggle <= request_sync;
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
