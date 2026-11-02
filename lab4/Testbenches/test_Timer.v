`timescale 1ns / 1ps

module test_Timer;

    reg CLK = 0;
    reg RESET = 0;
    reg ConfigureWritePulse = 0;
    reg [31:0] Period = 0;
    reg Enable = 0;

    wire TimerEvent;
    wire [31:0] TicksCounter;

    integer errors = 0;
    integer checks = 0;

    Timer dut (
        .CLK(CLK),
        .RESET(RESET),
        .ConfigureWritePulse(ConfigureWritePulse),
        .Period(Period),
        .Enable(Enable),
        .TimerEvent(TimerEvent),
        .TicksCounter(TicksCounter)
    );

    always #5 CLK = ~CLK;

    // Wait for one rising edge and check the resulting outputs.
    task check_cycle;
        input expected_event;
        input [31:0] expected_ticks;
        begin
            @(posedge CLK);
            #1;
            checks = checks + 1;

            if ((TimerEvent !== expected_event) ||
                (TicksCounter !== expected_ticks)) begin
                errors = errors + 1;
                $display(
                    "FAIL at %0t: event=%b expected=%b, ticks=%0d expected=%0d",
                    $time, TimerEvent, expected_event,
                    TicksCounter, expected_ticks
                );
            end
        end
    endtask

    // Load new settings for exactly one rising edge.
    task configure;
        input [31:0] new_period;
        input new_enable;
        input [31:0] expected_ticks;
        begin
            @(negedge CLK);
            Period = new_period;
            Enable = new_enable;
            ConfigureWritePulse = 1;

            // Loading settings restarts the interval, without adding a tick.
            check_cycle(0, expected_ticks);

            @(negedge CLK);
            ConfigureWritePulse = 0;
        end
    endtask

    initial begin
        $display("Starting Timer tests");

        // Reset disables the timer and clears its tick count.
        RESET = 1;
        check_cycle(0, 0);
        @(negedge CLK);
        RESET = 0;

        repeat (3) check_cycle(0, 0);

        // Period 3: event on every third counting edge.
        configure(3, 1, 0);
        check_cycle(0, 0);
        check_cycle(0, 0);
        check_cycle(1, 1);
        check_cycle(0, 1);
        check_cycle(0, 1);
        check_cycle(1, 2);

        // Changing input settings without a write must have no effect.
        @(negedge CLK);
        Period = 1;
        Enable = 0;

        check_cycle(0, 2);
        check_cycle(0, 2);
        check_cycle(1, 3);

        // Reconfiguration restarts the interval and preserves total ticks.
        configure(2, 1, 3);
        check_cycle(0, 3);
        check_cycle(1, 4);

        // Disable: stop events, but keep the total tick count.
        configure(2, 0, 4);
        repeat (4) check_cycle(0, 4);

        // Period zero produces no events, even when enabled.
        configure(0, 1, 4);
        repeat (3) check_cycle(0, 4);

        // Period one produces an event on every counting edge.
        configure(1, 1, 4);
        check_cycle(1, 5);
        check_cycle(1, 6);
        check_cycle(1, 7);

        // Holding the configuration input high keeps restarting the timer.
        @(negedge CLK);
        ConfigureWritePulse = 1;
        Period = 2;
        Enable = 1;

        repeat (3) check_cycle(0, 7);

        @(negedge CLK);
        ConfigureWritePulse = 0;

        check_cycle(0, 7);
        check_cycle(1, 8);

        // Reset wins over a simultaneous configuration write.
        @(negedge CLK);
        RESET = 1;
        ConfigureWritePulse = 1;
        Period = 1;
        Enable = 1;

        check_cycle(0, 0);

        @(negedge CLK);
        RESET = 0;
        ConfigureWritePulse = 0;

        repeat (2) check_cycle(0, 0);

        if (errors == 0)
            $display("TIMER PASS: all %0d checks passed", checks);
        else
            $display("TIMER FAIL: %0d errors in %0d checks",
                     errors, checks);

        $finish;
    end

    initial begin
        #10000;
        $display("FAIL: Timer test timed out");
        $finish;
    end

endmodule