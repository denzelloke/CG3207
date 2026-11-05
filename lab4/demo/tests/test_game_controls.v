`timescale 1ns/1ps
module test_game_controls;
    reg clk=0,reset=1;always #5 clk=~clk;
    reg[3:0] buttons=0;reg[15:0] switches=7;
    reg frame=0;wire[2047:0] objects;wire[511:0] hud;wire[15:0]led;wire[31:0]seg,pc;
    integer cycles=0,old_count,mode=7,old_x,old_score,old_wave,i,active_count,difficulty;
    GameSoC #(.DEBOUNCE_CYCLES(3),.TICK_CYCLES(16000)) dut
        (clk,reset,buttons,switches,frame,objects,hud,led,seg,pc);
    always @(negedge clk) begin
        cycles=cycles+1;frame=(cycles%4000==0);
        if(cycles>2500000)$fatal(1,"Controls timeout state=%d pc=%h",dut.dmem[0],pc);
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
        difficulty=(mode>>4)&3;active_count=0;
        for(i=0;i<7;i=i+1)if(dut.dmem[65+2*i][7:0]!=0)active_count=active_count+1;
        check(active_count==4+difficulty,"difficulty scales fleet size");
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
        old_wave=dut.dmem[3];
        for(i=0;i<7;i=i+1)dut.dmem[65+2*i]=0;
        step;check(dut.dmem[3]==old_wave+1 && dut.dmem[65][7:0]==1+(difficulty>>1),"wave repopulation");
        // Force the next movement tick to cross the invasion line with one life.
        dut.dmem[6]=8;dut.dmem[2]=1;
        dut.dmem[64]={16'd419,16'd600};dut.dmem[65]=32'h00000201;
        wait(dut.dmem[0]===2);tick;
        check(dut.dmem[2]==0,"invasion causes game over");
        press_start;wait(dut.dmem[0]===1 && dut.dmem[6]===0);step;
        check(dut.dmem[2]==3 && dut.dmem[1]==0 && dut.dmem[3]==1,"round restart restores state");
        // The CPU chooses a live shooter and creates a hostile projectile.
        dut.dmem[35]=1;dut.dmem[36]=0;dut.dmem[6]=1;
        dut.dmem[64]={16'd200,16'd100};dut.dmem[65]=32'h00000201;
        step;
        check(dut.dmem[89][7:0]==1 && dut.dmem[88]=={16'd216,16'd110},"enemy fires from muzzle");
        check(dut.dmem[35]==90-16*difficulty,"difficulty scales firing interval");
        check(dut.dmem[89][15:8]==(difficulty==0?0:1),"harder shots aim towards player");
        old_x=dut.dmem[88][31:16];step;
        check(dut.dmem[88][31:16]==old_x+3+difficulty,"enemy bullet moves downward");
        // Two simultaneous hits cost one life; both shots are consumed.
        dut.dmem[37]=0;dut.dmem[35]=90;
        dut.dmem[88]=(432<<16)+dut.dmem[4];dut.dmem[89]=1;
        dut.dmem[90]=(432<<16)+dut.dmem[4];dut.dmem[91]=1;
        step;
        check(dut.dmem[2]==2 && dut.dmem[37]==45,"hit damages player with grace period");
        check(dut.dmem[89][7:0]==0 && dut.dmem[91][7:0]==0,"overlapping hits consumed once");
        dut.dmem[88]=(432<<16)+dut.dmem[4];dut.dmem[89]=1;step;
        check(dut.dmem[2]==2 && dut.dmem[89][7:0]==0,"grace blocks repeated damage");
        // Last hostile slot expires at the screen boundary without corrupting RAM.
        dut.dmem[94]={16'd459,16'd200};dut.dmem[95]=1;dut.dmem[96]=32'h1234abcd;step;
        check(dut.dmem[95][7:0]==0 && dut.dmem[96]==32'h1234abcd,"hostile pool bounds and expiry");
        // Staggered direction reversal also changes y at a phase boundary.
        dut.dmem[6]=64;dut.dmem[64]={16'd200,16'd300};dut.dmem[65]=32'h00000201;
        step;
        check(dut.dmem[64][15:0]==298 && dut.dmem[65][15:8]==8'hfe,"zigzag reverses direction");
        check(dut.dmem[64][31:16]==205+difficulty,"zigzag descends and bobs");
        dut.dmem[37]=0;dut.dmem[2]=1;
        dut.dmem[88]=(432<<16)+dut.dmem[4];dut.dmem[89]=1;
        step;check(dut.dmem[2]==0 && dut.dmem[0]==2,"hostile hit causes game over");
        press_start;wait(dut.dmem[0]===1 && dut.dmem[6]===0);step;
        check(dut.dmem[2]==3 && dut.dmem[37]==0,"restart clears damage grace");
        for(i=0;i<4;i=i+1)check(dut.dmem[89+2*i][7:0]==0,"restart clears hostile shots");
        $display("CONTROLS PASS mode=%0d",mode);$finish;
    end
endmodule
