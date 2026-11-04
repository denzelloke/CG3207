`timescale 1ns / 1ps
// AI-assisted educational integration test for Giggs's CG3207 Lab 4 Wrapper.
// Uses the actual CPU and peripherals. No forced IRQ, bus, pending bits or PC.
// Only IROM/DMEM are initialized hierarchically, while RESET is asserted.
// Use as SIMULATION SOURCE ONLY. See README before running.
module test_Wrapper_TimerIRQ;
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
    always #5 CLK = ~CLK;

    integer checks = 0;
    integer entries = 0, returns = 0;
    integer masked_cycles = 0, irq_stall_cycles = 0;
    integer read_seen = 0, writes_seen = 0;
    integer run_number = 0, i, elapsed;
    reg monitoring = 0;
    reg in_handler = 0;
    reg [31:0] expected_epc = 0;
    reg [31:0] ref_period = 0, ref_saved_period = 0;
    reg ref_enable = 0, ref_event = 0;
    reg [31:0] ref_interval = 0, ref_ticks = 0;
    reg [1:0] ref_mask = 0, ref_pending = 0;
    reg [1:0] ack_now;
    reg store_word, config_now, enable_now, period_now;
    reg take_now, return_now;
    reg [31:0] pc_before, return_target;
    reg [31:0] final_ticks;

    task expect32;
        input [31:0] actual;
        input [31:0] expected;
        input [8*100-1:0] description;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                $display("FAIL run=%0d time=%0t: %0s expected=%08h actual=%08h",
                         run_number, $time, description, expected, actual);
                $fatal(1, "Wrapper timer/IRQ test failed");
            end
        end
    endtask

    // Independent peripheral model driven by CPU bus address/data/mask.
    // Sample before the DUT nonblocking updates; compare after they settle.
    // The IC sees the TimerEvent from BEFORE this edge, not the newly produced one.
    always @(posedge CLK) begin
        if (monitoring) begin
            take_now = dut.RV1.InterruptTaken;
            return_now = dut.RV1.ReturnFromInterrupt;
            pc_before = dut.PC;
            return_target = expected_epc;
            store_word = (dut.MemWrite_out === 4'b1111) && !RESET;
            period_now = store_word && (dut.ALUResult == 32'hFFFF0100);
            config_now = store_word && (dut.ALUResult == 32'hFFFF0104);
            enable_now = store_word && (dut.ALUResult == 32'hFFFF010C);
            ack_now = (store_word && dut.ALUResult == 32'hFFFF0114)
                       ? dut.WriteData_out[1:0] : 2'b00;

            if (!RESET) begin
                expect32(dut.TimerConfigureWritePulse, config_now, "timer configuration write decode");
                expect32(dut.LoadEnableMask, enable_now, "interrupt mask write decode");
                expect32(dut.ACK, ack_now, "ACK is present only for acknowledgement stores");
                expect32(dut.ButtonEvent, 0, "button path disabled for this test");
                if (ref_pending[0] && !ref_mask[0]) masked_cycles = masked_cycles + 1;
                if (dut.IRQ && dut.RV1.MCYCLESTALL) irq_stall_cycles = irq_stall_cycles + 1;

                if (dut.MemRead === 1'b1) begin
                    case (dut.ALUResult)
                        32'hFFFF0100: begin
                            expect32(dut.ReadData_in, ref_period, "CPU reads staged timer period");
                            read_seen = read_seen | 1;
                        end
                        32'hFFFF0108: begin
                            expect32(dut.ReadData_in, ref_ticks, "CPU reads tick counter");
                            read_seen = read_seen | 2;
                        end
                        32'hFFFF010C: begin
                            expect32(dut.ReadData_in, {30'd0,ref_mask}, "CPU reads enable mask");
                            read_seen = read_seen | 4;
                        end
                        32'hFFFF0110: begin
                            expect32(dut.ReadData_in, {30'd0,ref_pending}, "CPU reads pending bits");
                            read_seen = read_seen | 8;
                        end
                    endcase
                end
                if (period_now) writes_seen = writes_seen | 1;
                if (config_now) writes_seen = writes_seen | 2;
                if (enable_now) writes_seen = writes_seen | 4;
                if (ack_now != 0) writes_seen = writes_seen | 8;

                if (take_now === 1'b1) begin
                    expect32(in_handler, 0, "no nested interrupt entry");
                    expect32(dut.RV1.PipelineEmpty, 1, "entry waits for empty pipeline");
                    expect32({dut.RV1.ValidD,dut.RV1.ValidE,dut.RV1.ValidM,dut.RV1.ValidW}, 0,
                             "no admitted instructions remain at entry");
                    expected_epc = pc_before;
                    in_handler = 1;
                    entries = entries + 1;
                end
                if (return_now === 1'b1) begin
                    expect32(in_handler, 1, "return belongs to an active handler");
                    expect32(dut.RV1.ReturnPC, expected_epc, "MRET uses saved resume address");
                    in_handler = 0;
                    returns = returns + 1;
                end
                // Only the final PASS or explicit software FAIL writes seven-segment.
                if (store_word && dut.ALUResult == 32'hFFFF0080 &&
                    dut.WriteData_out !== 32'h600D600D) begin
                    $display("Software check failed: decimal ID=%0d hex=%08h", dut.WriteData_out, dut.WriteData_out);
                    $fatal(1, "See README failure ID list");
                end
            end

            if (RESET) begin
                ref_period = 0; ref_saved_period = 0; ref_enable = 0;
                ref_interval = 0; ref_ticks = 0; ref_event = 0;
                ref_mask = 0; ref_pending = 0;
                entries = 0; returns = 0; in_handler = 0; expected_epc = 0;
                masked_cycles = 0; irq_stall_cycles = 0; read_seen = 0; writes_seen = 0;
            end else begin
                // Pending is recorded regardless of whether the source is enabled.
                ref_pending = (ref_pending & ~ack_now) | {1'b0,ref_event};
                if (enable_now) ref_mask = dut.WriteData_out[1:0];
                if (config_now) begin
                    ref_saved_period = ref_period;
                    ref_enable = dut.WriteData_out[0];
                    ref_interval = 0; ref_event = 0;
                end else if (!ref_enable || ref_saved_period == 0) begin
                    ref_interval = 0; ref_event = 0;
                end else if (ref_interval == ref_saved_period - 1) begin
                    ref_interval = 0; ref_event = 1; ref_ticks = ref_ticks + 1;
                end else begin
                    ref_interval = ref_interval + 1; ref_event = 0;
                end
                if (period_now) ref_period = dut.WriteData_out;
            end
            #1;
            expect32(dut.TimerPeriod, ref_period, "Wrapper period storage");
            expect32(dut.TimerEvent, ref_event, "timer event timing");
            expect32(dut.TicksCounter, ref_ticks, "tick count and configuration preservation");
            expect32(dut.Pending, {30'd0,ref_pending}, "pending events and acknowledgement");
            expect32(dut.EnableMask, {30'd0,ref_mask}, "saved interrupt mask");
            expect32(dut.IRQ, |(ref_pending & ref_mask), "IRQ from enabled pending events");
            if (RESET) begin
                expect32(SEVENSEGHEX, 0, "seven-segment reset without a store");
                expect32(LED_OUT, 0, "LED reset");
            end else begin
                if (take_now) expect32(dut.PC, 32'h00400100, "PC redirects to actual handler address");
                if (return_now) begin
                    expect32(dut.PC, return_target, "PC resumes at saved address");
                    expect32(dut.RV1.ValidD, 0, "MRET flushes D validity");
                    expect32(dut.RV1.ValidE, 0, "MRET flushes E validity");
                end
            end
        end
    end

    task load_program;
        begin
            // Override simulation RAM after Wrapper's time-zero readmemh calls.
            // No source .mem file is changed on disk.
            for (i=0; i<2048; i=i+1) dut.IROM[i] = 32'h00000013;
            // Poison RAM so the software must initialize all locations it uses.
            for (i=0; i<128; i=i+1) dut.DMEM[i] = 32'hA5A5A5A5;
        dut.IROM[0] = 32'h2000006f; // 00400000 2000006f  jal x0, main
        dut.IROM[1] = 32'h00000013; // 00400004 00000013  addi x0, x0, 0
        dut.IROM[2] = 32'h00000013; // 00400008 00000013  addi x0, x0, 0
        dut.IROM[3] = 32'h00000013; // 0040000c 00000013  addi x0, x0, 0
        dut.IROM[4] = 32'h00000013; // 00400010 00000013  addi x0, x0, 0
        dut.IROM[5] = 32'h00000013; // 00400014 00000013  addi x0, x0, 0
        dut.IROM[6] = 32'h00000013; // 00400018 00000013  addi x0, x0, 0
        dut.IROM[7] = 32'h00000013; // 0040001c 00000013  addi x0, x0, 0
        dut.IROM[8] = 32'h00000013; // 00400020 00000013  addi x0, x0, 0
        dut.IROM[9] = 32'h00000013; // 00400024 00000013  addi x0, x0, 0
        dut.IROM[10] = 32'h00000013; // 00400028 00000013  addi x0, x0, 0
        dut.IROM[11] = 32'h00000013; // 0040002c 00000013  addi x0, x0, 0
        dut.IROM[12] = 32'h00000013; // 00400030 00000013  addi x0, x0, 0
        dut.IROM[13] = 32'h00000013; // 00400034 00000013  addi x0, x0, 0
        dut.IROM[14] = 32'h00000013; // 00400038 00000013  addi x0, x0, 0
        dut.IROM[15] = 32'h00000013; // 0040003c 00000013  addi x0, x0, 0
        dut.IROM[16] = 32'h00000013; // 00400040 00000013  addi x0, x0, 0
        dut.IROM[17] = 32'h00000013; // 00400044 00000013  addi x0, x0, 0
        dut.IROM[18] = 32'h00000013; // 00400048 00000013  addi x0, x0, 0
        dut.IROM[19] = 32'h00000013; // 0040004c 00000013  addi x0, x0, 0
        dut.IROM[20] = 32'h00000013; // 00400050 00000013  addi x0, x0, 0
        dut.IROM[21] = 32'h00000013; // 00400054 00000013  addi x0, x0, 0
        dut.IROM[22] = 32'h00000013; // 00400058 00000013  addi x0, x0, 0
        dut.IROM[23] = 32'h00000013; // 0040005c 00000013  addi x0, x0, 0
        dut.IROM[24] = 32'h00000013; // 00400060 00000013  addi x0, x0, 0
        dut.IROM[25] = 32'h00000013; // 00400064 00000013  addi x0, x0, 0
        dut.IROM[26] = 32'h00000013; // 00400068 00000013  addi x0, x0, 0
        dut.IROM[27] = 32'h00000013; // 0040006c 00000013  addi x0, x0, 0
        dut.IROM[28] = 32'h00000013; // 00400070 00000013  addi x0, x0, 0
        dut.IROM[29] = 32'h00000013; // 00400074 00000013  addi x0, x0, 0
        dut.IROM[30] = 32'h00000013; // 00400078 00000013  addi x0, x0, 0
        dut.IROM[31] = 32'h00000013; // 0040007c 00000013  addi x0, x0, 0
        dut.IROM[32] = 32'h00000013; // 00400080 00000013  addi x0, x0, 0
        dut.IROM[33] = 32'h00000013; // 00400084 00000013  addi x0, x0, 0
        dut.IROM[34] = 32'h00000013; // 00400088 00000013  addi x0, x0, 0
        dut.IROM[35] = 32'h00000013; // 0040008c 00000013  addi x0, x0, 0
        dut.IROM[36] = 32'h00000013; // 00400090 00000013  addi x0, x0, 0
        dut.IROM[37] = 32'h00000013; // 00400094 00000013  addi x0, x0, 0
        dut.IROM[38] = 32'h00000013; // 00400098 00000013  addi x0, x0, 0
        dut.IROM[39] = 32'h00000013; // 0040009c 00000013  addi x0, x0, 0
        dut.IROM[40] = 32'h00000013; // 004000a0 00000013  addi x0, x0, 0
        dut.IROM[41] = 32'h00000013; // 004000a4 00000013  addi x0, x0, 0
        dut.IROM[42] = 32'h00000013; // 004000a8 00000013  addi x0, x0, 0
        dut.IROM[43] = 32'h00000013; // 004000ac 00000013  addi x0, x0, 0
        dut.IROM[44] = 32'h00000013; // 004000b0 00000013  addi x0, x0, 0
        dut.IROM[45] = 32'h00000013; // 004000b4 00000013  addi x0, x0, 0
        dut.IROM[46] = 32'h00000013; // 004000b8 00000013  addi x0, x0, 0
        dut.IROM[47] = 32'h00000013; // 004000bc 00000013  addi x0, x0, 0
        dut.IROM[48] = 32'h00000013; // 004000c0 00000013  addi x0, x0, 0
        dut.IROM[49] = 32'h00000013; // 004000c4 00000013  addi x0, x0, 0
        dut.IROM[50] = 32'h00000013; // 004000c8 00000013  addi x0, x0, 0
        dut.IROM[51] = 32'h00000013; // 004000cc 00000013  addi x0, x0, 0
        dut.IROM[52] = 32'h00000013; // 004000d0 00000013  addi x0, x0, 0
        dut.IROM[53] = 32'h00000013; // 004000d4 00000013  addi x0, x0, 0
        dut.IROM[54] = 32'h00000013; // 004000d8 00000013  addi x0, x0, 0
        dut.IROM[55] = 32'h00000013; // 004000dc 00000013  addi x0, x0, 0
        dut.IROM[56] = 32'h00000013; // 004000e0 00000013  addi x0, x0, 0
        dut.IROM[57] = 32'h00000013; // 004000e4 00000013  addi x0, x0, 0
        dut.IROM[58] = 32'h00000013; // 004000e8 00000013  addi x0, x0, 0
        dut.IROM[59] = 32'h00000013; // 004000ec 00000013  addi x0, x0, 0
        dut.IROM[60] = 32'h00000013; // 004000f0 00000013  addi x0, x0, 0
        dut.IROM[61] = 32'h00000013; // 004000f4 00000013  addi x0, x0, 0
        dut.IROM[62] = 32'h00000013; // 004000f8 00000013  addi x0, x0, 0
        dut.IROM[63] = 32'h00000013; // 004000fc 00000013  addi x0, x0, 0
        dut.IROM[64] = 32'hff010113; // 00400100 ff010113  addi x2, x2, -16
        dut.IROM[65] = 32'h01412023; // 00400104 01412023  sw x20, 0(x2)
        dut.IROM[66] = 32'h01512223; // 00400108 01512223  sw x21, 4(x2)
        dut.IROM[67] = 32'h01712423; // 0040010c 01712423  sw x23, 8(x2)
        dut.IROM[68] = 32'h110faa03; // 00400110 110faa03  lw x20, 272(x31)
        dut.IROM[69] = 32'h001a7a93; // 00400114 001a7a93  andi x21, x20, 1
        dut.IROM[70] = 32'h040a8463; // 00400118 040a8463  beq x21, x0, handler_fail
        dut.IROM[71] = 32'h014f2223; // 0040011c 014f2223  sw x20, 4(x30)
        dut.IROM[72] = 32'h000f2a83; // 00400120 000f2a83  lw x21, 0(x30)
        dut.IROM[73] = 32'h001a8a93; // 00400124 001a8a93  addi x21, x21, 1
        dut.IROM[74] = 32'h015f2023; // 00400128 015f2023  sw x21, 0(x30)
        dut.IROM[75] = 32'h00400b93; // 0040012c 00400b93  addi x23, x0, 4
        dut.IROM[76] = 32'h017a9663; // 00400130 017a9663  bne x21, x23, ack
        dut.IROM[77] = 32'h100fa223; // 00400134 100fa223  sw x0, 260(x31)
        dut.IROM[78] = 32'h100fa623; // 00400138 100fa623  sw x0, 268(x31)
        dut.IROM[79] = 32'h00100b93; // 0040013c 00100b93  addi x23, x0, 1
        dut.IROM[80] = 32'h117faa23; // 00400140 117faa23  sw x23, 276(x31)
        dut.IROM[81] = 32'h00012a03; // 00400144 00012a03  lw x20, 0(x2)
        dut.IROM[82] = 32'h00412a83; // 00400148 00412a83  lw x21, 4(x2)
        dut.IROM[83] = 32'h00812b83; // 0040014c 00812b83  lw x23, 8(x2)
        dut.IROM[84] = 32'h01010113; // 00400150 01010113  addi x2, x2, 16
        dut.IROM[85] = 32'h30200073; // 00400154 30200073  mret
        dut.IROM[86] = 32'h06300d13; // 00400158 06300d13  addi x26, x0, 99
        dut.IROM[87] = 32'h2cc0006f; // 0040015c 2cc0006f  jal x0, fail
        dut.IROM[88] = 32'h06200d13; // 00400160 06200d13  addi x26, x0, 98
        dut.IROM[89] = 32'h2c40006f; // 00400164 2c40006f  jal x0, fail
        dut.IROM[90] = 32'h00000013; // 00400168 00000013  addi x0, x0, 0
        dut.IROM[91] = 32'h00000013; // 0040016c 00000013  addi x0, x0, 0
        dut.IROM[92] = 32'h00000013; // 00400170 00000013  addi x0, x0, 0
        dut.IROM[93] = 32'h00000013; // 00400174 00000013  addi x0, x0, 0
        dut.IROM[94] = 32'h00000013; // 00400178 00000013  addi x0, x0, 0
        dut.IROM[95] = 32'h00000013; // 0040017c 00000013  addi x0, x0, 0
        dut.IROM[96] = 32'h00000013; // 00400180 00000013  addi x0, x0, 0
        dut.IROM[97] = 32'h00000013; // 00400184 00000013  addi x0, x0, 0
        dut.IROM[98] = 32'h00000013; // 00400188 00000013  addi x0, x0, 0
        dut.IROM[99] = 32'h00000013; // 0040018c 00000013  addi x0, x0, 0
        dut.IROM[100] = 32'h00000013; // 00400190 00000013  addi x0, x0, 0
        dut.IROM[101] = 32'h00000013; // 00400194 00000013  addi x0, x0, 0
        dut.IROM[102] = 32'h00000013; // 00400198 00000013  addi x0, x0, 0
        dut.IROM[103] = 32'h00000013; // 0040019c 00000013  addi x0, x0, 0
        dut.IROM[104] = 32'h00000013; // 004001a0 00000013  addi x0, x0, 0
        dut.IROM[105] = 32'h00000013; // 004001a4 00000013  addi x0, x0, 0
        dut.IROM[106] = 32'h00000013; // 004001a8 00000013  addi x0, x0, 0
        dut.IROM[107] = 32'h00000013; // 004001ac 00000013  addi x0, x0, 0
        dut.IROM[108] = 32'h00000013; // 004001b0 00000013  addi x0, x0, 0
        dut.IROM[109] = 32'h00000013; // 004001b4 00000013  addi x0, x0, 0
        dut.IROM[110] = 32'h00000013; // 004001b8 00000013  addi x0, x0, 0
        dut.IROM[111] = 32'h00000013; // 004001bc 00000013  addi x0, x0, 0
        dut.IROM[112] = 32'h00000013; // 004001c0 00000013  addi x0, x0, 0
        dut.IROM[113] = 32'h00000013; // 004001c4 00000013  addi x0, x0, 0
        dut.IROM[114] = 32'h00000013; // 004001c8 00000013  addi x0, x0, 0
        dut.IROM[115] = 32'h00000013; // 004001cc 00000013  addi x0, x0, 0
        dut.IROM[116] = 32'h00000013; // 004001d0 00000013  addi x0, x0, 0
        dut.IROM[117] = 32'h00000013; // 004001d4 00000013  addi x0, x0, 0
        dut.IROM[118] = 32'h00000013; // 004001d8 00000013  addi x0, x0, 0
        dut.IROM[119] = 32'h00000013; // 004001dc 00000013  addi x0, x0, 0
        dut.IROM[120] = 32'h00000013; // 004001e0 00000013  addi x0, x0, 0
        dut.IROM[121] = 32'h00000013; // 004001e4 00000013  addi x0, x0, 0
        dut.IROM[122] = 32'h00000013; // 004001e8 00000013  addi x0, x0, 0
        dut.IROM[123] = 32'h00000013; // 004001ec 00000013  addi x0, x0, 0
        dut.IROM[124] = 32'h00000013; // 004001f0 00000013  addi x0, x0, 0
        dut.IROM[125] = 32'h00000013; // 004001f4 00000013  addi x0, x0, 0
        dut.IROM[126] = 32'h00000013; // 004001f8 00000013  addi x0, x0, 0
        dut.IROM[127] = 32'h00000013; // 004001fc 00000013  addi x0, x0, 0
        dut.IROM[128] = 32'hffff0fb7; // 00400200 ffff0fb7  lui x31, 0xffff0
        dut.IROM[129] = 32'h10010f37; // 00400204 10010f37  lui x30, 0x10010
        dut.IROM[130] = 32'h200f0113; // 00400208 200f0113  addi x2, x30, 512
        dut.IROM[131] = 32'h00000293; // 0040020c 00000293  addi x5, x0, 0
        dut.IROM[132] = 32'h00000313; // 00400210 00000313  addi x6, x0, 0
        dut.IROM[133] = 32'h00000393; // 00400214 00000393  addi x7, x0, 0
        dut.IROM[134] = 32'h00000413; // 00400218 00000413  addi x8, x0, 0
        dut.IROM[135] = 32'h00000493; // 0040021c 00000493  addi x9, x0, 0
        dut.IROM[136] = 32'h00000513; // 00400220 00000513  addi x10, x0, 0
        dut.IROM[137] = 32'h00000a13; // 00400224 00000a13  addi x20, x0, 0
        dut.IROM[138] = 32'h00000a93; // 00400228 00000a93  addi x21, x0, 0
        dut.IROM[139] = 32'h00000b13; // 0040022c 00000b13  addi x22, x0, 0
        dut.IROM[140] = 32'h00000b93; // 00400230 00000b93  addi x23, x0, 0
        dut.IROM[141] = 32'h00000d13; // 00400234 00000d13  addi x26, x0, 0
        dut.IROM[142] = 32'h00000d93; // 00400238 00000d93  addi x27, x0, 0
        dut.IROM[143] = 32'h000f2023; // 0040023c 000f2023  sw x0, 0(x30)
        dut.IROM[144] = 32'h000f2223; // 00400240 000f2223  sw x0, 4(x30)
        dut.IROM[145] = 32'h000f2423; // 00400244 000f2423  sw x0, 8(x30)
        dut.IROM[146] = 32'h10cfaa03; // 00400248 10cfaa03  lw x20, 268(x31)
        dut.IROM[147] = 32'h00100d13; // 0040024c 00100d13  addi x26, x0, 1
        dut.IROM[148] = 32'h00000d93; // 00400250 00000d93  addi x27, x0, 0
        dut.IROM[149] = 32'h1dba1a63; // 00400254 1dba1a63  bne x20, x27, fail
        dut.IROM[150] = 32'h110faa03; // 00400258 110faa03  lw x20, 272(x31)
        dut.IROM[151] = 32'h00200d13; // 0040025c 00200d13  addi x26, x0, 2
        dut.IROM[152] = 32'h00000d93; // 00400260 00000d93  addi x27, x0, 0
        dut.IROM[153] = 32'h1dba1263; // 00400264 1dba1263  bne x20, x27, fail
        dut.IROM[154] = 32'h108faa03; // 00400268 108faa03  lw x20, 264(x31)
        dut.IROM[155] = 32'h00300d13; // 0040026c 00300d13  addi x26, x0, 3
        dut.IROM[156] = 32'h00000d93; // 00400270 00000d93  addi x27, x0, 0
        dut.IROM[157] = 32'h1bba1a63; // 00400274 1bba1a63  bne x20, x27, fail
        dut.IROM[158] = 32'h01400a13; // 00400278 01400a13  addi x20, x0, 20
        dut.IROM[159] = 32'h114fa023; // 0040027c 114fa023  sw x20, 256(x31)
        dut.IROM[160] = 32'h100faa83; // 00400280 100faa83  lw x21, 256(x31)
        dut.IROM[161] = 32'h00400d13; // 00400284 00400d13  addi x26, x0, 4
        dut.IROM[162] = 32'h01400d93; // 00400288 01400d93  addi x27, x0, 20
        dut.IROM[163] = 32'h19ba9e63; // 0040028c 19ba9e63  bne x21, x27, fail
        dut.IROM[164] = 32'h00100a13; // 00400290 00100a13  addi x20, x0, 1
        dut.IROM[165] = 32'h114fa223; // 00400294 114fa223  sw x20, 260(x31)
        dut.IROM[166] = 32'h110faa83; // 00400298 110faa83  lw x21, 272(x31)
        dut.IROM[167] = 32'h001afa93; // 0040029c 001afa93  andi x21, x21, 1
        dut.IROM[168] = 32'hfe0a8ce3; // 004002a0 fe0a8ce3  beq x21, x0, masked_wait
        dut.IROM[169] = 32'h10cfaa83; // 004002a4 10cfaa83  lw x21, 268(x31)
        dut.IROM[170] = 32'h00500d13; // 004002a8 00500d13  addi x26, x0, 5
        dut.IROM[171] = 32'h00000d93; // 004002ac 00000d93  addi x27, x0, 0
        dut.IROM[172] = 32'h17ba9c63; // 004002b0 17ba9c63  bne x21, x27, fail
        dut.IROM[173] = 32'h100fa223; // 004002b4 100fa223  sw x0, 260(x31)
        dut.IROM[174] = 32'h00000013; // 004002b8 00000013  addi x0, x0, 0
        dut.IROM[175] = 32'h00000013; // 004002bc 00000013  addi x0, x0, 0
        dut.IROM[176] = 32'h00000013; // 004002c0 00000013  addi x0, x0, 0
        dut.IROM[177] = 32'h00000013; // 004002c4 00000013  addi x0, x0, 0
        dut.IROM[178] = 32'h00000013; // 004002c8 00000013  addi x0, x0, 0
        dut.IROM[179] = 32'h00000013; // 004002cc 00000013  addi x0, x0, 0
        dut.IROM[180] = 32'h00000013; // 004002d0 00000013  addi x0, x0, 0
        dut.IROM[181] = 32'h00000013; // 004002d4 00000013  addi x0, x0, 0
        dut.IROM[182] = 32'h00100a13; // 004002d8 00100a13  addi x20, x0, 1
        dut.IROM[183] = 32'h114faa23; // 004002dc 114faa23  sw x20, 276(x31)
        dut.IROM[184] = 32'h110faa83; // 004002e0 110faa83  lw x21, 272(x31)
        dut.IROM[185] = 32'h00600d13; // 004002e4 00600d13  addi x26, x0, 6
        dut.IROM[186] = 32'h00000d93; // 004002e8 00000d93  addi x27, x0, 0
        dut.IROM[187] = 32'h13ba9e63; // 004002ec 13ba9e63  bne x21, x27, fail
        dut.IROM[188] = 32'h108fab03; // 004002f0 108fab03  lw x22, 264(x31)
        dut.IROM[189] = 32'h00700d13; // 004002f4 00700d13  addi x26, x0, 7
        dut.IROM[190] = 32'h120b0863; // 004002f8 120b0863  beq x22, x0, fail
        dut.IROM[191] = 32'h19000a13; // 004002fc 19000a13  addi x20, x0, 400
        dut.IROM[192] = 32'h114fa023; // 00400300 114fa023  sw x20, 256(x31)
        dut.IROM[193] = 32'h100faa83; // 00400304 100faa83  lw x21, 256(x31)
        dut.IROM[194] = 32'h00800d13; // 00400308 00800d13  addi x26, x0, 8
        dut.IROM[195] = 32'h19000d93; // 0040030c 19000d93  addi x27, x0, 400
        dut.IROM[196] = 32'h11ba9c63; // 00400310 11ba9c63  bne x21, x27, fail
        dut.IROM[197] = 32'h108faa83; // 00400314 108faa83  lw x21, 264(x31)
        dut.IROM[198] = 32'h00900d13; // 00400318 00900d13  addi x26, x0, 9
        dut.IROM[199] = 32'h116a9663; // 0040031c 116a9663  bne x21, x22, fail
        dut.IROM[200] = 32'h00100a13; // 00400320 00100a13  addi x20, x0, 1
        dut.IROM[201] = 32'h114fa623; // 00400324 114fa623  sw x20, 268(x31)
        dut.IROM[202] = 32'h10cfaa83; // 00400328 10cfaa83  lw x21, 268(x31)
        dut.IROM[203] = 32'h00a00d13; // 0040032c 00a00d13  addi x26, x0, 10
        dut.IROM[204] = 32'h00100d93; // 00400330 00100d93  addi x27, x0, 1
        dut.IROM[205] = 32'h0fba9a63; // 00400334 0fba9a63  bne x21, x27, fail
        dut.IROM[206] = 32'h114fa223; // 00400338 114fa223  sw x20, 260(x31)
        dut.IROM[207] = 32'h07b00a13; // 0040033c 07b00a13  addi x20, x0, 123
        dut.IROM[208] = 32'h1c800a93; // 00400340 1c800a93  addi x21, x0, 456
        dut.IROM[209] = 32'h31500b93; // 00400344 31500b93  addi x23, x0, 789
        dut.IROM[210] = 32'h00100293; // 00400348 00100293  addi x5, x0, 1
        dut.IROM[211] = 32'h00000313; // 0040034c 00000313  addi x6, x0, 0
        dut.IROM[212] = 32'h02100393; // 00400350 02100393  addi x7, x0, 33
        dut.IROM[213] = 32'h00300413; // 00400354 00300413  addi x8, x0, 3
        dut.IROM[214] = 32'h028284b3; // 00400358 028284b3  mul x9, x5, x8
        dut.IROM[215] = 32'h0284d533; // 0040035c 0284d533  divu x10, x9, x8
        dut.IROM[216] = 32'h00b00d13; // 00400360 00b00d13  addi x26, x0, 11
        dut.IROM[217] = 32'h0c551263; // 00400364 0c551263  bne x10, x5, fail
        dut.IROM[218] = 32'h00a30333; // 00400368 00a30333  add x6, x6, x10
        dut.IROM[219] = 32'h00128293; // 0040036c 00128293  addi x5, x5, 1
        dut.IROM[220] = 32'hfe7294e3; // 00400370 fe7294e3  bne x5, x7, game_loop
        dut.IROM[221] = 32'h006f2423; // 00400374 006f2423  sw x6, 8(x30)
        dut.IROM[222] = 32'h000f2483; // 00400378 000f2483  lw x9, 0(x30)
        dut.IROM[223] = 32'h00400513; // 0040037c 00400513  addi x10, x0, 4
        dut.IROM[224] = 32'hfea4ece3; // 00400380 fea4ece3  bltu x9, x10, wait_four
        dut.IROM[225] = 32'h00c00d13; // 00400384 00c00d13  addi x26, x0, 12
        dut.IROM[226] = 32'h00400d93; // 00400388 00400d93  addi x27, x0, 4
        dut.IROM[227] = 32'h09b49e63; // 0040038c 09b49e63  bne x9, x27, fail
        dut.IROM[228] = 32'h00d00d13; // 00400390 00d00d13  addi x26, x0, 13
        dut.IROM[229] = 32'h21000d93; // 00400394 21000d93  addi x27, x0, 528
        dut.IROM[230] = 32'h09b31863; // 00400398 09b31863  bne x6, x27, fail
        dut.IROM[231] = 32'h00e00d13; // 0040039c 00e00d13  addi x26, x0, 14
        dut.IROM[232] = 32'h07b00d93; // 004003a0 07b00d93  addi x27, x0, 123
        dut.IROM[233] = 32'h09ba1263; // 004003a4 09ba1263  bne x20, x27, fail
        dut.IROM[234] = 32'h00f00d13; // 004003a8 00f00d13  addi x26, x0, 15
        dut.IROM[235] = 32'h1c800d93; // 004003ac 1c800d93  addi x27, x0, 456
        dut.IROM[236] = 32'h07ba9c63; // 004003b0 07ba9c63  bne x21, x27, fail
        dut.IROM[237] = 32'h01000d13; // 004003b4 01000d13  addi x26, x0, 16
        dut.IROM[238] = 32'h31500d93; // 004003b8 31500d93  addi x27, x0, 789
        dut.IROM[239] = 32'h07bb9663; // 004003bc 07bb9663  bne x23, x27, fail
        dut.IROM[240] = 32'h200f0513; // 004003c0 200f0513  addi x10, x30, 512
        dut.IROM[241] = 32'h01100d13; // 004003c4 01100d13  addi x26, x0, 17
        dut.IROM[242] = 32'h06a11063; // 004003c8 06a11063  bne x2, x10, fail
        dut.IROM[243] = 32'h004f2483; // 004003cc 004f2483  lw x9, 4(x30)
        dut.IROM[244] = 32'h01200d13; // 004003d0 01200d13  addi x26, x0, 18
        dut.IROM[245] = 32'h00100d93; // 004003d4 00100d93  addi x27, x0, 1
        dut.IROM[246] = 32'h05b49863; // 004003d8 05b49863  bne x9, x27, fail
        dut.IROM[247] = 32'h110fa483; // 004003dc 110fa483  lw x9, 272(x31)
        dut.IROM[248] = 32'h01300d13; // 004003e0 01300d13  addi x26, x0, 19
        dut.IROM[249] = 32'h00000d93; // 004003e4 00000d93  addi x27, x0, 0
        dut.IROM[250] = 32'h05b49063; // 004003e8 05b49063  bne x9, x27, fail
        dut.IROM[251] = 32'h10cfa483; // 004003ec 10cfa483  lw x9, 268(x31)
        dut.IROM[252] = 32'h01400d13; // 004003f0 01400d13  addi x26, x0, 20
        dut.IROM[253] = 32'h00000d93; // 004003f4 00000d93  addi x27, x0, 0
        dut.IROM[254] = 32'h03b49863; // 004003f8 03b49863  bne x9, x27, fail
        dut.IROM[255] = 32'h108fa483; // 004003fc 108fa483  lw x9, 264(x31)
        dut.IROM[256] = 32'h416484b3; // 00400400 416484b3  sub x9, x9, x22
        dut.IROM[257] = 32'h01500d13; // 00400404 01500d13  addi x26, x0, 21
        dut.IROM[258] = 32'h00400d93; // 00400408 00400d93  addi x27, x0, 4
        dut.IROM[259] = 32'h01b49e63; // 0040040c 01b49e63  bne x9, x27, fail
        dut.IROM[260] = 32'h00f00493; // 00400410 00f00493  addi x9, x0, 15
        dut.IROM[261] = 32'h069fa023; // 00400414 069fa023  sw x9, 96(x31)
        dut.IROM[262] = 32'h600d64b7; // 00400418 600d64b7  lui x9, 0x600d6
        dut.IROM[263] = 32'h00d48493; // 0040041c 00d48493  addi x9, x9, 13
        dut.IROM[264] = 32'h089fa023; // 00400420 089fa023  sw x9, 128(x31)
        dut.IROM[265] = 32'h0000006f; // 00400424 0000006f  jal x0, halt
        dut.IROM[266] = 32'h07afa023; // 00400428 07afa023  sw x26, 96(x31)
        dut.IROM[267] = 32'h09afa023; // 0040042c 09afa023  sw x26, 128(x31)
        dut.IROM[268] = 32'h0000006f; // 00400430 0000006f  jal x0, fail_halt
        end
    endtask

    initial begin
        #1;
        load_program;
        monitoring = 1;
        $display("Starting actual Wrapper timer/IRQ integration test");
        for (run_number=1; run_number<=2; run_number=run_number+1) begin
            // Assert/deassert away from rising edges to avoid stimulus races.
            @(negedge CLK); RESET = 1;
            repeat (4) @(negedge CLK);
            RESET = 0;
            elapsed = 0;
            while (SEVENSEGHEX !== 32'h600D600D && elapsed < 20000) begin
                @(negedge CLK);
                elapsed = elapsed + 1;
            end
            if (elapsed == 20000) begin
                $display("TIMEOUT: PC=%08h pending=%b mask=%b ticks=%0d entries=%0d returns=%0d",
                         dut.PC,dut.Pending,dut.EnableMask,dut.TicksCounter,entries,returns);
                $fatal(1, "Program failed to complete within 20000 CPU cycles");
            end
            expect32(LED_OUT, 32'h0F, "final LED signature");
            expect32(dut.DMEM[0], 4, "four game tick handlers completed");
            expect32(dut.DMEM[1], 1, "handler identified timer as source");
            expect32(dut.DMEM[2], 528, "foreground sum 1 through 32 survives interrupts");
            expect32(entries, 4, "exactly four entries");
            expect32(returns, 4, "exactly four returns");
            expect32(read_seen, 15, "all four readable registers exercised");
            expect32(writes_seen, 15, "all four writable registers exercised");
            expect32(masked_cycles > 0, 1, "masked event was observed pending");
            expect32(in_handler, 0, "foreground resumed after final return");
            final_ticks = dut.TicksCounter;
            repeat (40) @(negedge CLK);
            expect32(dut.TicksCounter, final_ticks, "stopped timer remains stopped");
            expect32(dut.Pending, 0, "no stale pending event after final acknowledgement");
            expect32(dut.IRQ, 0, "IRQ remains inactive after completion");
            expect32(entries, 4, "no repeated entry after completion");
            expect32(SEVENSEGHEX, 32'h600D600D, "PASS display remains stable");
            $display("RUN %0d PASS: cycles=%0d entries=%0d returns=%0d IRQ-and-MCycle-stall cycles=%0d",
                     run_number,elapsed,entries,returns,irq_stall_cycles);
        end
        $display("WRAPPER TIMER IRQ PASS: both runs passed; %0d checks", checks);
        $display("Expected: sevenseg=600d600d LEDs=0f RAM[0]=4 RAM[2]=528");
        $finish;
    end
    // Hard guard against an accidental infinite wait in the testbench itself.
    initial begin
        #500000;
        $fatal(1, "Global simulation timeout");
    end
endmodule
