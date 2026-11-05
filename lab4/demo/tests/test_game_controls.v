`timescale 1ns/1ps
module test_game_controls;
    reg clk=0,reset=1;always #5 clk=~clk;
    reg pixel_clk=0;always #20 pixel_clk=~pixel_clk;
    integer pixel_count=0;
    reg[3:0] buttons=0;reg[15:0] switches=7;
    reg frame=0;wire[2047:0] objects;wire[511:0] hud;wire[15:0]led;wire[31:0]seg,pc;
    integer cycles=0,old_count,mode=7,old_x,old_score,old_wave;
    GameSoC #(.DEBOUNCE_CYCLES(3),.TICK_CYCLES(16000)) dut
        (clk,reset,pixel_clk,reset,buttons,switches,frame,objects,hud,led,seg,pc);
    always @(negedge pixel_clk) begin
        pixel_count=pixel_count+1;frame=(pixel_count%1000==0);
    end
    always @(negedge clk) begin
        cycles=cycles+1;
        if(cycles>1000000)$fatal(1,"Controls timeout state=%d pc=%h",dut.dmem[0],pc);
    end
    task tick;begin @(negedge clk);end endtask
    task step;begin
        old_count=dut.dmem[6];wait(dut.dmem[6]!==old_count);tick;
    end endtask
    task press_start;begin buttons=8;repeat(12)tick;buttons=0;repeat(12)tick;end endtask
    task check;input condition;input[511:0] msg;begin if(condition!==1'b1)$fatal(1,"%s pc=%h",msg,pc);end endtask
    initial begin
        if($value$plusargs("MODE=%d",mode))begin end
        switches=mode;repeat(12)tick;reset=0;
        wait(dut.dmem[0]===0 && dut.period!==0);
        check(dut.dmem[2]==3,"menu initialized");
        press_start;wait(dut.dmem[0]===1);step;
        old_x=dut.dmem[4];buttons=4;repeat(12)tick;step;
        check(dut.dmem[4]==old_x-5,"left movement");
        buttons=1;repeat(12)tick;step;
        check(dut.dmem[4]==old_x,"right movement");
        dut.dmem[4]=16;buttons=4;repeat(12)tick;step;
        check(dut.dmem[4]==16,"left boundary clamp");
        dut.dmem[4]=600;buttons=1;repeat(12)tick;step;
        check(dut.dmem[4]==600,"right boundary clamp");
        buttons=0;repeat(12)tick;
        // A short but fully debounced fire press is retained until next update.
        buttons=2;repeat(12)tick;buttons=0;repeat(12)tick;step;
        check(dut.dmem[81][7:0]==1,"short fire press allocated bullet");
        // Seed one known collision, keeping the rest inactive and away.
        dut.dmem[64]={16'd200,16'd300};dut.dmem[65]=32'h00000201;
        dut.dmem[66]={16'd144,16'd96};dut.dmem[67]=32'h00000201;
        dut.dmem[68]={16'd144,16'd224};dut.dmem[69]=32'h00000201;
        dut.dmem[70]={16'd144,16'd480};dut.dmem[71]=32'h00000201;
        dut.dmem[80]={16'd212,16'd310};dut.dmem[81]=1;
        dut.dmem[83]=0;dut.dmem[85]=0;dut.dmem[87]=0;
        old_score=dut.dmem[1];step;
        check(dut.dmem[65][7:0]==0 && dut.dmem[81][7:0]==0,"collision consumes enemy and bullet");
        check(dut.dmem[1]==old_score+10,"score exactly once");
        step;check(dut.dmem[1]==old_score+10,"no duplicate score");
        old_wave=dut.dmem[3];dut.dmem[65]=0;dut.dmem[67]=0;dut.dmem[69]=0;dut.dmem[71]=0;
        step;check(dut.dmem[3]==old_wave+1 && dut.dmem[65][7:0]==1,"wave repopulation");
        // Force the next movement tick to cross the invasion line with one life.
        dut.dmem[6]=8;dut.dmem[2]=1;
        dut.dmem[64]={16'd419,16'd600};dut.dmem[65]=32'h00000201;
        wait(dut.dmem[0]===2);tick;
        check(dut.dmem[2]==0,"invasion causes game over");
        press_start;wait(dut.dmem[0]===1);step;
        check(dut.dmem[2]==3 && dut.dmem[1]==0 && dut.dmem[3]==1,"round restart restores state");
        $display("CONTROLS PASS mode=%0d",mode);$finish;
    end
endmodule
