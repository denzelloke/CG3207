`timescale 1ns / 1ps

// Simulation source only.
// Uses the existing button_irq_test assembly and its IROM/DMEM files.
// Drives physical button inputs; does not force IRQ or CPU signals.

module test_Wrapper_ButtonIRQ;

    reg CLK = 0;
    reg RESET = 1;
    reg [15:0] DIP = 0;
    reg [2:0] PB = 0;

    wire [7:0] LED_OUT;
    wire [6:0] LED_PC;
    wire [31:0] SEVENSEGHEX;
    wire [7:0] UART_TX;
    wire UART_TX_valid;
    wire UART_RX_ack;
    wire OLED_Write;
    wire [6:0] OLED_Col;
    wire [5:0] OLED_Row;
    wire [23:0] OLED_Data;

    // Must match the ButtonDebouncer instance inside Wrapper.
    localparam integer DEBOUNCE_CYCLES = 62500;

    // Allows time for synchronisation, interrupt servicing and LED updates.
    localparam integer SOFTWARE_WAIT = 1000;

    Wrapper dut (
        .DIP(DIP),
        .PB(PB),
        .LED_OUT(LED_OUT),
        .LED_PC(LED_PC),
        .SEVENSEGHEX(SEVENSEGHEX),
        .UART_TX(UART_TX),
        .UART_TX_ready(1'b1),
        .UART_TX_valid(UART_TX_valid),
        .UART_RX(8'd0),
        .UART_RX_valid(1'b0),
        .UART_RX_ack(UART_RX_ack),
        .OLED_Write(OLED_Write),
        .OLED_Col(OLED_Col),
        .OLED_Row(OLED_Row),
        .OLED_Data(OLED_Data),
        .ACCEL_Data(32'd0),
        .ACCEL_DReady(1'b0),
        .RESET(RESET),
        .CLK(CLK)
    );

    // CPU clock: 6.25 MHz, period = 160 ns.
    always #80 CLK = ~CLK;

    integer checks = 0;
    integer events = 0;
    integer entries = 0;
    integer returns = 0;

    // Reference model for the synchroniser and debouncer.
    reg [2:0] model_meta = 0;
    reg [2:0] model_sync = 0;
    reg model_down = 0;
    reg model_event = 0;
    integer model_count = 0;

    reg taken;
    reg returning;
    reg [31:0] saved_pc = 0;

    task check;
        input [31:0] actual;
        input [31:0] expected;
        input [8*100-1:0] message;
        begin
            checks = checks + 1;

            if (actual !== expected) begin
                $display(
                    "FAIL: %0s actual=%h expected=%h PC=%h time=%0t",
                    message, actual, expected, dut.PC, $time
                );
                $fatal(1, "Button debounce/IRQ test failed");
            end
        end
    endtask

    // Change inputs on falling edges, away from CPU sampling edges.
    task drive_buttons;
        input [2:0] value;
        input integer cycles;
        begin
            @(negedge CLK);
            PB = value;
            repeat (cycles) @(negedge CLK);
        end
    endtask

    // Wait for software to finish servicing an event.
    task check_count;
        input [31:0] expected;
        begin
            repeat (SOFTWARE_WAIT) @(negedge CLK);

            check(SEVENSEGHEX, expected, "seven-segment count");
            check(dut.DMEM[0], expected, "button count in RAM");
            check(dut.Pending, 0, "pending bits acknowledged");
            check(dut.IRQ, 0, "IRQ cleared");
            check(dut.ButtonEvent, 0, "event pulse has ended");

            // Each accepted press should cause exactly one complete ISR.
            check(events, expected, "accepted button events");
            check(entries, expected, "interrupt entries");
            check(returns, expected, "interrupt returns");
        end
    endtask

    task boot;
        integer timeout;
        begin
            @(negedge CLK);
            RESET = 1;
            PB = 0;

            repeat (5) @(negedge CLK);
            RESET = 0;

            // Wait for assembly to enable only the button interrupt.
            timeout = 0;
            while ((dut.EnableMask !== 2'b10) &&
                   (timeout < 3000)) begin
                @(negedge CLK);
                timeout = timeout + 1;
            end

            check(dut.EnableMask, 2, "software enables button interrupt");
            check_count(0);
            check(LED_OUT, 0, "buttons released after reset");
        end
    endtask

    // Check the sampled hardware behaviour every clock.
    always @(posedge CLK) begin
        // These are the requests that RV accepts at this clock edge.
        taken = dut.RV1.InterruptTaken;
        returning = dut.RV1.ReturnFromInterrupt;

        if (RESET) begin
            model_meta = 0;
            model_sync = 0;
            model_down = 0;
            model_event = 0;
            model_count = 0;

            events = 0;
            entries = 0;
            returns = 0;
            saved_pc = 0;
        end
        else begin
            // IC samples the event value from BEFORE this edge.
            if (dut.ButtonEvent)
                events = events + 1;

            if (taken) begin
                check(dut.RV1.PipelineEmpty, 1,
                      "interrupt entry waits for an empty pipeline");

                saved_pc = dut.PC;
                entries = entries + 1;
            end

            if (returning) begin
                check(dut.RV1.ReturnPC, saved_pc,
                      "MRET uses the saved resume address");

                returns = returns + 1;
            end

            // Debouncer sees the OLD synchroniser output at this edge.
            model_event = 0;

            if (model_sync[1] == model_down) begin
                model_count = 0;
            end
            else begin
                model_count = model_count + 1;

                if (model_count == DEBOUNCE_CYCLES) begin
                    model_down = model_sync[1];
                    model_event = model_sync[1];
                    model_count = 0;
                end
            end

            // Update the two synchroniser stages after using their old values.
            model_sync = model_meta;
            model_meta = PB;
        end

        // Wait for non-blocking assignments and combinational logic to settle.
        #1;

        check(dut.PB_sync, model_sync,
              "two-stage button synchroniser");
        check(dut.CentreButtonDown, model_down,
              "debounced centre-button level");
        check(dut.ButtonEvent, model_event,
              "event only after a qualified press");

        if (!RESET && taken)
            check(dut.PC, 32'h00400100, "redirect to interrupt handler");

        if (!RESET && returning)
            check(dut.PC, saved_pc, "return to interrupted program");
    end

    initial begin
        $display("Starting Wrapper button debounce and IRQ tests");

        // Check key instructions from the existing button-test program.
        // The testbench does not overwrite either memory.
        #2;
        check(dut.IROM[0], 32'h2000006f, "button-test startup jump");
        check(dut.IROM[64], 32'hff010113, "button-test handler");
        check(dut.IROM[79], 32'h30200073, "handler MRET");
        check(dut.IROM[128], 32'hffff0fb7, "button-test main");
        check(dut.IROM[139], 32'h068fa283, "button-read loop");
        check(dut.IROM[141], 32'hff9ff06f, "button-loop jump");

        boot;

        // ------------------------------------------------------------
        // 1. Left/right remain readable and do not generate button IRQs.
        // ------------------------------------------------------------
        drive_buttons(3'b100, SOFTWARE_WAIT);
        check(LED_OUT, 4, "left button readback");
        check_count(0);

        drive_buttons(3'b001, SOFTWARE_WAIT);
        check(LED_OUT, 1, "right button readback");
        check_count(0);

        drive_buttons(3'b000, SOFTWARE_WAIT);
        check(LED_OUT, 0, "left/right released");

        $display("PASS: left/right readback without centre IRQ");

        // ------------------------------------------------------------
        // 2. A short centre-button glitch must be ignored.
        // ------------------------------------------------------------
        drive_buttons(3'b010, DEBOUNCE_CYCLES / 4);

        check(dut.CentreButtonDown, 0, "short press not accepted");
        check(LED_OUT, 0, "short press not shown on LED1");

        drive_buttons(3'b000, SOFTWARE_WAIT);
        check_count(0);

        $display("PASS: short centre-button glitch rejected");

        // ------------------------------------------------------------
        // 3. Press bounce, followed by one stable press.
        // Each bouncing high period is shorter than the threshold.
        // ------------------------------------------------------------
        drive_buttons(3'b010, 100);
        drive_buttons(3'b000, 80);
        drive_buttons(3'b010, 400);
        drive_buttons(3'b000, 200);
        drive_buttons(3'b010, 1000);
        drive_buttons(3'b000, SOFTWARE_WAIT);
        check_count(0);

        drive_buttons(3'b010, DEBOUNCE_CYCLES + 4);
        check(dut.CentreButtonDown, 1, "stable press accepted");
        check_count(1);
        check(LED_OUT, 2, "debounced centre button readback");

        $display("PASS: bouncing press produces exactly one interrupt");

        // ------------------------------------------------------------
        // 4. Holding the button must not generate another event.
        // ------------------------------------------------------------
        drive_buttons(3'b010, DEBOUNCE_CYCLES + 4);
        check_count(1);

        $display("PASS: held button does not retrigger");

        // ------------------------------------------------------------
        // 5. Release bounce must not re-arm the button prematurely.
        // ------------------------------------------------------------
        drive_buttons(3'b000, 100);
        drive_buttons(3'b010, 80);
        drive_buttons(3'b000, 400);
        drive_buttons(3'b010, SOFTWARE_WAIT);

        check(dut.CentreButtonDown, 1,
              "short release bounce keeps button pressed");
        check_count(1);
        check(LED_OUT, 2, "release bounce keeps LED1 on");

        // A fully qualified release re-arms the next press.
        drive_buttons(3'b000, DEBOUNCE_CYCLES + 4);
        check(dut.CentreButtonDown, 0, "stable release accepted");
        check_count(1);
        check(LED_OUT, 0, "released centre button readback");

        $display("PASS: release bounce rejected; release generates no IRQ");

        // ------------------------------------------------------------
        // 6. Another real press must now be accepted.
        // ------------------------------------------------------------
        drive_buttons(3'b010, DEBOUNCE_CYCLES + 4);
        check_count(2);

        drive_buttons(3'b000, DEBOUNCE_CYCLES + 4);
        check_count(2);

        $display("PASS: second press accepted after stable release");

        // ------------------------------------------------------------
        // 7. All buttons together: only centre generates an IRQ.
        // ------------------------------------------------------------
        drive_buttons(3'b111, DEBOUNCE_CYCLES + 4);
        check_count(3);
        check(LED_OUT, 7, "all three buttons readback");

        drive_buttons(3'b000, DEBOUNCE_CYCLES + 4);
        check_count(3);
        check(LED_OUT, 0, "all buttons released");

        $display("PASS: simultaneous buttons produce one centre IRQ");

        // ------------------------------------------------------------
        // 8. Reset during an unfinished press clears debounce progress.
        // ------------------------------------------------------------
        drive_buttons(3'b010, DEBOUNCE_CYCLES / 2);
        check(dut.CentreButtonDown, 0, "partial press still unqualified");

        boot;

        // This half-length press must not inherit progress from before reset.
        drive_buttons(3'b010, DEBOUNCE_CYCLES / 2);
        drive_buttons(3'b000, SOFTWARE_WAIT);
        check_count(0);

        // A full new press must work after reset.
        drive_buttons(3'b010, DEBOUNCE_CYCLES + 4);
        check_count(1);

        drive_buttons(3'b000, DEBOUNCE_CYCLES + 4);
        check_count(1);

        $display("PASS: reset clears debounce progress and software count");

        $display("----------------------------------------------");
        $display("BUTTON DEBOUNCE / IRQ PASS: %0d checks", checks);
        $display("----------------------------------------------");
        $finish;
    end

    // 500 ms simulation timeout; longer than all intended test scenarios.
    initial begin
        #500000000;
        $fatal(1, "Global timeout: button debounce/IRQ test did not finish");
    end

endmodule