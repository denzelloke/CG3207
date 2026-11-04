`timescale 1ns/1ps
module test_peripherals;
    reg clk=0,reset=1;always #5 clk=~clk;
    reg control_write=0;reg [2:0] control=0;reg [6:0] events=0;reg [3:0] index=0;
    wire [31:0] data;wire enabled;
    PerformanceCounters c(clk,reset,control_write,control,events,index,data,enabled);
    reg frame=0,wh=0,wo=0,commit=0;reg[5:0] wi=0;reg[31:0] wd=0;
    wire busy;wire[31:0] seq;wire[2047:0] objects;wire[511:0] hud;
    DisplayRegisters d(clk,reset,frame,wh,wo,commit,wi,wd,busy,seq,objects,hud);
    reg [3:0] buttons=0;wire[3:0] held,pressed;wire[15:0] sw;
    GameInputs #(.DEBOUNCE_CYCLES(3)) g(clk,reset,buttons,16'h1234,held,pressed,sw);
    integer pulses=0;
    always @(negedge clk) if(pressed[1])pulses=pulses+1;
    task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
    task cmd;input[2:0] v;begin control=v;control_write=1;tick;control_write=0;end endtask
    task check;input condition;input[255:0] msg;begin if(condition!==1'b1)$fatal(1,"%s",msg);end endtask
    initial begin
        tick;tick;reset=0;tick;
        cmd(3); // clear and enable
        events=7'b0000011;tick; // retire+branch
        events=7'b0000101;tick; // retire+miss
        events=7'b0010000;tick; // MCycle only
        events=0;tick;
        cmd(4); // snapshot/stop; snapshot command cycle excluded
        index=2;#1;check(data==4,"cycle trace");
        index=3;#1;check(data==2,"retirement includes two events");
        index=4;#1;check(data==1,"branch trace");
        index=5;#1;check(data==1,"miss trace");
        index=7;#1;check(data==1,"MCycle trace");
        events=127;tick;tick;
        index=2;#1;check(data==4,"disabled freeze");
        cmd(1);tick;tick; // live changes, old snapshot stays
        #1;check(data==4,"snapshot stable while counting");
        cmd(7);index=2;#1;check(data==0,"clear takes priority over snapshot");
        // Inject a near-wrap precondition; then exercise real increment/snapshot.
        c.live[0]=32'hffffffff;events=0;tick;cmd(4);#1;check(data==0,"32-bit wrap");
        wh=1;wi=0;wd=32'h12345678;tick;wh=0;
        wo=1;wi=3;wd=1;tick;wo=0;
        check(hud==0 && objects==0,"no publication before commit");
        commit=1;tick;commit=0;check(busy,"pending commit");
        wh=1;wi=0;wd=32'hdeadbeef;tick;wh=0;
        check(hud==0,"waiting for vertical blank");
        frame=1;tick;frame=0;
        check(!busy && hud[31:0]==32'h12345678 && objects[96] && seq==1,"atomic commit and rejected busy write");
        frame=1;tick;frame=0;check(seq==1,"no duplicate commit");
        buttons=2;tick;buttons=0;repeat(8)tick;
        check(held==0 && pulses==0,"short glitch rejected");
        buttons=2;repeat(12)tick;
        check(held==2 && pulses==1,"one clean press");
        repeat(12)tick;check(pulses==1,"hold does not retrigger");
        buttons=0;repeat(12)tick;check(held==0 && pulses==1,"release");
        buttons=2;repeat(12)tick;check(pulses==2,"second press");
        reset=1;tick;check(!busy && hud==0 && seq==0 && held==0,"reset");
        $display("PERIPHERALS PASS");$finish;
    end
endmodule
