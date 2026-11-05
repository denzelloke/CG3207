`timescale 1ns/1ps
module test_game #(parameter UPDATE_LIMIT=120);
    reg clk=0,reset=1;
    always #5 clk=~clk;
    reg [3:0] buttons=0;
    reg [15:0] switches=15;
    reg frame_boundary=0;
    wire [2047:0] objects;
    wire [511:0] hud;
    wire [15:0] leds;
    wire [31:0] sevenseg,pc;
    integer count=0,mode=15,deadline=0;
    integer entries=0,branches=0,misses=0;
    GameSoC #(.DEBOUNCE_CYCLES(3),.TICK_CYCLES(16000),.REPLAY_UPDATES(UPDATE_LIMIT)) dut
        (clk,reset,buttons,switches,frame_boundary,objects,hud,leds,sevenseg,pc);
    always @(negedge clk) begin
        count=count+1;
        frame_boundary=(count%16000==0);
        if(dut.events[5]) entries=entries+1;
        if(dut.events[1]) branches=branches+1;
        if(dut.events[2]) misses=misses+1;
        if(count>(UPDATE_LIMIT+20)*20000) $fatal(1,"Game timeout pc=%h state=%h updates=%d",pc,dut.dmem[0],dut.dmem[6]);
    end
    initial begin
        if($value$plusargs("MODE=%d",mode)) begin end
        switches=mode;
        repeat(12) @(negedge clk);
        reset=0;
        wait(dut.dmem[0]===32'd3);
        wait(hud[31:0]===32'd3);
        if(dut.dmem[6]!==UPDATE_LIMIT) $fatal(1,"Wrong update count");
        if(dut.dmem[9]!==0) $fatal(1,"Missed update deadlines: %d",dut.dmem[9]);
        if(dut.cpu.RegFile1.RegBank[2]!==32'h10011000) $fatal(1,"Stack not restored");
        if((mode&2)!=0 && entries==0) $fatal(1,"IRQ mode never entered handler");
        if((mode&2)==0 && entries!=0) $fatal(1,"Polling mode entered handler");
        if(dut.dmem[26]==0 || dut.dmem[27]==0) $fatal(1,"Counters empty");
        $display("GAME PASS mode=%0d checksum=%h score=%0d health=%0d wave=%0d updates=%0d cycles=%0d retired=%0d branches=%0d misses=%0d irq=%0d",
            mode,dut.dmem[20],dut.dmem[1],dut.dmem[2],dut.dmem[3],dut.dmem[6],dut.dmem[26],dut.dmem[29],dut.dmem[27],dut.dmem[28],entries);
        $finish;
    end
endmodule
