`timescale 1ns/1ps
module test_display_cdc;
    integer cpu_half=7;
    reg clk=0,pixel_clk=0,reset=1,pixel_reset=1,cpu_pause=0;
    initial begin
        if($value$plusargs("CPU_HALF=%d",cpu_half))begin end
        forever begin #(cpu_half);if(!cpu_pause)clk=~clk;end
    end
    initial begin #3;forever #20 pixel_clk=~pixel_clk;end
    reg frame=0,wh=0,wo=0,commit=0;
    reg[5:0] index=0;reg[31:0] data=0;
    wire busy;wire[31:0] seq;wire[2047:0] objects;wire[511:0] hud;
    reg[2047:0] expected_objects,previous_objects;
    reg[511:0] expected_hud,previous_hud;
    reg boundary_at_edge;
    integer n,round;
    DisplayRegisters dut(clk,reset,pixel_clk,pixel_reset,frame,wh,wo,commit,
                         index,data,busy,seq,objects,hud);
    task tick;begin @(negedge clk);end endtask
    task check;input condition;input[511:0] msg;begin
        if(condition!==1'b1)$fatal(1,"%s CPU_HALF=%d",msg,cpu_half);
    end endtask
    task boundary;begin
        @(negedge pixel_clk);frame=1;
        @(negedge pixel_clk);frame=0;
    end endtask
    task fill;input[31:0] seed;begin
        expected_objects=0;expected_hud=0;
        for(n=0;n<64;n=n+1)begin
            index=n;data=seed+n;wo=1;tick;wo=0;
            expected_objects[n*32+:32]=seed+n;
        end
        for(n=0;n<16;n=n+1)begin
            index=n;data=seed+100+n;wh=1;
            // Last payload write and commit may occur on the same CPU edge.
            if(n==15)commit=1;
            tick;wh=0;commit=0;expected_hud[n*32+:32]=seed+100+n;
        end
    end endtask
    always @(posedge pixel_clk)begin
        previous_objects=objects;previous_hud=hud;boundary_at_edge=frame;
        #1;
        if(!pixel_reset && !boundary_at_edge &&
           (objects!==previous_objects || hud!==previous_hud))
            $fatal(1,"Active display changed outside vertical blank");
    end
    initial begin
        repeat(5)tick;reset=0;
        // Deliberately release pixel reset later than CPU reset.
        repeat(4)@(negedge pixel_clk);pixel_reset=0;tick;
        check(objects==0 && hud==0 && seq==0 && !busy,"initial state");
        for(round=1;round<=4;round=round+1)begin
            fill(32'habc00000+round*256);
            check(busy,"commit holds busy");
            // Repeated commit and writes while pending must not corrupt payload.
            wo=1;wh=1;index=3;data=32'hdeadbeef;commit=1;
            repeat(4)tick;wo=0;wh=0;commit=0;
            repeat(4)@(negedge pixel_clk);
            check(seq==round-1,"no ack before boundary");
            boundary;
            check(objects===expected_objects && hud===expected_hud,"atomic complete payload");
            wait(!busy);tick;
            check(seq==round,"exactly one acknowledgement");
            boundary;repeat(4)tick;check(seq==round,"no duplicate publication");
        end
        // Reset a request before publication: stale payload must never appear.
        fill(32'hdef00000);
        reset=1;pixel_reset=1;#2;
        check(!busy && objects==0 && hud==0 && seq==0,"reset pending request");
        repeat(4)tick;reset=0;
        repeat(4)@(negedge pixel_clk);pixel_reset=0;
        repeat(4)@(negedge pixel_clk);boundary;repeat(4)tick;
        check(objects==0 && hud==0 && seq==0,"no stale request after reset");
        // Reset after destination capture but before CPU can receive the ACK.
        fill(32'hfed00000);cpu_pause=1;
        repeat(4)@(negedge pixel_clk);boundary;
        check(busy && objects===expected_objects,"capture with CPU clock paused");
        reset=1;pixel_reset=1;#2;
        check(!busy && objects==0 && hud==0 && seq==0,"reset during ack flight");
        cpu_pause=0;repeat(4)tick;reset=0;pixel_reset=0;
        fill(32'h12340000);repeat(4)@(negedge pixel_clk);boundary;
        wait(!busy);tick;
        check(seq==1 && objects===expected_objects && hud===expected_hud,"restart after reset");
        $display("DISPLAY CDC PASS CPU_HALF=%0d",cpu_half);$finish;
    end
    initial begin #1000000;$fatal(1,"CDC timeout");end
endmodule
