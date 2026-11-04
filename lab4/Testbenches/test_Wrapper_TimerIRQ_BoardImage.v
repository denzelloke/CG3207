`timescale 1ns / 1ps
// AI-assisted educational integration test for Giggs's CG3207 Lab 4 Wrapper.
// Uses the actual CPU and peripherals. No forced IRQ, bus, pending bits or PC.
// Wrapper loads AA_IROM.mem and AA_DMEM.mem itself; this bench checks the image.
// Use as SIMULATION SOURCE ONLY. See README before running.
module test_Wrapper_TimerIRQ_BoardImage;
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
    always #80 CLK = ~CLK; // 160 ns period = 6.25 MHz CPU clock

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

    task check_program;
        begin
            // Read-only checks: do not replace the memories loaded by Wrapper.
            expect32(dut.IROM[0], 32'h2000006f, "IROM word 0: correct board image");
            expect32(dut.IROM[1], 32'h00000013, "IROM word 1: correct board image");
            expect32(dut.IROM[2], 32'h00000013, "IROM word 2: correct board image");
            expect32(dut.IROM[3], 32'h00000013, "IROM word 3: correct board image");
            expect32(dut.IROM[4], 32'h00000013, "IROM word 4: correct board image");
            expect32(dut.IROM[5], 32'h00000013, "IROM word 5: correct board image");
            expect32(dut.IROM[6], 32'h00000013, "IROM word 6: correct board image");
            expect32(dut.IROM[7], 32'h00000013, "IROM word 7: correct board image");
            expect32(dut.IROM[8], 32'h00000013, "IROM word 8: correct board image");
            expect32(dut.IROM[9], 32'h00000013, "IROM word 9: correct board image");
            expect32(dut.IROM[10], 32'h00000013, "IROM word 10: correct board image");
            expect32(dut.IROM[11], 32'h00000013, "IROM word 11: correct board image");
            expect32(dut.IROM[12], 32'h00000013, "IROM word 12: correct board image");
            expect32(dut.IROM[13], 32'h00000013, "IROM word 13: correct board image");
            expect32(dut.IROM[14], 32'h00000013, "IROM word 14: correct board image");
            expect32(dut.IROM[15], 32'h00000013, "IROM word 15: correct board image");
            expect32(dut.IROM[16], 32'h00000013, "IROM word 16: correct board image");
            expect32(dut.IROM[17], 32'h00000013, "IROM word 17: correct board image");
            expect32(dut.IROM[18], 32'h00000013, "IROM word 18: correct board image");
            expect32(dut.IROM[19], 32'h00000013, "IROM word 19: correct board image");
            expect32(dut.IROM[20], 32'h00000013, "IROM word 20: correct board image");
            expect32(dut.IROM[21], 32'h00000013, "IROM word 21: correct board image");
            expect32(dut.IROM[22], 32'h00000013, "IROM word 22: correct board image");
            expect32(dut.IROM[23], 32'h00000013, "IROM word 23: correct board image");
            expect32(dut.IROM[24], 32'h00000013, "IROM word 24: correct board image");
            expect32(dut.IROM[25], 32'h00000013, "IROM word 25: correct board image");
            expect32(dut.IROM[26], 32'h00000013, "IROM word 26: correct board image");
            expect32(dut.IROM[27], 32'h00000013, "IROM word 27: correct board image");
            expect32(dut.IROM[28], 32'h00000013, "IROM word 28: correct board image");
            expect32(dut.IROM[29], 32'h00000013, "IROM word 29: correct board image");
            expect32(dut.IROM[30], 32'h00000013, "IROM word 30: correct board image");
            expect32(dut.IROM[31], 32'h00000013, "IROM word 31: correct board image");
            expect32(dut.IROM[32], 32'h00000013, "IROM word 32: correct board image");
            expect32(dut.IROM[33], 32'h00000013, "IROM word 33: correct board image");
            expect32(dut.IROM[34], 32'h00000013, "IROM word 34: correct board image");
            expect32(dut.IROM[35], 32'h00000013, "IROM word 35: correct board image");
            expect32(dut.IROM[36], 32'h00000013, "IROM word 36: correct board image");
            expect32(dut.IROM[37], 32'h00000013, "IROM word 37: correct board image");
            expect32(dut.IROM[38], 32'h00000013, "IROM word 38: correct board image");
            expect32(dut.IROM[39], 32'h00000013, "IROM word 39: correct board image");
            expect32(dut.IROM[40], 32'h00000013, "IROM word 40: correct board image");
            expect32(dut.IROM[41], 32'h00000013, "IROM word 41: correct board image");
            expect32(dut.IROM[42], 32'h00000013, "IROM word 42: correct board image");
            expect32(dut.IROM[43], 32'h00000013, "IROM word 43: correct board image");
            expect32(dut.IROM[44], 32'h00000013, "IROM word 44: correct board image");
            expect32(dut.IROM[45], 32'h00000013, "IROM word 45: correct board image");
            expect32(dut.IROM[46], 32'h00000013, "IROM word 46: correct board image");
            expect32(dut.IROM[47], 32'h00000013, "IROM word 47: correct board image");
            expect32(dut.IROM[48], 32'h00000013, "IROM word 48: correct board image");
            expect32(dut.IROM[49], 32'h00000013, "IROM word 49: correct board image");
            expect32(dut.IROM[50], 32'h00000013, "IROM word 50: correct board image");
            expect32(dut.IROM[51], 32'h00000013, "IROM word 51: correct board image");
            expect32(dut.IROM[52], 32'h00000013, "IROM word 52: correct board image");
            expect32(dut.IROM[53], 32'h00000013, "IROM word 53: correct board image");
            expect32(dut.IROM[54], 32'h00000013, "IROM word 54: correct board image");
            expect32(dut.IROM[55], 32'h00000013, "IROM word 55: correct board image");
            expect32(dut.IROM[56], 32'h00000013, "IROM word 56: correct board image");
            expect32(dut.IROM[57], 32'h00000013, "IROM word 57: correct board image");
            expect32(dut.IROM[58], 32'h00000013, "IROM word 58: correct board image");
            expect32(dut.IROM[59], 32'h00000013, "IROM word 59: correct board image");
            expect32(dut.IROM[60], 32'h00000013, "IROM word 60: correct board image");
            expect32(dut.IROM[61], 32'h00000013, "IROM word 61: correct board image");
            expect32(dut.IROM[62], 32'h00000013, "IROM word 62: correct board image");
            expect32(dut.IROM[63], 32'h00000013, "IROM word 63: correct board image");
            expect32(dut.IROM[64], 32'hff010113, "IROM word 64: correct board image");
            expect32(dut.IROM[65], 32'h01412023, "IROM word 65: correct board image");
            expect32(dut.IROM[66], 32'h01512223, "IROM word 66: correct board image");
            expect32(dut.IROM[67], 32'h01712423, "IROM word 67: correct board image");
            expect32(dut.IROM[68], 32'h110faa03, "IROM word 68: correct board image");
            expect32(dut.IROM[69], 32'h001a7a93, "IROM word 69: correct board image");
            expect32(dut.IROM[70], 32'h040a8463, "IROM word 70: correct board image");
            expect32(dut.IROM[71], 32'h014f2223, "IROM word 71: correct board image");
            expect32(dut.IROM[72], 32'h000f2a83, "IROM word 72: correct board image");
            expect32(dut.IROM[73], 32'h001a8a93, "IROM word 73: correct board image");
            expect32(dut.IROM[74], 32'h015f2023, "IROM word 74: correct board image");
            expect32(dut.IROM[75], 32'h00400b93, "IROM word 75: correct board image");
            expect32(dut.IROM[76], 32'h017a9663, "IROM word 76: correct board image");
            expect32(dut.IROM[77], 32'h100fa223, "IROM word 77: correct board image");
            expect32(dut.IROM[78], 32'h100fa623, "IROM word 78: correct board image");
            expect32(dut.IROM[79], 32'h00100b93, "IROM word 79: correct board image");
            expect32(dut.IROM[80], 32'h117faa23, "IROM word 80: correct board image");
            expect32(dut.IROM[81], 32'h00012a03, "IROM word 81: correct board image");
            expect32(dut.IROM[82], 32'h00412a83, "IROM word 82: correct board image");
            expect32(dut.IROM[83], 32'h00812b83, "IROM word 83: correct board image");
            expect32(dut.IROM[84], 32'h01010113, "IROM word 84: correct board image");
            expect32(dut.IROM[85], 32'h30200073, "IROM word 85: correct board image");
            expect32(dut.IROM[86], 32'h06300d13, "IROM word 86: correct board image");
            expect32(dut.IROM[87], 32'h2cc0006f, "IROM word 87: correct board image");
            expect32(dut.IROM[88], 32'h06200d13, "IROM word 88: correct board image");
            expect32(dut.IROM[89], 32'h2c40006f, "IROM word 89: correct board image");
            expect32(dut.IROM[90], 32'h00000013, "IROM word 90: correct board image");
            expect32(dut.IROM[91], 32'h00000013, "IROM word 91: correct board image");
            expect32(dut.IROM[92], 32'h00000013, "IROM word 92: correct board image");
            expect32(dut.IROM[93], 32'h00000013, "IROM word 93: correct board image");
            expect32(dut.IROM[94], 32'h00000013, "IROM word 94: correct board image");
            expect32(dut.IROM[95], 32'h00000013, "IROM word 95: correct board image");
            expect32(dut.IROM[96], 32'h00000013, "IROM word 96: correct board image");
            expect32(dut.IROM[97], 32'h00000013, "IROM word 97: correct board image");
            expect32(dut.IROM[98], 32'h00000013, "IROM word 98: correct board image");
            expect32(dut.IROM[99], 32'h00000013, "IROM word 99: correct board image");
            expect32(dut.IROM[100], 32'h00000013, "IROM word 100: correct board image");
            expect32(dut.IROM[101], 32'h00000013, "IROM word 101: correct board image");
            expect32(dut.IROM[102], 32'h00000013, "IROM word 102: correct board image");
            expect32(dut.IROM[103], 32'h00000013, "IROM word 103: correct board image");
            expect32(dut.IROM[104], 32'h00000013, "IROM word 104: correct board image");
            expect32(dut.IROM[105], 32'h00000013, "IROM word 105: correct board image");
            expect32(dut.IROM[106], 32'h00000013, "IROM word 106: correct board image");
            expect32(dut.IROM[107], 32'h00000013, "IROM word 107: correct board image");
            expect32(dut.IROM[108], 32'h00000013, "IROM word 108: correct board image");
            expect32(dut.IROM[109], 32'h00000013, "IROM word 109: correct board image");
            expect32(dut.IROM[110], 32'h00000013, "IROM word 110: correct board image");
            expect32(dut.IROM[111], 32'h00000013, "IROM word 111: correct board image");
            expect32(dut.IROM[112], 32'h00000013, "IROM word 112: correct board image");
            expect32(dut.IROM[113], 32'h00000013, "IROM word 113: correct board image");
            expect32(dut.IROM[114], 32'h00000013, "IROM word 114: correct board image");
            expect32(dut.IROM[115], 32'h00000013, "IROM word 115: correct board image");
            expect32(dut.IROM[116], 32'h00000013, "IROM word 116: correct board image");
            expect32(dut.IROM[117], 32'h00000013, "IROM word 117: correct board image");
            expect32(dut.IROM[118], 32'h00000013, "IROM word 118: correct board image");
            expect32(dut.IROM[119], 32'h00000013, "IROM word 119: correct board image");
            expect32(dut.IROM[120], 32'h00000013, "IROM word 120: correct board image");
            expect32(dut.IROM[121], 32'h00000013, "IROM word 121: correct board image");
            expect32(dut.IROM[122], 32'h00000013, "IROM word 122: correct board image");
            expect32(dut.IROM[123], 32'h00000013, "IROM word 123: correct board image");
            expect32(dut.IROM[124], 32'h00000013, "IROM word 124: correct board image");
            expect32(dut.IROM[125], 32'h00000013, "IROM word 125: correct board image");
            expect32(dut.IROM[126], 32'h00000013, "IROM word 126: correct board image");
            expect32(dut.IROM[127], 32'h00000013, "IROM word 127: correct board image");
            expect32(dut.IROM[128], 32'hffff0fb7, "IROM word 128: correct board image");
            expect32(dut.IROM[129], 32'h10010f37, "IROM word 129: correct board image");
            expect32(dut.IROM[130], 32'h200f0113, "IROM word 130: correct board image");
            expect32(dut.IROM[131], 32'h00000293, "IROM word 131: correct board image");
            expect32(dut.IROM[132], 32'h00000313, "IROM word 132: correct board image");
            expect32(dut.IROM[133], 32'h00000393, "IROM word 133: correct board image");
            expect32(dut.IROM[134], 32'h00000413, "IROM word 134: correct board image");
            expect32(dut.IROM[135], 32'h00000493, "IROM word 135: correct board image");
            expect32(dut.IROM[136], 32'h00000513, "IROM word 136: correct board image");
            expect32(dut.IROM[137], 32'h00000a13, "IROM word 137: correct board image");
            expect32(dut.IROM[138], 32'h00000a93, "IROM word 138: correct board image");
            expect32(dut.IROM[139], 32'h00000b13, "IROM word 139: correct board image");
            expect32(dut.IROM[140], 32'h00000b93, "IROM word 140: correct board image");
            expect32(dut.IROM[141], 32'h00000d13, "IROM word 141: correct board image");
            expect32(dut.IROM[142], 32'h00000d93, "IROM word 142: correct board image");
            expect32(dut.IROM[143], 32'h000f2023, "IROM word 143: correct board image");
            expect32(dut.IROM[144], 32'h000f2223, "IROM word 144: correct board image");
            expect32(dut.IROM[145], 32'h000f2423, "IROM word 145: correct board image");
            expect32(dut.IROM[146], 32'h10cfaa03, "IROM word 146: correct board image");
            expect32(dut.IROM[147], 32'h00100d13, "IROM word 147: correct board image");
            expect32(dut.IROM[148], 32'h00000d93, "IROM word 148: correct board image");
            expect32(dut.IROM[149], 32'h1dba1a63, "IROM word 149: correct board image");
            expect32(dut.IROM[150], 32'h110faa03, "IROM word 150: correct board image");
            expect32(dut.IROM[151], 32'h00200d13, "IROM word 151: correct board image");
            expect32(dut.IROM[152], 32'h00000d93, "IROM word 152: correct board image");
            expect32(dut.IROM[153], 32'h1dba1263, "IROM word 153: correct board image");
            expect32(dut.IROM[154], 32'h108faa03, "IROM word 154: correct board image");
            expect32(dut.IROM[155], 32'h00300d13, "IROM word 155: correct board image");
            expect32(dut.IROM[156], 32'h00000d93, "IROM word 156: correct board image");
            expect32(dut.IROM[157], 32'h1bba1a63, "IROM word 157: correct board image");
            expect32(dut.IROM[158], 32'h01400a13, "IROM word 158: correct board image");
            expect32(dut.IROM[159], 32'h114fa023, "IROM word 159: correct board image");
            expect32(dut.IROM[160], 32'h100faa83, "IROM word 160: correct board image");
            expect32(dut.IROM[161], 32'h00400d13, "IROM word 161: correct board image");
            expect32(dut.IROM[162], 32'h01400d93, "IROM word 162: correct board image");
            expect32(dut.IROM[163], 32'h19ba9e63, "IROM word 163: correct board image");
            expect32(dut.IROM[164], 32'h00100a13, "IROM word 164: correct board image");
            expect32(dut.IROM[165], 32'h114fa223, "IROM word 165: correct board image");
            expect32(dut.IROM[166], 32'h110faa83, "IROM word 166: correct board image");
            expect32(dut.IROM[167], 32'h001afa93, "IROM word 167: correct board image");
            expect32(dut.IROM[168], 32'hfe0a8ce3, "IROM word 168: correct board image");
            expect32(dut.IROM[169], 32'h10cfaa83, "IROM word 169: correct board image");
            expect32(dut.IROM[170], 32'h00500d13, "IROM word 170: correct board image");
            expect32(dut.IROM[171], 32'h00000d93, "IROM word 171: correct board image");
            expect32(dut.IROM[172], 32'h17ba9c63, "IROM word 172: correct board image");
            expect32(dut.IROM[173], 32'h100fa223, "IROM word 173: correct board image");
            expect32(dut.IROM[174], 32'h00000013, "IROM word 174: correct board image");
            expect32(dut.IROM[175], 32'h00000013, "IROM word 175: correct board image");
            expect32(dut.IROM[176], 32'h00000013, "IROM word 176: correct board image");
            expect32(dut.IROM[177], 32'h00000013, "IROM word 177: correct board image");
            expect32(dut.IROM[178], 32'h00000013, "IROM word 178: correct board image");
            expect32(dut.IROM[179], 32'h00000013, "IROM word 179: correct board image");
            expect32(dut.IROM[180], 32'h00000013, "IROM word 180: correct board image");
            expect32(dut.IROM[181], 32'h00000013, "IROM word 181: correct board image");
            expect32(dut.IROM[182], 32'h00100a13, "IROM word 182: correct board image");
            expect32(dut.IROM[183], 32'h114faa23, "IROM word 183: correct board image");
            expect32(dut.IROM[184], 32'h110faa83, "IROM word 184: correct board image");
            expect32(dut.IROM[185], 32'h00600d13, "IROM word 185: correct board image");
            expect32(dut.IROM[186], 32'h00000d93, "IROM word 186: correct board image");
            expect32(dut.IROM[187], 32'h13ba9e63, "IROM word 187: correct board image");
            expect32(dut.IROM[188], 32'h108fab03, "IROM word 188: correct board image");
            expect32(dut.IROM[189], 32'h00700d13, "IROM word 189: correct board image");
            expect32(dut.IROM[190], 32'h120b0863, "IROM word 190: correct board image");
            expect32(dut.IROM[191], 32'h19000a13, "IROM word 191: correct board image");
            expect32(dut.IROM[192], 32'h114fa023, "IROM word 192: correct board image");
            expect32(dut.IROM[193], 32'h100faa83, "IROM word 193: correct board image");
            expect32(dut.IROM[194], 32'h00800d13, "IROM word 194: correct board image");
            expect32(dut.IROM[195], 32'h19000d93, "IROM word 195: correct board image");
            expect32(dut.IROM[196], 32'h11ba9c63, "IROM word 196: correct board image");
            expect32(dut.IROM[197], 32'h108faa83, "IROM word 197: correct board image");
            expect32(dut.IROM[198], 32'h00900d13, "IROM word 198: correct board image");
            expect32(dut.IROM[199], 32'h116a9663, "IROM word 199: correct board image");
            expect32(dut.IROM[200], 32'h00100a13, "IROM word 200: correct board image");
            expect32(dut.IROM[201], 32'h114fa623, "IROM word 201: correct board image");
            expect32(dut.IROM[202], 32'h10cfaa83, "IROM word 202: correct board image");
            expect32(dut.IROM[203], 32'h00a00d13, "IROM word 203: correct board image");
            expect32(dut.IROM[204], 32'h00100d93, "IROM word 204: correct board image");
            expect32(dut.IROM[205], 32'h0fba9a63, "IROM word 205: correct board image");
            expect32(dut.IROM[206], 32'h114fa223, "IROM word 206: correct board image");
            expect32(dut.IROM[207], 32'h07b00a13, "IROM word 207: correct board image");
            expect32(dut.IROM[208], 32'h1c800a93, "IROM word 208: correct board image");
            expect32(dut.IROM[209], 32'h31500b93, "IROM word 209: correct board image");
            expect32(dut.IROM[210], 32'h00100293, "IROM word 210: correct board image");
            expect32(dut.IROM[211], 32'h00000313, "IROM word 211: correct board image");
            expect32(dut.IROM[212], 32'h02100393, "IROM word 212: correct board image");
            expect32(dut.IROM[213], 32'h00300413, "IROM word 213: correct board image");
            expect32(dut.IROM[214], 32'h028284b3, "IROM word 214: correct board image");
            expect32(dut.IROM[215], 32'h0284d533, "IROM word 215: correct board image");
            expect32(dut.IROM[216], 32'h00b00d13, "IROM word 216: correct board image");
            expect32(dut.IROM[217], 32'h0c551263, "IROM word 217: correct board image");
            expect32(dut.IROM[218], 32'h00a30333, "IROM word 218: correct board image");
            expect32(dut.IROM[219], 32'h00128293, "IROM word 219: correct board image");
            expect32(dut.IROM[220], 32'hfe7294e3, "IROM word 220: correct board image");
            expect32(dut.IROM[221], 32'h006f2423, "IROM word 221: correct board image");
            expect32(dut.IROM[222], 32'h000f2483, "IROM word 222: correct board image");
            expect32(dut.IROM[223], 32'h00400513, "IROM word 223: correct board image");
            expect32(dut.IROM[224], 32'hfea4ece3, "IROM word 224: correct board image");
            expect32(dut.IROM[225], 32'h00c00d13, "IROM word 225: correct board image");
            expect32(dut.IROM[226], 32'h00400d93, "IROM word 226: correct board image");
            expect32(dut.IROM[227], 32'h09b49e63, "IROM word 227: correct board image");
            expect32(dut.IROM[228], 32'h00d00d13, "IROM word 228: correct board image");
            expect32(dut.IROM[229], 32'h21000d93, "IROM word 229: correct board image");
            expect32(dut.IROM[230], 32'h09b31863, "IROM word 230: correct board image");
            expect32(dut.IROM[231], 32'h00e00d13, "IROM word 231: correct board image");
            expect32(dut.IROM[232], 32'h07b00d93, "IROM word 232: correct board image");
            expect32(dut.IROM[233], 32'h09ba1263, "IROM word 233: correct board image");
            expect32(dut.IROM[234], 32'h00f00d13, "IROM word 234: correct board image");
            expect32(dut.IROM[235], 32'h1c800d93, "IROM word 235: correct board image");
            expect32(dut.IROM[236], 32'h07ba9c63, "IROM word 236: correct board image");
            expect32(dut.IROM[237], 32'h01000d13, "IROM word 237: correct board image");
            expect32(dut.IROM[238], 32'h31500d93, "IROM word 238: correct board image");
            expect32(dut.IROM[239], 32'h07bb9663, "IROM word 239: correct board image");
            expect32(dut.IROM[240], 32'h200f0513, "IROM word 240: correct board image");
            expect32(dut.IROM[241], 32'h01100d13, "IROM word 241: correct board image");
            expect32(dut.IROM[242], 32'h06a11063, "IROM word 242: correct board image");
            expect32(dut.IROM[243], 32'h004f2483, "IROM word 243: correct board image");
            expect32(dut.IROM[244], 32'h01200d13, "IROM word 244: correct board image");
            expect32(dut.IROM[245], 32'h00100d93, "IROM word 245: correct board image");
            expect32(dut.IROM[246], 32'h05b49863, "IROM word 246: correct board image");
            expect32(dut.IROM[247], 32'h110fa483, "IROM word 247: correct board image");
            expect32(dut.IROM[248], 32'h01300d13, "IROM word 248: correct board image");
            expect32(dut.IROM[249], 32'h00000d93, "IROM word 249: correct board image");
            expect32(dut.IROM[250], 32'h05b49063, "IROM word 250: correct board image");
            expect32(dut.IROM[251], 32'h10cfa483, "IROM word 251: correct board image");
            expect32(dut.IROM[252], 32'h01400d13, "IROM word 252: correct board image");
            expect32(dut.IROM[253], 32'h00000d93, "IROM word 253: correct board image");
            expect32(dut.IROM[254], 32'h03b49863, "IROM word 254: correct board image");
            expect32(dut.IROM[255], 32'h108fa483, "IROM word 255: correct board image");
            expect32(dut.IROM[256], 32'h416484b3, "IROM word 256: correct board image");
            expect32(dut.IROM[257], 32'h01500d13, "IROM word 257: correct board image");
            expect32(dut.IROM[258], 32'h00400d93, "IROM word 258: correct board image");
            expect32(dut.IROM[259], 32'h01b49e63, "IROM word 259: correct board image");
            expect32(dut.IROM[260], 32'h00f00493, "IROM word 260: correct board image");
            expect32(dut.IROM[261], 32'h069fa023, "IROM word 261: correct board image");
            expect32(dut.IROM[262], 32'h600d64b7, "IROM word 262: correct board image");
            expect32(dut.IROM[263], 32'h00d48493, "IROM word 263: correct board image");
            expect32(dut.IROM[264], 32'h089fa023, "IROM word 264: correct board image");
            expect32(dut.IROM[265], 32'h0000006f, "IROM word 265: correct board image");
            expect32(dut.IROM[266], 32'h07afa023, "IROM word 266: correct board image");
            expect32(dut.IROM[267], 32'h09afa023, "IROM word 267: correct board image");
            expect32(dut.IROM[268], 32'h0000006f, "IROM word 268: correct board image");
            for (i=269; i<2048; i=i+1)
                expect32(dut.IROM[i], 32'h00000013, "IROM unused words are NOPs");
            for (i=0; i<128; i=i+1)
                expect32(dut.DMEM[i], 0, "initial DMEM matches board image");
        end
    endtask

    initial begin
        #1;
        check_program;
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
        #8000000; // 8 ms: longer than two 20,000-cycle timeouts
        $fatal(1, "Global simulation timeout");
    end
endmodule
