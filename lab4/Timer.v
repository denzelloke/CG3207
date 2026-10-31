`timescale 1ns / 1ps

//Used to generate ticks that the game will operate on. Uses the CPU's CLK, but counts clock cycles independently of what instructions the CPU is executing 
module Timer (
    input CLK,                    // Same clock as the CPU; each rising edge is one timer counting step.
    input RESET,                  // Clears the timer's counters and saved settings; disables the timer.

    input ConfigureWritePulse,    // When 1 at a rising edge, saves Period and Enable as the new settings.
                                  // Wrapper must assert and deassert!!

    input [31:0] Period,          // e.g. If game wants a tick every 20ms, and CPU clock is 10Mhz, then Period must be inputted as 10000000*0.020 = 200000
                                  // Later supplied through Wrapper from a software-written register.
                                  // Captured only when ConfigureWritePulse is 1; 0 means no events.

    input Enable,                 // New run setting: 1 = run, 0 = stop.
                                  // Captured with Period when ConfigureWritePulse is 1.
                                  // Changing this input alone does not change the saved setting.

    output reg TimerEvent,            // One-clock pulse whenever a complete interval has elapsed.
                                  // Goes to InterruptController, which remembers the event until acknowledged.

    output reg [31:0] TicksCounter// Total number of timer events generated since RESET—not CPU clock cycles.
                                  // Later readable by software to track how many timer intervals have elapsed.
);

reg [31:0] SavedPeriod = 0;     //stores the configured number of clock cycles per interval
reg SavedEnable = 0;            //remembers Enable when configuration is written
reg [31:0] IntervalCounter = 0; //counts clock cycles within the current interval

//expires when the timer is running and has reached N clock cycles
wire Expired;
assign Expired = SavedEnable && (SavedPeriod > 0) && (IntervalCounter == SavedPeriod - 32'd1);

always @ (posedge CLK) begin
    //highest priority; if reset clear everything
    if (RESET) begin            
        SavedPeriod <= 32'b0;
        SavedEnable <= 1'b0;
        IntervalCounter <= 32'b0;
        TimerEvent <= 1'b0;
        TicksCounter <= 32'b0;
    end
    //captures new settings and then starts new interval counting
    //TicksCounter is preserved so no write here
    else if (ConfigureWritePulse) begin
        SavedPeriod <= Period;
        SavedEnable <= Enable;
        IntervalCounter <= 32'b0;
        TimerEvent <= 1'b0;
    end
    else if (SavedEnable == 1'b0 || SavedPeriod == 32'b0) begin
        //timer is stopped so dont count or generate events
        IntervalCounter <= 32'b0;
        TimerEvent <= 1'b0;
    end
    else if (Expired) begin
        //interval completed so increment TicksCounter and restart counting
        IntervalCounter <= 32'b0;
        TimerEvent <= 1'b1;
        TicksCounter <= TicksCounter + 32'd1;
    end
    else begin
        //still in progress, count one more clock cycle
        IntervalCounter <= IntervalCounter + 32'd1;
        TimerEvent <= 1'b0;
    end
end

endmodule