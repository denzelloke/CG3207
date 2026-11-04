`timescale 1ns / 1ps

// Debounce an ALREADY SYNCHRONISED, active-high button.
// Connect ButtonSync to Wrapper's PB_sync[1], not directly to a board pin.
// Both presses and releases must remain stable for DEBOUNCE_CYCLES samples.
module ButtonDebouncer #(
    parameter integer DEBOUNCE_CYCLES = 62500 // 10 ms at 6.25 MHz; must be >= 1
) (
    input CLK,
    input RESET,
    input ButtonSync,          // Button after the existing two-flop synchroniser
    output reg ButtonDown,    // Accepted button state: 1 while pressed
    output reg ButtonEvent    // One-clock pulse for each accepted press
);

    localparam integer COUNTER_WIDTH =
        (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);
    localparam [COUNTER_WIDTH-1:0] LAST_COUNT = DEBOUNCE_CYCLES - 1;
    reg [COUNTER_WIDTH-1:0] StableCounter;

    always @(posedge CLK) begin
        if (RESET) begin
            StableCounter <= 0;
            ButtonDown <= 1'b0;
            ButtonEvent <= 1'b0;
        end
        else begin
            ButtonEvent <= 1'b0; // Default: no new press this cycle

            if (ButtonSync == ButtonDown) begin
                // Back to the accepted state: cancel any candidate change.
                StableCounter <= 0;
            end
            else if (StableCounter == LAST_COUNT) begin
                // Opposite state has lasted long enough. Accept it.
                StableCounter <= 0;
                ButtonDown <= ButtonSync;
                ButtonEvent <= ButtonSync; // Pulse on press, not release
            end
            else begin
                // Opposite state is still being checked.
                StableCounter <= StableCounter + 1'b1;
            end
        end
    end
endmodule
