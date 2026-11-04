`timescale 1ns / 1ps
// AI-assisted educational integration test for Giggs's CG3207 Lab 4 Wrapper.
// Uses the actual CPU and peripherals. No forced IRQ, bus, pending bits or PC.
// Only IROM/DMEM are initialized hierarchically, while RESET is asserted.
// Use as SIMULATION SOURCE ONLY. See README before running.
module test_Wrapper_ButtonIRQ;
    reg CLK = 0;
    reg RESET = 1;
    reg [15:0] DIP = 0;
    reg [2:0] PB = 0;
    wire [7:0] LED_OUT;
    wire [6:0] LED_PC;
    wire [31:0] SEVENSEGHEX;
    wire [7:0] UART_TX;
    wire UART_TX_valid, UART_RX_ack, OLED_Write, ACCEL_DReady_unused;
    wire [6:0] OLED_Col;
    wire [5:0] OLED_Row;
    wire [23:0] OLED_Data;

    Wrapper dut (
        .DIP(DIP), .PB(PB), .LED_OUT(LED_OUT), .LED_PC(LED_PC),
        .SEVENSEGHEX(SEVENSEGHEX), .UART_TX(UART_TX),
        .UART_TX_ready(1'b1), .UART_TX_valid(UART_TX_valid),
        .UART_RX(8'd0), .UART_RX_valid(1'b0), .UART_RX_ack(UART_RX_ack),
        .OLED_Write(OLED_Write), .OLED_Col(OLED_Col), .OLED_Row(OLED_Row),
        .OLED_Data(OLED_Data), .ACCEL_Data(32'd0), .ACCEL_DReady(1'b0),
        .RESET(RESET), .CLK(CLK)
    );
    always #80 CLK = ~CLK;


    integer checks=0, i, n;
    task check;
        input [31:0] actual, expected;
        input [8*100-1:0] msg;
        begin
            checks=checks+1;
            if(actual !== expected) begin
                $display("FAIL %0s actual=%h expected=%h PC=%h",msg,actual,expected,dut.PC);
                $fatal(1,"Button IRQ test failed");
            end
        end
    endtask
    task settle;
        begin repeat(600) @(negedge CLK); end
    endtask
    task count_is;
        input [31:0] expected;
        begin
            settle;
            check(SEVENSEGHEX,expected,"display count");
            check(dut.DMEM[0],expected,"ISR count in RAM");
            check(dut.Pending,0,"handler acknowledged event");
            check(dut.IRQ,0,"IRQ cleared");
            check(dut.ButtonEvent,0,"event not sustained");
        end
    endtask
    task boot;
        begin
            @(negedge CLK); RESET=1; PB=0;
            repeat(5) @(negedge CLK);
            RESET=0;
            n=0;
            while(dut.EnableMask !== 2'b10 && n<2000) begin
                @(negedge CLK);n=n+1;
            end
            check(dut.EnableMask,2,"button interrupt enabled by software");
            count_is(0);
        end
    endtask
    // Model the sampled button path independently from physical input stimulus.
    reg [2:0] m1=0,m2=0;
    reg previous=0, expected_event;
    integer events=0, entries=0, returns=0;
    reg [31:0] saved_pc;
    reg taken, returning;
    always @(posedge CLK) begin
        taken=dut.RV1.InterruptTaken; returning=dut.RV1.ReturnFromInterrupt;
        if(RESET) begin
            m1=0;m2=0;previous=0;events=0;entries=0;returns=0;
        end else begin
            if(dut.ButtonEvent) events=events+1;
            if(taken) begin
                check(dut.RV1.PipelineEmpty,1,"entry after drain");
                saved_pc=dut.PC; entries=entries+1;
            end
            if(returning) begin
                check(dut.RV1.ReturnPC,saved_pc,"return to saved PC");
                returns=returns+1;
            end
            previous=m2[1];m2=m1;m1=PB;
        end
        expected_event=!RESET && m2[1] && !previous;
        #1;
        check(dut.PB_sync,m2,"synchronised button levels");
        check(dut.ButtonEvent,expected_event,"one-cycle rising-edge event");
        if(!RESET && taken) check(dut.PC,32'h00400100,"handler address");
        if(!RESET && returning) check(dut.PC,saved_pc,"resume address");
    end
    initial begin
        #2;
        check(dut.IROM[0],32'h2000006f,"correct button test ROM");
        check(dut.IROM[1],32'h00000013,"correct button test ROM");
        check(dut.IROM[2],32'h00000013,"correct button test ROM");
        check(dut.IROM[3],32'h00000013,"correct button test ROM");
        check(dut.IROM[4],32'h00000013,"correct button test ROM");
        check(dut.IROM[5],32'h00000013,"correct button test ROM");
        check(dut.IROM[6],32'h00000013,"correct button test ROM");
        check(dut.IROM[7],32'h00000013,"correct button test ROM");
        check(dut.IROM[8],32'h00000013,"correct button test ROM");
        check(dut.IROM[9],32'h00000013,"correct button test ROM");
        check(dut.IROM[10],32'h00000013,"correct button test ROM");
        check(dut.IROM[11],32'h00000013,"correct button test ROM");
        check(dut.IROM[12],32'h00000013,"correct button test ROM");
        check(dut.IROM[13],32'h00000013,"correct button test ROM");
        check(dut.IROM[14],32'h00000013,"correct button test ROM");
        check(dut.IROM[15],32'h00000013,"correct button test ROM");
        check(dut.IROM[16],32'h00000013,"correct button test ROM");
        check(dut.IROM[17],32'h00000013,"correct button test ROM");
        check(dut.IROM[18],32'h00000013,"correct button test ROM");
        check(dut.IROM[19],32'h00000013,"correct button test ROM");
        check(dut.IROM[20],32'h00000013,"correct button test ROM");
        check(dut.IROM[21],32'h00000013,"correct button test ROM");
        check(dut.IROM[22],32'h00000013,"correct button test ROM");
        check(dut.IROM[23],32'h00000013,"correct button test ROM");
        check(dut.IROM[24],32'h00000013,"correct button test ROM");
        check(dut.IROM[25],32'h00000013,"correct button test ROM");
        check(dut.IROM[26],32'h00000013,"correct button test ROM");
        check(dut.IROM[27],32'h00000013,"correct button test ROM");
        check(dut.IROM[28],32'h00000013,"correct button test ROM");
        check(dut.IROM[29],32'h00000013,"correct button test ROM");
        check(dut.IROM[30],32'h00000013,"correct button test ROM");
        check(dut.IROM[31],32'h00000013,"correct button test ROM");
        check(dut.IROM[32],32'h00000013,"correct button test ROM");
        check(dut.IROM[33],32'h00000013,"correct button test ROM");
        check(dut.IROM[34],32'h00000013,"correct button test ROM");
        check(dut.IROM[35],32'h00000013,"correct button test ROM");
        check(dut.IROM[36],32'h00000013,"correct button test ROM");
        check(dut.IROM[37],32'h00000013,"correct button test ROM");
        check(dut.IROM[38],32'h00000013,"correct button test ROM");
        check(dut.IROM[39],32'h00000013,"correct button test ROM");
        check(dut.IROM[40],32'h00000013,"correct button test ROM");
        check(dut.IROM[41],32'h00000013,"correct button test ROM");
        check(dut.IROM[42],32'h00000013,"correct button test ROM");
        check(dut.IROM[43],32'h00000013,"correct button test ROM");
        check(dut.IROM[44],32'h00000013,"correct button test ROM");
        check(dut.IROM[45],32'h00000013,"correct button test ROM");
        check(dut.IROM[46],32'h00000013,"correct button test ROM");
        check(dut.IROM[47],32'h00000013,"correct button test ROM");
        check(dut.IROM[48],32'h00000013,"correct button test ROM");
        check(dut.IROM[49],32'h00000013,"correct button test ROM");
        check(dut.IROM[50],32'h00000013,"correct button test ROM");
        check(dut.IROM[51],32'h00000013,"correct button test ROM");
        check(dut.IROM[52],32'h00000013,"correct button test ROM");
        check(dut.IROM[53],32'h00000013,"correct button test ROM");
        check(dut.IROM[54],32'h00000013,"correct button test ROM");
        check(dut.IROM[55],32'h00000013,"correct button test ROM");
        check(dut.IROM[56],32'h00000013,"correct button test ROM");
        check(dut.IROM[57],32'h00000013,"correct button test ROM");
        check(dut.IROM[58],32'h00000013,"correct button test ROM");
        check(dut.IROM[59],32'h00000013,"correct button test ROM");
        check(dut.IROM[60],32'h00000013,"correct button test ROM");
        check(dut.IROM[61],32'h00000013,"correct button test ROM");
        check(dut.IROM[62],32'h00000013,"correct button test ROM");
        check(dut.IROM[63],32'h00000013,"correct button test ROM");
        check(dut.IROM[64],32'hff010113,"correct button test ROM");
        check(dut.IROM[65],32'h01412023,"correct button test ROM");
        check(dut.IROM[66],32'h01512223,"correct button test ROM");
        check(dut.IROM[67],32'h110faa03,"correct button test ROM");
        check(dut.IROM[68],32'h002a7a13,"correct button test ROM");
        check(dut.IROM[69],32'h000a0e63,"correct button test ROM");
        check(dut.IROM[70],32'h000f2a83,"correct button test ROM");
        check(dut.IROM[71],32'h001a8a93,"correct button test ROM");
        check(dut.IROM[72],32'h015f2023,"correct button test ROM");
        check(dut.IROM[73],32'h095fa023,"correct button test ROM");
        check(dut.IROM[74],32'h00200a13,"correct button test ROM");
        check(dut.IROM[75],32'h114faa23,"correct button test ROM");
        check(dut.IROM[76],32'h00012a03,"correct button test ROM");
        check(dut.IROM[77],32'h00412a83,"correct button test ROM");
        check(dut.IROM[78],32'h01010113,"correct button test ROM");
        check(dut.IROM[79],32'h30200073,"correct button test ROM");
        check(dut.IROM[80],32'h00000013,"correct button test ROM");
        check(dut.IROM[81],32'h00000013,"correct button test ROM");
        check(dut.IROM[82],32'h00000013,"correct button test ROM");
        check(dut.IROM[83],32'h00000013,"correct button test ROM");
        check(dut.IROM[84],32'h00000013,"correct button test ROM");
        check(dut.IROM[85],32'h00000013,"correct button test ROM");
        check(dut.IROM[86],32'h00000013,"correct button test ROM");
        check(dut.IROM[87],32'h00000013,"correct button test ROM");
        check(dut.IROM[88],32'h00000013,"correct button test ROM");
        check(dut.IROM[89],32'h00000013,"correct button test ROM");
        check(dut.IROM[90],32'h00000013,"correct button test ROM");
        check(dut.IROM[91],32'h00000013,"correct button test ROM");
        check(dut.IROM[92],32'h00000013,"correct button test ROM");
        check(dut.IROM[93],32'h00000013,"correct button test ROM");
        check(dut.IROM[94],32'h00000013,"correct button test ROM");
        check(dut.IROM[95],32'h00000013,"correct button test ROM");
        check(dut.IROM[96],32'h00000013,"correct button test ROM");
        check(dut.IROM[97],32'h00000013,"correct button test ROM");
        check(dut.IROM[98],32'h00000013,"correct button test ROM");
        check(dut.IROM[99],32'h00000013,"correct button test ROM");
        check(dut.IROM[100],32'h00000013,"correct button test ROM");
        check(dut.IROM[101],32'h00000013,"correct button test ROM");
        check(dut.IROM[102],32'h00000013,"correct button test ROM");
        check(dut.IROM[103],32'h00000013,"correct button test ROM");
        check(dut.IROM[104],32'h00000013,"correct button test ROM");
        check(dut.IROM[105],32'h00000013,"correct button test ROM");
        check(dut.IROM[106],32'h00000013,"correct button test ROM");
        check(dut.IROM[107],32'h00000013,"correct button test ROM");
        check(dut.IROM[108],32'h00000013,"correct button test ROM");
        check(dut.IROM[109],32'h00000013,"correct button test ROM");
        check(dut.IROM[110],32'h00000013,"correct button test ROM");
        check(dut.IROM[111],32'h00000013,"correct button test ROM");
        check(dut.IROM[112],32'h00000013,"correct button test ROM");
        check(dut.IROM[113],32'h00000013,"correct button test ROM");
        check(dut.IROM[114],32'h00000013,"correct button test ROM");
        check(dut.IROM[115],32'h00000013,"correct button test ROM");
        check(dut.IROM[116],32'h00000013,"correct button test ROM");
        check(dut.IROM[117],32'h00000013,"correct button test ROM");
        check(dut.IROM[118],32'h00000013,"correct button test ROM");
        check(dut.IROM[119],32'h00000013,"correct button test ROM");
        check(dut.IROM[120],32'h00000013,"correct button test ROM");
        check(dut.IROM[121],32'h00000013,"correct button test ROM");
        check(dut.IROM[122],32'h00000013,"correct button test ROM");
        check(dut.IROM[123],32'h00000013,"correct button test ROM");
        check(dut.IROM[124],32'h00000013,"correct button test ROM");
        check(dut.IROM[125],32'h00000013,"correct button test ROM");
        check(dut.IROM[126],32'h00000013,"correct button test ROM");
        check(dut.IROM[127],32'h00000013,"correct button test ROM");
        check(dut.IROM[128],32'hffff0fb7,"correct button test ROM");
        check(dut.IROM[129],32'h10010f37,"correct button test ROM");
        check(dut.IROM[130],32'h200f0113,"correct button test ROM");
        check(dut.IROM[131],32'h100fa223,"correct button test ROM");
        check(dut.IROM[132],32'h100fa623,"correct button test ROM");
        check(dut.IROM[133],32'h000f2023,"correct button test ROM");
        check(dut.IROM[134],32'h080fa023,"correct button test ROM");
        check(dut.IROM[135],32'h00300a13,"correct button test ROM");
        check(dut.IROM[136],32'h114faa23,"correct button test ROM");
        check(dut.IROM[137],32'h00200a13,"correct button test ROM");
        check(dut.IROM[138],32'h114fa623,"correct button test ROM");
        check(dut.IROM[139],32'h068fa283,"correct button test ROM");
        check(dut.IROM[140],32'h065fa023,"correct button test ROM");
        check(dut.IROM[141],32'hff9ff06f,"correct button test ROM");
        boot;
        // Stimulus changes on falling edges, safely away from sampling edges.
        PB=3'b100;settle;check(LED_OUT,4,"left button MMIO readback");count_is(0);
        PB=3'b001;settle;check(LED_OUT,1,"right button MMIO readback");count_is(0);
        PB=0;settle;
        PB=3'b010;count_is(1);check(LED_OUT,2,"centre button level");
        count_is(1); // Still held: must not retrigger after ACK.
        PB=0;count_is(1);check(LED_OUT,0,"released buttons");
        PB=3'b010;count_is(2);
        PB=0;count_is(2);
        PB=3'b111;count_is(3);check(LED_OUT,7,"all buttons readback");
        PB=0;count_is(3);
        check(events,3,"three clean rising edges");
        check(entries,3,"three ISR entries");check(returns,3,"three MRET returns");
        boot; // Software and hardware restart without reloading RAM.
        PB=3'b010;count_is(1);
        PB=0;count_is(1);
        check(events,1,"one event after reset");
        check(entries,1,"one entry after reset");check(returns,1,"one return after reset");
        $display("BUTTON IRQ PASS: %0d checks; clean presses, hold, release, MMIO and reset",checks);
        $finish;
    end
    initial begin #10000000; $fatal(1,"Global timeout"); end
endmodule
