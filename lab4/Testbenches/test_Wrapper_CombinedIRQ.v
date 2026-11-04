`timescale 1ns / 1ps
// Simulation only. Uses actual memories; does not force CPU or IRQ signals.
module test_Wrapper_CombinedIRQ;
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



    localparam integer PERIOD = 625000;
    localparam integer DEBOUNCE = 62500;
    integer checks=0, timer_events=0, button_events=0;
    integer entries=0, returns=0, both_pending=0, busy_irq=0;
    integer old_progress, old_ticks;
    reg [31:0] resume_pc;
    reg taken, returning;
    reg [1:0] pending_next;
    reg [2:0] meta_model=0, sync_model=0;
    reg down_model=0, event_model=0;
    integer stable_model=0;

    task check;
        input [31:0] actual, expected;
        input [8*100-1:0] message;
        begin
            checks=checks+1;
            if(actual !== expected) begin
                $display("FAIL %0s actual=%h expected=%h PC=%h time=%0t",
                         message,actual,expected,dut.PC,$time);
                $fatal(1,"Combined IRQ test failed");
            end
        end
    endtask

    task drive;
        input [2:0] value;
        input integer cycles;
        begin
            @(negedge CLK); PB=value;
            repeat(cycles) @(negedge CLK);
        end
    endtask

    // Check only after interrupts have had time to finish, away from expiry.
    task checkpoint;
        input integer expected_buttons;
        begin
            repeat(3000) @(negedge CLK);
            while(dut.Timer1.IntervalCounter < 3000 ||
                  dut.Timer1.IntervalCounter > PERIOD-4000)
                @(negedge CLK);
            check(dut.DMEM[0],timer_events,"all generated timer events serviced");
            check(dut.DMEM[1],expected_buttons,"button ISR count");
            check(button_events,expected_buttons,"qualified button event count");
            check(dut.DMEM[3],0,"foreground has no error");
            check(SEVENSEGHEX,{dut.DMEM[0][15:0],dut.DMEM[1][15:0]},
                  "display packs timer and button counts");
            check(dut.Pending,0,"both pending sources acknowledged");
            check(dut.IRQ,0,"IRQ cleared after service");
            check(entries,returns,"all interrupt entries have returned");
            check(LED_OUT,{5'b10000,PB[2],dut.CentreButtonDown,PB[0]},
                  "LED7 alive and button readback");
            if(dut.DMEM[2]===0 || ^dut.DMEM[2]===1'bx)
                $fatal(1,"Foreground made no progress");
        end
    endtask

    task boot;
        integer timeout;
        begin
            @(negedge CLK);RESET=1;PB=0;
            repeat(5) @(negedge CLK);RESET=0;
            timeout=0;
            while((dut.EnableMask !== 2'b11 ||
                   dut.Timer1.SavedEnable !== 1'b1) && timeout<10000) begin
                @(negedge CLK);timeout=timeout+1;
            end
            check(dut.EnableMask,3,"both sources enabled by assembly");
            check(dut.Timer1.SavedEnable,1,"timer enabled by assembly");
            check(dut.Timer1.SavedPeriod,PERIOD,"100ms timer period");
            checkpoint(0);
        end
    endtask

    always @(posedge CLK) begin
        taken=dut.RV1.InterruptTaken;
        returning=dut.RV1.ReturnFromInterrupt;
        if(RESET) begin
            timer_events=0;button_events=0;entries=0;returns=0;
            both_pending=0;busy_irq=0;resume_pc=0;
            pending_next=0;
            meta_model=0;sync_model=0;down_model=0;
            event_model=0;stable_model=0;
        end else begin
            pending_next=(dut.Pending & ~dut.ACK) |
                         {dut.ButtonEvent,dut.TimerEvent};
            if(dut.TimerEvent) timer_events=timer_events+1;
            if(dut.ButtonEvent) button_events=button_events+1;
            if(dut.Pending==3) both_pending=both_pending+1;
            if(dut.IRQ && dut.RV1.MCYCLESTALL) busy_irq=busy_irq+1;
            if(taken) begin
                check(dut.RV1.PipelineEmpty,1,"drained before entry");
                resume_pc=dut.PC;entries=entries+1;
            end
            if(returning) begin
                check(dut.RV1.ReturnPC,resume_pc,"saved return address");
                returns=returns+1;
            end
            event_model=0;
            if(sync_model[1]==down_model) stable_model=0;
            else begin
                stable_model=stable_model+1;
                if(stable_model==DEBOUNCE) begin
                    down_model=sync_model[1];event_model=sync_model[1];
                    stable_model=0;
                end
            end
            sync_model=meta_model;meta_model=PB;
        end
        #1;
        check(dut.Pending,pending_next,"pending/ACK/event arbitration");
        check(dut.PB_sync,sync_model,"button synchronisation");
        check(dut.CentreButtonDown,down_model,"debounced button level");
        check(dut.ButtonEvent,event_model,"qualified press pulse");
        if(!RESET && taken) check(dut.PC,32'h00400100,"handler redirect");
        if(!RESET && returning) check(dut.PC,resume_pc,"MRET redirect");
        if(!RESET && LED_OUT===8'hff)
            $fatal(1,"Assembly reported failure: display=%h",SEVENSEGHEX);
    end

    initial begin
        $display("Starting combined timer/button IRQ integration test");
        #2;
        check(dut.IROM[0],32'h2000006f,"combined test ROM");
        check(dut.IROM[1],32'h00000013,"combined test ROM");
        check(dut.IROM[2],32'h00000013,"combined test ROM");
        check(dut.IROM[3],32'h00000013,"combined test ROM");
        check(dut.IROM[4],32'h00000013,"combined test ROM");
        check(dut.IROM[5],32'h00000013,"combined test ROM");
        check(dut.IROM[6],32'h00000013,"combined test ROM");
        check(dut.IROM[7],32'h00000013,"combined test ROM");
        check(dut.IROM[8],32'h00000013,"combined test ROM");
        check(dut.IROM[9],32'h00000013,"combined test ROM");
        check(dut.IROM[10],32'h00000013,"combined test ROM");
        check(dut.IROM[11],32'h00000013,"combined test ROM");
        check(dut.IROM[12],32'h00000013,"combined test ROM");
        check(dut.IROM[13],32'h00000013,"combined test ROM");
        check(dut.IROM[14],32'h00000013,"combined test ROM");
        check(dut.IROM[15],32'h00000013,"combined test ROM");
        check(dut.IROM[16],32'h00000013,"combined test ROM");
        check(dut.IROM[17],32'h00000013,"combined test ROM");
        check(dut.IROM[18],32'h00000013,"combined test ROM");
        check(dut.IROM[19],32'h00000013,"combined test ROM");
        check(dut.IROM[20],32'h00000013,"combined test ROM");
        check(dut.IROM[21],32'h00000013,"combined test ROM");
        check(dut.IROM[22],32'h00000013,"combined test ROM");
        check(dut.IROM[23],32'h00000013,"combined test ROM");
        check(dut.IROM[24],32'h00000013,"combined test ROM");
        check(dut.IROM[25],32'h00000013,"combined test ROM");
        check(dut.IROM[26],32'h00000013,"combined test ROM");
        check(dut.IROM[27],32'h00000013,"combined test ROM");
        check(dut.IROM[28],32'h00000013,"combined test ROM");
        check(dut.IROM[29],32'h00000013,"combined test ROM");
        check(dut.IROM[30],32'h00000013,"combined test ROM");
        check(dut.IROM[31],32'h00000013,"combined test ROM");
        check(dut.IROM[32],32'h00000013,"combined test ROM");
        check(dut.IROM[33],32'h00000013,"combined test ROM");
        check(dut.IROM[34],32'h00000013,"combined test ROM");
        check(dut.IROM[35],32'h00000013,"combined test ROM");
        check(dut.IROM[36],32'h00000013,"combined test ROM");
        check(dut.IROM[37],32'h00000013,"combined test ROM");
        check(dut.IROM[38],32'h00000013,"combined test ROM");
        check(dut.IROM[39],32'h00000013,"combined test ROM");
        check(dut.IROM[40],32'h00000013,"combined test ROM");
        check(dut.IROM[41],32'h00000013,"combined test ROM");
        check(dut.IROM[42],32'h00000013,"combined test ROM");
        check(dut.IROM[43],32'h00000013,"combined test ROM");
        check(dut.IROM[44],32'h00000013,"combined test ROM");
        check(dut.IROM[45],32'h00000013,"combined test ROM");
        check(dut.IROM[46],32'h00000013,"combined test ROM");
        check(dut.IROM[47],32'h00000013,"combined test ROM");
        check(dut.IROM[48],32'h00000013,"combined test ROM");
        check(dut.IROM[49],32'h00000013,"combined test ROM");
        check(dut.IROM[50],32'h00000013,"combined test ROM");
        check(dut.IROM[51],32'h00000013,"combined test ROM");
        check(dut.IROM[52],32'h00000013,"combined test ROM");
        check(dut.IROM[53],32'h00000013,"combined test ROM");
        check(dut.IROM[54],32'h00000013,"combined test ROM");
        check(dut.IROM[55],32'h00000013,"combined test ROM");
        check(dut.IROM[56],32'h00000013,"combined test ROM");
        check(dut.IROM[57],32'h00000013,"combined test ROM");
        check(dut.IROM[58],32'h00000013,"combined test ROM");
        check(dut.IROM[59],32'h00000013,"combined test ROM");
        check(dut.IROM[60],32'h00000013,"combined test ROM");
        check(dut.IROM[61],32'h00000013,"combined test ROM");
        check(dut.IROM[62],32'h00000013,"combined test ROM");
        check(dut.IROM[63],32'h00000013,"combined test ROM");
        check(dut.IROM[64],32'hff010113,"combined test ROM");
        check(dut.IROM[65],32'h01412023,"combined test ROM");
        check(dut.IROM[66],32'h01512223,"combined test ROM");
        check(dut.IROM[67],32'h01612423,"combined test ROM");
        check(dut.IROM[68],32'h01712623,"combined test ROM");
        check(dut.IROM[69],32'h110faa03,"combined test ROM");
        check(dut.IROM[70],32'h001a7a93,"combined test ROM");
        check(dut.IROM[71],32'h000a8863,"combined test ROM");
        check(dut.IROM[72],32'h000f2b03,"combined test ROM");
        check(dut.IROM[73],32'h001b0b13,"combined test ROM");
        check(dut.IROM[74],32'h016f2023,"combined test ROM");
        check(dut.IROM[75],32'h002a7a93,"combined test ROM");
        check(dut.IROM[76],32'h000a8863,"combined test ROM");
        check(dut.IROM[77],32'h004f2b03,"combined test ROM");
        check(dut.IROM[78],32'h001b0b13,"combined test ROM");
        check(dut.IROM[79],32'h016f2223,"combined test ROM");
        check(dut.IROM[80],32'h000f2a83,"combined test ROM");
        check(dut.IROM[81],32'h010a9a93,"combined test ROM");
        check(dut.IROM[82],32'h004f2b03,"combined test ROM");
        check(dut.IROM[83],32'h010b1b13,"combined test ROM");
        check(dut.IROM[84],32'h010b5b13,"combined test ROM");
        check(dut.IROM[85],32'h016a8bb3,"combined test ROM");
        check(dut.IROM[86],32'h097fa023,"combined test ROM");
        check(dut.IROM[87],32'h003a7a13,"combined test ROM");
        check(dut.IROM[88],32'h114faa23,"combined test ROM");
        check(dut.IROM[89],32'h00012a03,"combined test ROM");
        check(dut.IROM[90],32'h00412a83,"combined test ROM");
        check(dut.IROM[91],32'h00812b03,"combined test ROM");
        check(dut.IROM[92],32'h00c12b83,"combined test ROM");
        check(dut.IROM[93],32'h01010113,"combined test ROM");
        check(dut.IROM[94],32'h30200073,"combined test ROM");
        check(dut.IROM[95],32'h06300d13,"combined test ROM");
        check(dut.IROM[96],32'h1640006f,"combined test ROM");
        check(dut.IROM[97],32'h00000013,"combined test ROM");
        check(dut.IROM[98],32'h00000013,"combined test ROM");
        check(dut.IROM[99],32'h00000013,"combined test ROM");
        check(dut.IROM[100],32'h00000013,"combined test ROM");
        check(dut.IROM[101],32'h00000013,"combined test ROM");
        check(dut.IROM[102],32'h00000013,"combined test ROM");
        check(dut.IROM[103],32'h00000013,"combined test ROM");
        check(dut.IROM[104],32'h00000013,"combined test ROM");
        check(dut.IROM[105],32'h00000013,"combined test ROM");
        check(dut.IROM[106],32'h00000013,"combined test ROM");
        check(dut.IROM[107],32'h00000013,"combined test ROM");
        check(dut.IROM[108],32'h00000013,"combined test ROM");
        check(dut.IROM[109],32'h00000013,"combined test ROM");
        check(dut.IROM[110],32'h00000013,"combined test ROM");
        check(dut.IROM[111],32'h00000013,"combined test ROM");
        check(dut.IROM[112],32'h00000013,"combined test ROM");
        check(dut.IROM[113],32'h00000013,"combined test ROM");
        check(dut.IROM[114],32'h00000013,"combined test ROM");
        check(dut.IROM[115],32'h00000013,"combined test ROM");
        check(dut.IROM[116],32'h00000013,"combined test ROM");
        check(dut.IROM[117],32'h00000013,"combined test ROM");
        check(dut.IROM[118],32'h00000013,"combined test ROM");
        check(dut.IROM[119],32'h00000013,"combined test ROM");
        check(dut.IROM[120],32'h00000013,"combined test ROM");
        check(dut.IROM[121],32'h00000013,"combined test ROM");
        check(dut.IROM[122],32'h00000013,"combined test ROM");
        check(dut.IROM[123],32'h00000013,"combined test ROM");
        check(dut.IROM[124],32'h00000013,"combined test ROM");
        check(dut.IROM[125],32'h00000013,"combined test ROM");
        check(dut.IROM[126],32'h00000013,"combined test ROM");
        check(dut.IROM[127],32'h00000013,"combined test ROM");
        check(dut.IROM[128],32'hffff0fb7,"combined test ROM");
        check(dut.IROM[129],32'h10010f37,"combined test ROM");
        check(dut.IROM[130],32'h200f0113,"combined test ROM");
        check(dut.IROM[131],32'h100fa223,"combined test ROM");
        check(dut.IROM[132],32'h100fa623,"combined test ROM");
        check(dut.IROM[133],32'h000f2023,"combined test ROM");
        check(dut.IROM[134],32'h000f2223,"combined test ROM");
        check(dut.IROM[135],32'h000f2423,"combined test ROM");
        check(dut.IROM[136],32'h000f2623,"combined test ROM");
        check(dut.IROM[137],32'h080fa023,"combined test ROM");
        check(dut.IROM[138],32'h00300a13,"combined test ROM");
        check(dut.IROM[139],32'h114faa23,"combined test ROM");
        check(dut.IROM[140],32'h00099a37,"combined test ROM");
        check(dut.IROM[141],32'h968a0a13,"combined test ROM");
        check(dut.IROM[142],32'h114fa023,"combined test ROM");
        check(dut.IROM[143],32'h00300a13,"combined test ROM");
        check(dut.IROM[144],32'h114fa623,"combined test ROM");
        check(dut.IROM[145],32'h00100a13,"combined test ROM");
        check(dut.IROM[146],32'h114fa223,"combined test ROM");
        check(dut.IROM[147],32'h07b00a13,"combined test ROM");
        check(dut.IROM[148],32'h1c800a93,"combined test ROM");
        check(dut.IROM[149],32'h31500b13,"combined test ROM");
        check(dut.IROM[150],32'h14100b93,"combined test ROM");
        check(dut.IROM[151],32'h00100293,"combined test ROM");
        check(dut.IROM[152],32'h00300413,"combined test ROM");
        check(dut.IROM[153],32'h028284b3,"combined test ROM");
        check(dut.IROM[154],32'h0284d533,"combined test ROM");
        check(dut.IROM[155],32'h00100d13,"combined test ROM");
        check(dut.IROM[156],32'h00000d93,"combined test ROM");
        check(dut.IROM[157],32'h06551863,"combined test ROM");
        check(dut.IROM[158],32'h00200d13,"combined test ROM");
        check(dut.IROM[159],32'h07b00d93,"combined test ROM");
        check(dut.IROM[160],32'h07ba1263,"combined test ROM");
        check(dut.IROM[161],32'h00300d13,"combined test ROM");
        check(dut.IROM[162],32'h1c800d93,"combined test ROM");
        check(dut.IROM[163],32'h05ba9c63,"combined test ROM");
        check(dut.IROM[164],32'h00400d13,"combined test ROM");
        check(dut.IROM[165],32'h31500d93,"combined test ROM");
        check(dut.IROM[166],32'h05bb1663,"combined test ROM");
        check(dut.IROM[167],32'h00500d13,"combined test ROM");
        check(dut.IROM[168],32'h14100d93,"combined test ROM");
        check(dut.IROM[169],32'h05bb9063,"combined test ROM");
        check(dut.IROM[170],32'h200f0d93,"combined test ROM");
        check(dut.IROM[171],32'h00600d13,"combined test ROM");
        check(dut.IROM[172],32'h03b11a63,"combined test ROM");
        check(dut.IROM[173],32'h008f2583,"combined test ROM");
        check(dut.IROM[174],32'h00158593,"combined test ROM");
        check(dut.IROM[175],32'h00bf2423,"combined test ROM");
        check(dut.IROM[176],32'h068fa603,"combined test ROM");
        check(dut.IROM[177],32'h00767613,"combined test ROM");
        check(dut.IROM[178],32'h08060613,"combined test ROM");
        check(dut.IROM[179],32'h06cfa023,"combined test ROM");
        check(dut.IROM[180],32'h00128293,"combined test ROM");
        check(dut.IROM[181],32'h02100d93,"combined test ROM");
        check(dut.IROM[182],32'hf9b296e3,"combined test ROM");
        check(dut.IROM[183],32'h00100293,"combined test ROM");
        check(dut.IROM[184],32'hf85ff06f,"combined test ROM");
        check(dut.IROM[185],32'h01af2623,"combined test ROM");
        check(dut.IROM[186],32'h100fa223,"combined test ROM");
        check(dut.IROM[187],32'h100fa623,"combined test ROM");
        check(dut.IROM[188],32'h0ff00d93,"combined test ROM");
        check(dut.IROM[189],32'h07bfa023,"combined test ROM");
        check(dut.IROM[190],32'hbad00db7,"combined test ROM");
        check(dut.IROM[191],32'h01ad8db3,"combined test ROM");
        check(dut.IROM[192],32'h09bfa023,"combined test ROM");
        check(dut.IROM[193],32'h0000006f,"combined test ROM");
        boot;
        drive(3'b100,3000);checkpoint(0);
        drive(3'b001,3000);checkpoint(0);
        drive(0,3000);
        $display("PASS: left/right readback without button IRQ");

        // All these press fragments are too short to qualify.
        drive(2,100);drive(0,100);drive(2,1000);drive(0,3000);
        checkpoint(0);
        $display("PASS: short bouncing press rejected");

        // Align a real press with the first timer expiry. No internal forcing.
        // Two synchroniser stages + debounce place its pulse near TimerEvent.
        while(dut.Timer1.IntervalCounter !== PERIOD-DEBOUNCE-3)
            @(negedge CLK);
        PB=2;
        repeat(DEBOUNCE+5000) @(negedge CLK);
        checkpoint(1);
        if(both_pending==0) $fatal(1,"No simultaneous pending sources observed");
        check(timer_events,1,"first timer tick occurred");
        $display("PASS: timer and centre-button pending together; both serviced");

        old_progress=dut.DMEM[2];old_ticks=timer_events;
        // Keep holding through two further timer intervals.
        repeat(2*PERIOD) @(negedge CLK);
        checkpoint(1);
        check(timer_events,old_ticks+2,"timer continues while button held");
        if(dut.DMEM[2]<=old_progress)
            $fatal(1,"Foreground stopped while button held");
        $display("PASS: timer and foreground progress while held; no repeat press");

        drive(0,100);drive(2,200);drive(0,500);drive(2,3000);
        checkpoint(1);
        drive(0,DEBOUNCE+4);checkpoint(1);
        drive(2,DEBOUNCE+4);checkpoint(2);
        drive(0,DEBOUNCE+4);checkpoint(2);
        $display("PASS: release bounce rejected; next deliberate press counted");
        $display("IRQ during MCycle busy: %0d sampled cycles",busy_irq);
        // Coverage is reported, not assumed: exact overlap depends on CPU timing.

        boot;
        check(timer_events,0,"reset restarts timer tick total");
        drive(2,DEBOUNCE+4);checkpoint(1);
        drive(0,DEBOUNCE+4);
        while(timer_events<1) @(negedge CLK);
        checkpoint(1);
        $display("PASS: reset and both interrupt sources work again");
        $display("COMBINED IRQ PASS: %0d checks",checks);
        $finish;
    end
    initial begin
        #1000000000;
        $fatal(1,"Global timeout after 1 second of simulated time");
    end
endmodule
