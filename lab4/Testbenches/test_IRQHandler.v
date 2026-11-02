`timescale 1ns / 1ps

module test_IRQHandler;

    localparam [31:0] HANDLER_ADDRESS = 32'h00400100;

    reg CLK = 0;
    reg RESET = 0;
    reg IRQ = 0;
    reg MRET = 0;
    reg [31:0] PC = 0;

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
        .MRET(MRET),
        .PC(PC),
        .InterruptTaken(InterruptTaken),
        .ReturnFromInterrupt(ReturnFromInterrupt),
        .InterruptPC(InterruptPC),
        .ReturnPC(ReturnPC),
        .FlushD(FlushD),
        .FlushE(FlushE)
    );

    always #5 CLK = ~CLK;

    // Check outputs and the two internal state registers.
    // Internal checks match your current names: InInterrupt and EPC.
    task step;
        input reset_value;
        input irq_value;
        input mret_value;
        input [31:0] pc_value;
        input expected_entry;
        input expected_return;
        input expected_active;
        input [31:0] expected_epc;
        input [31:0] expected_interrupt_pc;
        input [31:0] expected_return_pc;
        begin
            @(negedge CLK);
            RESET = reset_value;
            IRQ = irq_value;
            MRET = mret_value;
            PC = pc_value;

            @(posedge CLK);
            #1;
            checks = checks + 1;

            if ((InterruptTaken !== expected_entry) ||
                (ReturnFromInterrupt !== expected_return) ||
                (FlushD !== (expected_entry | expected_return)) ||
                (FlushE !== (expected_entry | expected_return)) ||
                (dut.InInterrupt !== expected_active) ||
                (dut.EPC !== expected_epc) ||
                (InterruptPC !== expected_interrupt_pc) ||
                (ReturnPC !== expected_return_pc)) begin

                errors = errors + 1;
                $display("FAIL check %0d at %0t", checks, $time);
                $display(" Entry=%b expected=%b Return=%b expected=%b",
                         InterruptTaken, expected_entry,
                         ReturnFromInterrupt, expected_return);
                $display(" FlushD=%b FlushE=%b Active=%b expected=%b",
                         FlushD, FlushE, dut.InInterrupt, expected_active);
                $display(" EPC=%h expected=%h",
                         dut.EPC, expected_epc);
                $display(" InterruptPC=%h expected=%h",
                         InterruptPC, expected_interrupt_pc);
                $display(" ReturnPC=%h expected=%h",
                         ReturnPC, expected_return_pc);
            end
        end
    endtask

    initial begin
        $display("Starting IRQHandler tests");
        $display("NOTE: These tests assume the current EPC = PC + 4 design.");

        // Reset takes priority over IRQ and MRET.
        step(1, 1, 1, 32'h00400020,
             0, 0, 0, 0, 0, 0);

        // MRET outside a handler is ignored by this simplified module.
        step(0, 0, 1, 32'h00400020,
             0, 0, 0, 0, 0, 0);

        // Enter handler: save 00400024.
        step(0, 1, 0, 32'h00400020,
             1, 0, 1, 32'h00400024, HANDLER_ADDRESS, 0);

        // IRQ remains high: no nested entry, no EPC overwrite.
        step(0, 1, 0, 32'h00400110,
             0, 0, 1, 32'h00400024, HANDLER_ADDRESS, 0);

        // Keep executing handler with no request.
        step(0, 0, 0, 32'h00400114,
             0, 0, 1, 32'h00400024, HANDLER_ADDRESS, 0);

        // Return to saved address.
        step(0, 0, 1, 32'h00400118,
             0, 1, 0, 32'h00400024, HANDLER_ADDRESS, 32'h00400024);

        // Return/flush pulses clear on the following cycle.
        step(0, 0, 0, 32'h00400024,
             0, 0, 0, 32'h00400024, HANDLER_ADDRESS, 32'h00400024);

        // A later interrupt captures a new EPC.
        step(0, 1, 0, 32'h00400040,
             1, 0, 1, 32'h00400044, HANDLER_ADDRESS, 32'h00400024);

        // While in handler, MRET takes priority over IRQ.
        step(0, 1, 1, 32'h00400118,
             0, 1, 0, 32'h00400044, HANDLER_ADDRESS, 32'h00400044);

        // Unacknowledged IRQ causes entry again on the next cycle.
        step(0, 1, 0, 32'h00400044,
             1, 0, 1, 32'h00400048, HANDLER_ADDRESS, 32'h00400044);

        // Reset while handling an interrupt.
        step(1, 1, 1, 32'h00400118,
             0, 0, 0, 0, 0, 0);

        step(0, 0, 0, 32'h00400000,
             0, 0, 0, 0, 0, 0);

        if (errors == 0)
            $display("IRQ HANDLER PASS: all %0d checks passed", checks);
        else
            $display("IRQ HANDLER FAIL: %0d errors", errors);

        $finish;
    end

    initial begin
        #10000;
        $display("FAIL: IRQHandler test timed out");
        $finish;
    end

endmodule