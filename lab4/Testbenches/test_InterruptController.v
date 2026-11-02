`timescale 1ns / 1ps

module test_InterruptController;

    reg CLK = 0;
    reg RESET = 0;
    reg TimerEvent = 0;
    reg ButtonEvent = 0;
    reg LoadEnableMask = 0;
    reg [1:0] EnableMaskIn = 0;
    reg [1:0] ACK = 0;

    wire [1:0] Pending;
    wire [1:0] EnableMask;
    wire IRQ;

    integer errors = 0;
    integer checks = 0;

    InterruptController dut (
        .CLK(CLK),
        .RESET(RESET),
        .TimerEvent(TimerEvent),
        .ButtonEvent(ButtonEvent),
        .LoadEnableMask(LoadEnableMask),
        .EnableMaskIn(EnableMaskIn),
        .ACK(ACK),
        .Pending(Pending),
        .EnableMask(EnableMask),
        .IRQ(IRQ)
    );

    always #5 CLK = ~CLK;

    // Apply inputs for one cycle, then check the saved state and IRQ.
    // Event vector: bit 1 = button, bit 0 = timer.
    task step;
        input reset_value;
        input [1:0] events;
        input load_mask;
        input [1:0] mask_value;
        input [1:0] ack_value;
        input [1:0] expected_pending;
        input [1:0] expected_mask;
        input expected_irq;
        begin
            @(negedge CLK);
            RESET = reset_value;
            {ButtonEvent, TimerEvent} = events;
            LoadEnableMask = load_mask;
            EnableMaskIn = mask_value;
            ACK = ack_value;

            @(posedge CLK);
            #1;
            checks = checks + 1;

            if ((Pending !== expected_pending) ||
                (EnableMask !== expected_mask) ||
                (IRQ !== expected_irq)) begin
                errors = errors + 1;
                $display(
                    "FAIL check %0d: Pending=%b/%b Mask=%b/%b IRQ=%b/%b",
                    checks, Pending, expected_pending,
                    EnableMask, expected_mask, IRQ, expected_irq
                );
            end
        end
    endtask

    initial begin
        $display("Starting InterruptController tests");

        // reset, events, load, mask, ACK, expected Pending, Mask, IRQ

        // Reset wins even if events and a configuration write occur.
        step(1, 2'b11, 1, 2'b11, 2'b00, 2'b00, 2'b00, 0);

        // Timer event is remembered while interrupts are disabled.
        step(0, 2'b01, 0, 2'b00, 2'b00, 2'b01, 2'b00, 0);

        // Pending event persists after its input pulse disappears.
        step(0, 2'b00, 0, 2'b00, 2'b00, 2'b01, 2'b00, 0);

        // Enabling the timer now raises IRQ for the saved event.
        step(0, 2'b00, 1, 2'b01, 2'b00, 2'b01, 2'b01, 1);

        // Button event must not erase the pending timer event.
        step(0, 2'b10, 0, 2'b00, 2'b00, 2'b11, 2'b01, 1);

        // ACK timer only: disabled button remains pending, IRQ falls.
        step(0, 2'b00, 0, 2'b00, 2'b01, 2'b10, 2'b01, 0);

        // Enable button; its saved event raises IRQ.
        step(0, 2'b00, 1, 2'b10, 2'b00, 2'b10, 2'b10, 1);

        // ACK button: clear the final pending event.
        step(0, 2'b00, 0, 2'b00, 2'b10, 2'b00, 2'b10, 0);

        // ACK an already-clear bit: must not create an event.
        step(0, 2'b00, 0, 2'b00, 2'b11, 2'b00, 2'b10, 0);

        // Enable both and receive both events.
        step(0, 2'b11, 1, 2'b11, 2'b00, 2'b11, 2'b11, 1);

        // ACK both, but a new timer event arrives: timer stays pending.
        step(0, 2'b01, 0, 2'b00, 2'b11, 2'b01, 2'b11, 1);

        // Repeated timer events still represent one pending source.
        step(0, 2'b01, 0, 2'b00, 2'b00, 2'b01, 2'b11, 1);

        // Disabling interrupts does not discard pending events.
        step(0, 2'b00, 1, 2'b00, 2'b00, 2'b01, 2'b00, 0);

        // EnableMaskIn alone must not change the saved mask.
        step(0, 2'b00, 0, 2'b11, 2'b00, 2'b01, 2'b00, 0);

        // Reset clears both saved registers.
        step(1, 2'b00, 0, 2'b00, 2'b00, 2'b00, 2'b00, 0);

        if (errors == 0)
            $display("INTERRUPT CONTROLLER PASS: all %0d checks passed",
                     checks);
        else
            $display("INTERRUPT CONTROLLER FAIL: %0d errors", errors);

        $finish;
    end

    initial begin
        #10000;
        $display("FAIL: InterruptController test timed out");
        $finish;
    end

endmodule