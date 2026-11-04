`timescale 1ns/1ps
// Demo wrapper around the original RV CPU. Async memory timing is preserved.
module GameSoC #(
    parameter ROM_FILE="game.mem",
    parameter IROM_WORDS=4096,
    parameter DMEM_WORDS=1024,
    parameter DEBOUNCE_CYCLES=250000,
    parameter TICK_CYCLES=416667,
    parameter REPLAY_UPDATES=600
) (
    input clk, reset,
    input [3:0] buttons,
    input [15:0] switches,
    input frame_boundary,
    output [2047:0] objects,
    output [511:0] hud,
    output reg [15:0] leds,
    output reg [31:0] sevenseg,
    output [31:0] debug_pc
);
    reg [31:0] irom[0:IROM_WORDS-1];
    reg [31:0] dmem[0:DMEM_WORDS-1];
    integer i;
    initial begin
        for(i=0;i<IROM_WORDS;i=i+1) irom[i]=32'h00000013;
        $readmemh(ROM_FILE,irom);
    end
    wire [3:0] held,pressed;
    wire [15:0] switch_sync;
    reg [15:0] mode;
    reg booted;
    wire cpu_reset=reset || !booted;
    GameInputs #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) inputs1
        (clk,reset,buttons,switches,held,pressed,switch_sync);
    always @(posedge clk) begin
        if(reset) begin mode<=0; booted<=0; end
        else if(!booted) begin mode<=switch_sync; booted<=1; end
    end
    wire [31:0] pc,addr,wdata;
    wire [3:0] mask;
    wire memread;
    wire [6:0] events;
    wire irq;
    reg [31:0] rdata;
    wire [31:0] instr=(pc>=32'h00400000 && pc<32'h00400000+IROM_WORDS*4 && pc[1:0]==0)
                       ? irom[(pc-32'h00400000)>>2] : 32'h00000013;
    RV #(.EXTERNAL_PREDICTOR_CONTROL(1)) cpu (
        .CLK(clk),.RESET(cpu_reset),.IRQ(irq),.Instr(instr),.ReadData_in(rdata),
        .MemRead(memread),.WriteMask(mask),.PCF(pc),.ALUResult(addr),
        .WriteData_out(wdata),.PredictionDisable(!mode[0]),.PerfEvents(events));
    assign debug_pc=pc;
    wire word_write=(&mask) && !cpu_reset && addr[1:0]==0;
    wire ram_select=(addr>=32'h10010000 && addr<32'h10010000+DMEM_WORDS*4);
    wire [31:0] aligned_addr={addr[31:2],2'b0};
    integer lane;
    always @(posedge clk) begin
        if(!cpu_reset && ram_select)
            for(lane=0;lane<4;lane=lane+1)
                if(mask[lane]) dmem[(addr-32'h10010000)>>2][lane*8+:8]<=wdata[lane*8+:8];
    end
    reg [31:0] period,cycles,fire_sequence,start_sequence;
    wire [31:0] ticks;
    wire timer_event;
    wire [1:0] pending,enable_mask;
    wire [1:0] ack=(word_write && addr==32'hffff0114) ? wdata[1:0] : 2'b0;
    Timer timer1(clk,cpu_reset,word_write && addr==32'hffff0104,
                 period,wdata[0],timer_event,ticks);
    InterruptController interrupt1(clk,cpu_reset,timer_event,pressed[1],
        word_write && addr==32'hffff010c,wdata[1:0],ack,pending,enable_mask,irq);
    reg irq_prev;
    reg [31:0] request_cycle,irq_latency;
    // Latency is IRQ assertion to accepted entry, including drain time. Coalesced
    // requests share the first assertion of the episode. Free-running, not gated
    // by the per-update performance-counter measurement window.
    always @(posedge clk) begin
        if(cpu_reset) begin
            period<=0; cycles<=0; fire_sequence<=0; start_sequence<=0;
            leds<=0; sevenseg<=0; irq_prev<=0; request_cycle<=0; irq_latency<=0;
        end else begin
            cycles<=cycles+1'b1;
            irq_prev<=irq;
            if(irq && !irq_prev) request_cycle<=cycles;
            if(events[5]) irq_latency<=cycles-request_cycle;
            if(pressed[1]) fire_sequence<=fire_sequence+1'b1;
            if(pressed[3]) start_sequence<=start_sequence+1'b1;
            if(word_write) begin
                if(addr==32'hffff0100) period<=wdata;
                if(addr==32'hffff0060) leds<=wdata[15:0];
                if(addr==32'hffff0080) sevenseg<=wdata;
            end
        end
    end
    wire [31:0] perf_data;
    wire perf_enabled;
    PerformanceCounters counters(clk,cpu_reset,word_write && addr==32'hffff0200,
        wdata[2:0],events,addr[5:2],perf_data,perf_enabled);
    wire display_busy;
    wire [31:0] frame_sequence;
    DisplayRegisters display1(clk,cpu_reset,frame_boundary,
        word_write && addr>=32'hffff0340 && addr<32'hffff0380,
        word_write && addr>=32'hffff0400 && addr<32'hffff0500,
        word_write && addr==32'hffff0300 && wdata[0],addr[7:2],wdata,
        display_busy,frame_sequence,objects,hud);
    always @* begin
        rdata=0;
        if(ram_select) rdata=dmem[(addr-32'h10010000)>>2];
        else if(aligned_addr>=32'hffff0200 && aligned_addr<=32'hffff0224) rdata=perf_data;
        else case(aligned_addr)
            32'hffff0064: rdata={16'b0,mode};
            32'hffff0068: rdata={28'b0,held};
            32'hffff00a0: rdata=cycles;
            32'hffff0100: rdata=period;
            32'hffff0108: rdata=ticks;
            32'hffff010c: rdata={30'b0,enable_mask};
            32'hffff0110: rdata={30'b0,pending};
            32'hffff0300: rdata={31'b0,display_busy};
            32'hffff0304: rdata=frame_sequence;
            32'hffff0330: rdata=fire_sequence;
            32'hffff0334: rdata=start_sequence;
            32'hffff0338: rdata=TICK_CYCLES;
            32'hffff033c: rdata=REPLAY_UPDATES;
            32'hffff0380: rdata=irq_latency;
            default: rdata=0;
        endcase
    end
endmodule
