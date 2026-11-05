`timescale 1ns/1ps
// Behavioural top-level clock/reset/scaling checks. Not an MMCM timing model.
module test_clock_domains #(parameter CPU_DIVIDE=16);
    reg board_clk=0;always #5 board_clk=~board_clk;
    reg reset=1;
    wire[15:0]led;wire[6:0]cat;wire[7:0]an;wire dp;
    wire[3:0]r,g,b;wire hs,vs;
    NeonTop #(.CPU_CLK_DIVIDE(CPU_DIVIDE)) dut(board_clk,16'd15,3'd0,1'b0,
        reset,led,cat,an,dp,r,g,b,hs,vs);
    realtime last_cpu=0,last_pixel=0,start_hs=0;
    integer cpu_edges=0,pixel_edges=0,hs_pulses=0;
    always @(posedge dut.cpu_clk)begin
        if(last_cpu!=0 && ($realtime-last_cpu < CPU_DIVIDE*1.25-0.002 ||
                          $realtime-last_cpu > CPU_DIVIDE*1.25+0.002))
            $fatal(1,"Wrong CPU period");
        last_cpu=$realtime;cpu_edges=cpu_edges+1;
    end
    always @(posedge dut.pixel_clk)begin
        if(last_pixel!=0 && $realtime-last_pixel!=40.0)$fatal(1,"Pixel clock changed");
        last_pixel=$realtime;pixel_edges=pixel_edges+1;
    end
    always @(negedge hs)start_hs=$realtime;
    always @(posedge hs)if(start_hs!=0 && !reset)begin
        if($realtime-start_hs!=3840.0)$fatal(1,"VGA HS changed with CPU clock");
        hs_pulses=hs_pulses+1;
    end
    initial begin
        #1000;reset=0;
        #2000000;
        if(dut.cpu_reset || dut.pixel_reset)$fatal(1,"Reset did not release");
        if(dut.soc.period!==dut.TICK_CYCLES)$fatal(1,"Firmware did not use scaled timer capability");
        if(dut.TICK_CYCLES!=(800000000/CPU_DIVIDE+30)/60)$fatal(1,"Timer scaling");
        if(dut.DEBOUNCE_CYCLES!=(800000000/CPU_DIVIDE)/100)$fatal(1,"Debounce scaling");
        if(hs_pulses<50 || led[1:0]!==3)$fatal(1,"Game or video did not boot");
        // A reset between clock edges must assert both domain resets immediately.
        #3;reset=1;#1;
        if(!dut.cpu_reset || !dut.pixel_reset)$fatal(1,"Asynchronous reset assertion");
        #100;reset=0;
        #200000;
        if(dut.cpu_reset || dut.pixel_reset)$fatal(1,"Restart reset did not release");
        $display("CLOCK DOMAINS PASS divider=%0d CPU_HZ=%0d PIXEL_HZ=25000000",CPU_DIVIDE,dut.CPU_HZ);
        $finish;
    end
    initial begin #3000000;$fatal(1,"Clock test timeout");end
endmodule
