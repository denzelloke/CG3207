`timescale 1ns/1ps
// Educational demo instrumentation. Counters are MMIO, not RISC-V CSRs.
// Control: bit0 enable (level), bit1 clear, bit2 freeze a coherent snapshot.
// Priority reset > clear > snapshot > count. Control cycles do not count.
module PerformanceCounters (
    input clk, reset, control_write,
    input [2:0] control,
    input [6:0] events,
    input [3:0] index,
    output reg [31:0] read_data,
    output reg enabled
);
    reg [31:0] live [0:7];
    reg [31:0] snapshot [0:7];
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            enabled <= 0;
            for (i=0;i<8;i=i+1) begin live[i]<=0; snapshot[i]<=0; end
        end else if (control_write) begin
            enabled <= control[0];
            if (control[1]) begin
                for (i=0;i<8;i=i+1) begin live[i]<=0; snapshot[i]<=0; end
            end else if (control[2]) begin
                for (i=0;i<8;i=i+1) snapshot[i]<=live[i];
            end
        end else if (enabled) begin
            live[0] <= live[0] + 1'b1;
            for (i=1;i<8;i=i+1) live[i] <= live[i] + {31'b0,events[i-1]};
        end
    end
    always @* begin
        read_data=0;
        if (index==0) read_data={31'b0,enabled};
        else if (index>=2 && index<=9) read_data=snapshot[index-2];
    end
endmodule
