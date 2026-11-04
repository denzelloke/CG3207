`timescale 1ns/1ps
module GameInputs #(parameter DEBOUNCE_CYCLES=250000) (
    input clk, reset,
    input [3:0] buttons,
    input [15:0] switches,
    output [3:0] held, pressed,
    output [15:0] switch_sync
);
    (* ASYNC_REG="TRUE" *) reg [3:0] button_meta=0, button_sync=0;
    (* ASYNC_REG="TRUE" *) reg [15:0] switch_meta=0, switch_stage=0;
    // Synchronizers run through reset so the stable mode is ready at boot.
    always @(posedge clk) begin
        button_meta<=buttons; button_sync<=button_meta;
        switch_meta<=switches; switch_stage<=switch_meta;
    end
    assign switch_sync=switch_stage;
    genvar n;
    generate for(n=0;n<4;n=n+1) begin: debounce
        ButtonDebouncer #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) db (
            .CLK(clk),.RESET(reset),.ButtonSync(button_sync[n]),
            .ButtonDown(held[n]),.ButtonEvent(pressed[n]));
    end endgenerate
endmodule
