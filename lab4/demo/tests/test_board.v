`timescale 1ns/1ps
// Port-only smoke test also suitable for the post-synthesis functional netlist.
module test_board;
    reg CLK_undiv=0;always #5 CLK_undiv=~CLK_undiv;
    reg [15:0] DIP=15;reg [2:0] PB=0;reg START=0,RESET=1;
    wire [15:0]LED;wire[6:0]SevenSegCat;wire[7:0]SevenSegAn;wire DP;
    wire[3:0]VGA_R,VGA_G,VGA_B;wire VGA_HS,VGA_VS;
    NeonTop dut(CLK_undiv,DIP,PB,START,RESET,LED,SevenSegCat,SevenSegAn,DP,
                VGA_R,VGA_G,VGA_B,VGA_HS,VGA_VS);
    integer colored=0,hs_pulses=0;time start_hs,start_vs;
    reg checking=0;
    always @(negedge VGA_HS) if(checking)start_hs=$time;
    always @(posedge VGA_HS) if(checking)begin
        if(start_hs!=0 && $time-start_hs!=3840)$fatal(1,"HS width %0t",$time-start_hs);
        hs_pulses=hs_pulses+1;
    end
    always @(negedge VGA_VS) if(checking)start_vs=$time;
    always @(posedge VGA_VS) if(checking && start_vs!=0)
        if($time-start_vs!=64000)$fatal(1,"VS width %0t",$time-start_vs);
    always @(posedge CLK_undiv) if(checking)begin
        if ((^{VGA_R,VGA_G,VGA_B,VGA_HS,VGA_VS,SevenSegCat,SevenSegAn})===1'bx)
            $fatal(1,"Unknown board output");
        if({VGA_R,VGA_G,VGA_B}!=0)colored=colored+1;
    end
    initial begin
        start_hs=0;start_vs=0;
        #1000;RESET=0;
        #1000000;checking=1;
        #34000000;
        if(hs_pulses<1000 || colored<1000)$fatal(1,"Video not running");
        if(LED[1:0]!==3)$fatal(1,"Firmware health/LED initialization");
        $display("BOARD PORTS PASS");$finish;
    end
    initial begin #50000000;$fatal(1,"Board smoke timeout");end
endmodule
