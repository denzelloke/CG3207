`timescale 1ns / 1ps

module test_IRQHandler;

    localparam [31:0] HANDLER_ADDRESS = 32'h00400100;

    localparam [1:0] NORMAL  = 2'b00;
    localparam [1:0] DRAIN   = 2'b01;
    localparam [1:0] HANDLER = 2'b10;

    // Inputs
    reg CLK = 0;
    reg RESET = 0;
    reg IRQ = 0;
    reg [31:0] ResumePC = 0;
    reg PipelineEmpty = 0;
    reg MRETExecute = 0;

    // Outputs
    wire StopFetchAdmission;
    wire InterruptTaken;
    wire ReturnFromInterrupt;
    wire [31:0] InterruptPC;
    wire [31:0] ReturnPC;
    wire FlushD;
    wire FlushE;

    integer errors = 0;
    integer checks = 0;

    IRQHandler #(
        .HANDLER_ADDRESS(HANDLER_ADDRESS)
    ) dut (
        .CLK(CLK),
        .RESET(RESET),
        .IRQ(IRQ),
        .ResumePC(ResumePC),
        .PipelineEmpty(PipelineEmpty),
        .MRETExecute(MRETExecute),
        .StopFetchAdmission(StopFetchAdmission),
        .InterruptTaken(InterruptTaken),
        .ReturnFromInterrupt(ReturnFromInterrupt),
        .InterruptPC(InterruptPC),
        .ReturnPC(ReturnPC),
        .FlushD(FlushD),
        .FlushE(FlushE)
    );

    // Clock: 10 ns period
    always #5 CLK = ~CLK;

    // Apply inputs on a falling edge.
    // Check combinational requests before the next rising edge.
    // Then check the stored state and EPC after that rising edge.
    task step;
        input [8*100-1:0] description;

        input reset_value;
        input irq_value;
        input empty_value;
        input mret_value;
        input [31:0] resume_value;

        input expected_stop;
        input expected_entry;
        input expected_return;
        input expected_flush;

        input [1:0] expected_state_after;
        input [31:0] expected_epc_after;

        integer errors_before;
        reg [31:0] epc_before;

        begin
            errors_before = errors;

            @(negedge CLK);
            RESET = reset_value;
            IRQ = irq_value;
            PipelineEmpty = empty_value;
            MRETExecute = mret_value;
            ResumePC = resume_value;

            #1;
            epc_before = dut.EPC;

            // These signals must be correct BEFORE the accepting edge.
            if ((StopFetchAdmission !== expected_stop) ||
                (InterruptTaken !== expected_entry) ||
                (ReturnFromInterrupt !== expected_return) ||
                (FlushD !== expected_flush) ||
                (FlushE !== expected_flush)) begin

                errors = errors + 1;

                $display("FAIL before edge: %0s", description);
                $display(" Stop=%b expected=%b",
                         StopFetchAdmission, expected_stop);
                $display(" Entry=%b expected=%b Return=%b expected=%b",
                         InterruptTaken, expected_entry,
                         ReturnFromInterrupt, expected_return);
                $display(" FlushD=%b FlushE=%b expected=%b",
                         FlushD, FlushE, expected_flush);
            end

            // Addresses are continuously available.
            if (InterruptPC !== HANDLER_ADDRESS) begin
                errors = errors + 1;
                $display("FAIL: InterruptPC=%h expected=%h",
                         InterruptPC, HANDLER_ADDRESS);
            end

            if (ReturnPC !== epc_before) begin
                errors = errors + 1;
                $display("FAIL: ReturnPC does not match current EPC");
            end

            @(posedge CLK);
            #1;

            if ((dut.State !== expected_state_after) ||
                (dut.EPC !== expected_epc_after) ||
                (ReturnPC !== expected_epc_after)) begin

                errors = errors + 1;

                $display("FAIL after edge: %0s", description);
                $display(" State=%b expected=%b",
                         dut.State, expected_state_after);
                $display(" EPC=%h expected=%h",
                         dut.EPC, expected_epc_after);
                $display(" ReturnPC=%h expected=%h",
                         ReturnPC, expected_epc_after);
            end

            checks = checks + 1;

            if (errors == errors_before)
                $display("PASS: %0s", description);
        end
    endtask

    initial begin
        $display("Starting drain-state IRQHandler tests");

        // Arguments after description:
        // RESET, IRQ, PipelineEmpty, MRETExecute, ResumePC
        // expected Stop, Entry, Return, Flush
        // expected State after edge, EPC after edge

        step("Reset overrides IRQ and MRET",
             1, 1, 1, 1, 32'h00400020,
             1, 0, 0, 0,
             NORMAL, 32'h00000000);

        step("Normal execution without IRQ",
             0, 0, 0, 0, 32'h00400020,
             0, 0, 0, 0,
             NORMAL, 32'h00000000);

        step("MRET outside handler is ignored",
             0, 0, 0, 1, 32'h00400020,
             0, 0, 0, 0,
             NORMAL, 32'h00000000);

        // IRQ selects DRAIN; entry does not happen on this edge.
        step("IRQ starts draining",
             0, 1, 0, 0, 32'h00400020,
             0, 0, 0, 0,
             DRAIN, 32'h00000000);

        step("Occupied pipeline prevents interrupt entry",
             0, 1, 0, 0, 32'h00400024,
             1, 0, 0, 0,
             DRAIN, 32'h00000000);

        // Once draining starts, dropping IRQ does not cancel it.
        step("Drain continues even if IRQ drops",
             0, 0, 0, 0, 32'h00400024,
             1, 0, 0, 0,
             DRAIN, 32'h00000000);

        step("MRET is ignored during drain",
             0, 0, 0, 1, 32'h00400024,
             1, 0, 0, 0,
             DRAIN, 32'h00000000);

        // Emulate RV correcting the continuation after a branch recovery.
        step("Resume address can change while draining",
             0, 0, 0, 0, 32'h00400080,
             1, 0, 0, 0,
             DRAIN, 32'h00000000);

        // EPC must capture 00400080 directly, NOT 00400084.
        step("Empty pipeline permits entry and captures ResumePC",
             0, 0, 1, 0, 32'h00400080,
             1, 1, 0, 0,
             HANDLER, 32'h00400080);

        step("Handler permits instruction admission",
             0, 0, 0, 0, 32'h00400110,
             0, 0, 0, 0,
             HANDLER, 32'h00400080);

        step("IRQ during handler does not cause nested entry",
             0, 1, 1, 0, 32'h00400114,
             0, 0, 0, 0,
             HANDLER, 32'h00400080);

        step("MRET redirects to EPC and flushes younger instructions",
             0, 0, 0, 1, 32'h00400118,
             1, 0, 1, 1,
             NORMAL, 32'h00400080);

        step("Return requests clear after returning",
             0, 0, 0, 0, 32'h00400080,
             0, 0, 0, 0,
             NORMAL, 32'h00400080);

        // Even if already empty, NORMAL first transitions into DRAIN.
        step("New IRQ with empty pipeline still starts with DRAIN",
             0, 1, 1, 0, 32'h004000A0,
             0, 0, 0, 0,
             DRAIN, 32'h00400080);

        step("Second entry replaces the saved EPC",
             0, 1, 1, 0, 32'h004000A4,
             1, 1, 0, 0,
             HANDLER, 32'h004000A4);

        step("MRET is allowed while IRQ remains asserted",
             0, 1, 0, 1, 32'h00400118,
             1, 0, 1, 1,
             NORMAL, 32'h004000A4);

        step("Unacknowledged IRQ starts another drain",
             0, 1, 0, 0, 32'h004000A4,
             0, 0, 0, 0,
             DRAIN, 32'h004000A4);

        step("Reset during drain cancels entry",
             1, 1, 1, 1, 32'h004000A4,
             1, 0, 0, 0,
             NORMAL, 32'h00000000);

        step("Start another interrupt after reset",
             0, 1, 0, 0, 32'h004000C0,
             0, 0, 0, 0,
             DRAIN, 32'h00000000);

        step("Enter handler after reset",
             0, 0, 1, 0, 32'h004000C0,
             1, 1, 0, 0,
             HANDLER, 32'h004000C0);

        step("Reset during handler suppresses return and clears EPC",
             1, 1, 1, 1, 32'h00400118,
             1, 0, 0, 0,
             NORMAL, 32'h00000000);

        step("Normal operation resumes after reset",
             0, 0, 0, 0, 32'h00400000,
             0, 0, 0, 0,
             NORMAL, 32'h00000000);

        $display("----------------------------------------");

        if (errors == 0)
            $display("IRQ HANDLER PASS: all %0d scenarios passed",
                     checks);
        else
            $display("IRQ HANDLER FAIL: %0d errors in %0d scenarios",
                     errors, checks);

        $display("----------------------------------------");
        $finish;
    end

    // Prevent a broken test from running indefinitely.
    initial begin
        #10000;
        $display("FAIL: IRQHandler test timed out");
        $finish;
    end

endmodule