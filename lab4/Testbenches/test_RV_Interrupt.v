`timescale 1ns / 1ps
// AI-assisted educational CPU integration test for CG3207 Neon Space Defender.
// No IROM.mem/DMEM.mem, Wrapper, Timer, VGA, or physical buttons are required.
// Add this file to Simulation Sources; use test_RV_Interrupt as simulation top.
// Requires the user's DRAIN-state IRQHandler and the latest RV internal names.
// This is a representative workload, NOT the final game program.
module test_RV_Interrupt;
    localparam [31:0] TEXT_BASE = 32'h00400000;
    localparam [31:0] DATA_BASE = 32'h10010000;
    localparam [31:0] HANDLER_PC = 32'h00400100;
    // ACK is testbench-only, not a proposed final Wrapper memory map.
    localparam [31:0] ACK_ADDR = 32'hffff00b0;
    localparam [31:0] LED_ADDR = 32'hffff0060;
    localparam [31:0] SEG_ADDR = 32'hffff0080;

    reg CLK = 0;
    reg RESET = 1;
    reg IRQ = 0;
    reg [31:0] Instr, ReadData_in;
    wire MemRead;
    wire [3:0] WriteMask;
    wire [31:0] PCF, ALUResult, WriteData_out;
    RV #(.PC_INIT(TEXT_BASE)) dut (
        .CLK(CLK), .RESET(RESET), .IRQ(IRQ), .Instr(Instr),
        .ReadData_in(ReadData_in), .MemRead(MemRead), .WriteMask(WriteMask),
        .PCF(PCF), .ALUResult(ALUResult), .WriteData_out(WriteData_out)
    );
    always #5 CLK = ~CLK;

    reg [31:0] IROM [0:127];
    reg [7:0] RAM [0:1023];
    reg [7:0] RefRAM [0:1023];
    reg [31:0] RefReg [0:31];
    reg [31:0] RefPC, RefEPC;
    reg RefInHandler;
    // Observe PCs through M/W without modifying the DUT or its pipeline registers.
    reg [31:0] ObservePCM, ObservePCW;
    reg [3:0] ObserveMaskW;
    reg [31:0] ObserveAddressW, ObserveDataW;
    reg ObserveReadW;
    integer mode = 0;
    integer delay_count, cycles, entries, returns, ack_count;
    integer retired, stores, starts, drain_stalls, drain_redirects;
    integer load_stalls, checks = 0, passed = 0;
    integer i, k, scenario, wait_cycles, expected_entries;
    reg injected, startup_seen, main_done;
    reg [31:0] LEDValue, SevenSegValue, RefLED, RefSevenSeg;
    reg [31:0] saved_pc, saved_redirect;
    reg was_hold, was_redirect, was_clear_d, was_clear_e, was_hold_d;
    reg [31:0] saved_instr_d;
    reg saved_valid_d;

    task check;
        input condition;
        input [8*160-1:0] message;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL mode=%0d time=%0t PCF=%h RefPC=%h: %0s",
                         mode, $time, PCF, RefPC, message);
                $display("Valid D/E/M/W=%b%b%b%b PCE=%h IRQ=%b Busy=%b",
                         dut.ValidD,dut.ValidE,dut.ValidM,dut.ValidW,dut.PCE,IRQ,dut.Busy);
                $finish;
            end
        end
    endtask

    function [31:0] reference_word;
        input [31:0] address;
        integer a;
        begin
            a = (address - DATA_BASE) & 32'hfffffffc;
            reference_word = {RefRAM[a+3],RefRAM[a+2],RefRAM[a+1],RefRAM[a]};
        end
    endfunction

    // Asynchronous instruction and data reads, matching the CPU's current interface.
    integer read_index;
    always @(*) begin
        Instr = 32'h00000013;
        if (PCF >= TEXT_BASE && PCF < TEXT_BASE + 512)
            Instr = IROM[(PCF - TEXT_BASE) >> 2];
        ReadData_in = 0;
        read_index = 0;
        if (MemRead && ALUResult >= DATA_BASE && ALUResult < DATA_BASE + 1024) begin
            read_index = (ALUResult - DATA_BASE) & 32'hfffffffc;
            ReadData_in = {RAM[read_index+3],RAM[read_index+2],RAM[read_index+1],RAM[read_index]};
        end
    end

    // Independent instruction model. Runs once per valid W-stage instruction.
    // It derives results from instruction bits and reference state, not DUT results.
    task retire_reference;
        reg [31:0] ins, a, b, imm, value, next_pc, address, word_value;
        reg [31:0] store_data;
        reg [3:0] mask;
        reg write_reg, load_op, store_op, take_branch;
        integer rd, rs1, rs2, f3, byte_lane, byte_count, j, index;
        begin
            check(ObservePCW === RefPC, "Retirement PC mismatch: instruction skipped, repeated, or wrong path committed");
            check(RefPC >= TEXT_BASE && RefPC < TEXT_BASE+512 && RefPC[1:0]==0,
                  "Reference PC outside test instruction memory");
            ins = IROM[(RefPC-TEXT_BASE)>>2];
            rd=ins[11:7]; rs1=ins[19:15]; rs2=ins[24:20]; f3=ins[14:12];
            a=RefReg[rs1]; b=RefReg[rs2];
            imm={{20{ins[31]}},ins[31:20]};
            value=0; address=0; store_data=0; mask=0; byte_count=0;
            write_reg=0; load_op=0; store_op=0; take_branch=0;
            next_pc=RefPC+4;
            case(ins[6:0])
                7'h37: begin write_reg=1; value={ins[31:12],12'b0}; end
                7'h13: begin
                    check(f3==0,"Reference program expects only ADDI in immediate-ALU class");
                    write_reg=1; value=a+imm;
                end
                7'h33: begin
                    check(ins[31:25]==7'h01,"Unexpected R-type instruction in test image");
                    write_reg=1;
                    case(f3)
                        0: value=a*b;
                        4: begin check(b!=0,"Test must not divide by zero"); value=$signed(a)/$signed(b); end
                        5: begin check(b!=0,"Test must not divide by zero"); value=a/b; end
                        default: check(0,"Unsupported reference arithmetic instruction");
                    endcase
                end
                7'h03: begin
                    write_reg=1; load_op=1; address=a+imm;
                    check(address>=DATA_BASE && address<DATA_BASE+1024,"Load address outside RAM");
                    word_value=reference_word(address) >> (8*address[1:0]);
                    case(f3)
                        0: value={{24{word_value[7]}},word_value[7:0]};
                        1: begin check(!address[0],"Unaligned halfword outside test scope"); value={{16{word_value[15]}},word_value[15:0]}; end
                        2: begin check(address[1:0]==0,"Unaligned word outside test scope"); value=word_value; end
                        4: value={24'b0,word_value[7:0]};
                        5: begin check(!address[0],"Unaligned halfword outside test scope"); value={16'b0,word_value[15:0]}; end
                        default: check(0,"Unsupported reference load");
                    endcase
                end
                7'h23: begin
                    store_op=1;
                    imm={{20{ins[31]}},ins[31:25],ins[11:7]}; address=a+imm;
                    byte_lane=address[1:0];
                    case(f3)
                        0: byte_count=1;
                        1: begin byte_count=2; check(!address[0],"Unaligned store halfword"); end
                        2: begin byte_count=4; check(byte_lane==0,"Unaligned store word"); end
                        default: check(0,"Unsupported reference store");
                    endcase
                    mask=((1<<byte_count)-1)<<byte_lane;
                    store_data=b << (8*byte_lane);
                end
                7'h63: begin
                    imm={{19{ins[31]}},ins[31],ins[7],ins[30:25],ins[11:8],1'b0};
                    case(f3)
                        0: take_branch=(a==b);
                        1: take_branch=(a!=b);
                        default: check(0,"Unsupported reference branch");
                    endcase
                    if(take_branch) next_pc=RefPC+imm;
                end
                7'h6f: begin
                    imm={{11{ins[31]}},ins[31],ins[19:12],ins[20],ins[30:21],1'b0};
                    write_reg=1;value=RefPC+4;next_pc=RefPC+imm;
                end
                7'h67: begin write_reg=1;value=RefPC+4;next_pc=(a+imm)&32'hfffffffe;end
                7'h73: begin
                    check(ins===32'h30200073 && RefInHandler,"Unexpected SYSTEM instruction or MRET outside handler");
                    next_pc=RefEPC; RefInHandler=0;
                end
                default: check(0,"Unsupported instruction reached reference model");
            endcase
            check(dut.WE === write_reg,"Unexpected or missing register write-enable");
            if(write_reg && rd!=0) begin
                if(dut.rdW!==rd || dut.WD!==value)
                    $display("  instruction=%h rd=%0d expected=%h actual rd=%0d data=%h",ins,rd,value,dut.rdW,dut.WD);
                check(dut.rdW==rd && dut.WD===value,"Register result mismatch");
                RefReg[rd]=value;
            end
            RefReg[0]=0;
            check(ObserveReadW === load_op,"Unexpected or missing memory read");
            check(ObserveMaskW === mask,"Unexpected, missing, or incorrect store byte mask");
            if(load_op || store_op) check(ObserveAddressW===address,"Memory address mismatch");
            if(store_op) begin
                for(j=0;j<4;j=j+1)
                    if(mask[j]) check(ObserveDataW[j*8+:8]===store_data[j*8+:8],"Stored byte mismatch");
                if(address>=DATA_BASE && address<DATA_BASE+1024) begin
                    index=address-DATA_BASE;
                    for(j=0;j<byte_count;j=j+1) RefRAM[index+j]=b[j*8+:8];
                end else begin
                    check(mask==4'b1111,"Test MMIO writes must be full words");
                    case(address)
                        LED_ADDR: RefLED=b;
                        SEG_ADDR: RefSevenSeg=b;
                        ACK_ADDR: check(b==1,"IRQ acknowledgement must be one");
                        default: check(0,"Unmodelled MMIO address");
                    endcase
                end
            end
            RefPC=next_pc; retired=retired+1;
        end
    endtask

    // Sample pre-edge outputs: these are the actions the real synchronous
    // register file/RAM would accept. Check updated PC/validity after NBA with #1.
    integer mem_index, lane;
    always @(posedge CLK) begin
        if(RESET) begin
            ObservePCM<=0; ObservePCW<=0; ObserveMaskW<=0;
            ObserveAddressW<=0; ObserveDataW<=0; ObserveReadW<=0;
            RefPC=TEXT_BASE; RefEPC=0; RefInHandler=0;
            cycles=0; entries=0; returns=0; ack_count=0;
            retired=0; stores=0; starts=0; drain_stalls=0; drain_redirects=0;load_stalls=0;
            startup_seen=0;main_done=0;
            LEDValue=0;SevenSegValue=0;RefLED=0;RefSevenSeg=0;
            for(k=0;k<32;k=k+1) RefReg[k]=0;
            for(k=0;k<1024;k=k+1) begin RAM[k]<=0;RefRAM[k]=0;end
            RAM[0]<=100;RefRAM[0]=100;
        end else begin
            cycles=cycles+1;
            check((^{PCF,MemRead,WriteMask,dut.WE,dut.ValidD,dut.ValidE,dut.ValidM,dut.ValidW}) !== 1'bx,
                  "Unknown PC, validity, or side-effect control after reset");
            check(!(dut.WE && !dut.ValidW),"Invalid W stage wrote a register");
            check(!((MemRead || |WriteMask) && !dut.ValidM),"Invalid M stage accessed memory");
            check(!(dut.Start && !dut.ValidE),"Invalid E stage started MCycle");
            if(dut.Start) starts=starts+1;
            if(dut.StallD && !dut.StallE) load_stalls=load_stalls+1;
            if(dut.StopFetchAdmission && dut.StallD) drain_stalls=drain_stalls+1;
            if(dut.StopFetchAdmission && dut.MispredictE) drain_redirects=drain_redirects+1;
            if(dut.ValidW) retire_reference;
            else begin
                check(!dut.WE,"Bubble has write enable");
                check(ObserveMaskW==0 && !ObserveReadW,"Bubble performed memory operation");
            end
            if(dut.InterruptTaken) begin
                check(dut.PipelineEmpty && !RefInHandler,"IRQ entry before empty pipeline or nested entry");
                check(PCF===RefPC,"ResumePC is not the next unexecuted instruction");
                RefEPC=RefPC;RefPC=HANDLER_PC;RefInHandler=1;entries=entries+1;
            end
            if(dut.ReturnFromInterrupt) begin
                check(RefInHandler && dut.MRETExecute,"Return without valid handler MRET");
                check(dut.ReturnPC===RefEPC,"Return address differs from independently tracked continuation");
                check(dut.IRQFlushD && dut.IRQFlushE,"MRET must flush younger D/E instructions");
                returns=returns+1;
            end
            ObservePCM<=dut.PCE; ObservePCW<=ObservePCM;
            ObserveMaskW<=WriteMask;ObserveAddressW<=ALUResult;
            ObserveDataW<=WriteData_out;ObserveReadW<=MemRead;
            if(MemRead) check(ALUResult>=DATA_BASE && ALUResult<DATA_BASE+1024,"Unexpected read outside RAM");
            if(|WriteMask) begin
                stores=stores+1;
                if(ALUResult>=DATA_BASE && ALUResult<DATA_BASE+1024) begin
                    mem_index=(ALUResult-DATA_BASE)&32'hfffffffc;
                    check(mem_index!=244,"Wrong-path poison store reached RAM");
                    for(lane=0;lane<4;lane=lane+1)
                        if(WriteMask[lane]) RAM[mem_index+lane]<=WriteData_out[lane*8+:8];
                    if(mem_index==240) startup_seen=1;
                    if(mem_index==252) main_done=1;
                end else begin
                    check(WriteMask==15,"MMIO requires word store in this workload");
                    case(ALUResult)
                        LED_ADDR: LEDValue=WriteData_out;
                        SEG_ADDR: SevenSegValue=WriteData_out;
                        ACK_ADDR: ack_count=ack_count+1;
                        default: check(0,"Unexpected MMIO write");
                    endcase
                end
            end
            was_clear_d=dut.ClearD; was_clear_e=dut.ClearE;
            was_hold_d=dut.StallD && !dut.ClearD;
            saved_instr_d=dut.InstrD; saved_valid_d=dut.ValidD;
            saved_pc=PCF;
            was_hold=dut.StopFetchAdmission && !dut.MispredictE && !dut.InterruptTaken && !dut.ReturnFromInterrupt;
            was_redirect=dut.InterruptTaken || dut.ReturnFromInterrupt || dut.MispredictE;
            saved_redirect=dut.ReturnFromInterrupt ? dut.ReturnPC :
                           dut.InterruptTaken ? HANDLER_PC : dut.ActualNextPCE;
            #1;
            if(was_clear_d) check(dut.ValidD===1'b0,"D clear must clear ValidD");
            if(was_clear_e) check(dut.ValidE===1'b0 && dut.MRETE===1'b0,"E clear must clear validity and MRET");
            if(was_hold_d) check(dut.InstrD===saved_instr_d && dut.ValidD===saved_valid_d,"Stalled D instruction was lost or changed");
            if(was_hold) check(PCF===saved_pc,"PC advanced during drain without redirect");
            if(was_redirect) check(PCF===saved_redirect,"PC redirect was not accepted");
        end
    end

    // IRQ stimulus changes on falling edges to avoid races with DUT sampling.
    // mode 7 deliberately ignores the first ACK, representing an event still pending.
    always @(negedge CLK) begin
        if(RESET) begin IRQ=0;injected=0;delay_count=0;end
        else begin
            if(!injected) begin
                case(mode)
                    0: begin end
                    1,7: if(dut.ValidE && dut.PCE==TEXT_BASE+32) begin IRQ=1;injected=1;end
                    2: if(dut.ValidE && dut.PCE==TEXT_BASE+24 && dut.StallD) begin IRQ=1;injected=1;end
                    3,8: if(dut.ValidE && dut.PCE==TEXT_BASE+44 && dut.Busy) begin IRQ=1;injected=1;end
                    4: if(dut.ValidE && dut.PCE==TEXT_BASE+48 && dut.Busy) begin IRQ=1;injected=1;end
                    5: if(dut.ValidD && dut.PCD==TEXT_BASE+96) begin IRQ=1;injected=1;end
                    6: if(dut.ValidD && dut.PCD==TEXT_BASE+124) begin IRQ=1;injected=1;end
                    9: if(dut.ValidE && dut.PCE==TEXT_BASE+32) begin IRQ=1;injected=1;end
                    10: if(dut.ValidE && dut.PCE==TEXT_BASE+52 && dut.Busy) begin IRQ=1;injected=1;end
                    11: if(dut.ValidE && dut.PCE==TEXT_BASE+36) begin IRQ=1;injected=1;end
                    12: if(dut.ValidM && ALUResult==DATA_BASE+12 && |WriteMask) begin IRQ=1;injected=1;end
                    13: if(dut.ValidM && ALUResult==DATA_BASE+14 && |WriteMask) begin IRQ=1;injected=1;end
                    14: if(dut.ValidE && dut.PCE==TEXT_BASE+96 && dut.PredictedNextPCE==TEXT_BASE+88) begin IRQ=1;injected=1;end
                    default: if(mode>=20 && startup_seen) begin
                        if(delay_count==mode-20) begin IRQ=1;injected=1;end
                        else delay_count=delay_count+1;
                    end
                endcase
            end
            if(injected && ack_count >= ((mode==7)?2:1)) IRQ=0;
        end
    end

    task start_case;
        input integer new_mode;
        begin
            // Drive reset away from both clock edges.
            #2;RESET=1;mode=new_mode;
            repeat(4) @(posedge CLK);
            #2;RESET=0;
        end
    endtask

    task finish_case;
        input integer wanted_entries;
        integer n;
        begin
            n=0;
            while(!(main_done && entries==wanted_entries && returns==wanted_entries &&
                    !RefInHandler && IRQ==0) && n<1500) begin
                @(posedge CLK);#2;n=n+1;
            end
            check(n<1500,"Timeout: missing trigger, deadlock, missing MRET, or program did not finish");
            repeat(12) begin @(posedge CLK);#2;end
            check(entries==wanted_entries && returns==wanted_entries,"Incorrect number of IRQ entries/returns");
            check(ack_count==wanted_entries,"Each handler must acknowledge exactly once");
            check(starts==3,"MUL, DIV and DIVU must each start exactly once");
            check(load_stalls>0,"Workload did not exercise load-use stalls");
            check(RefReg[5]==20 && RefReg[6]==32'hfffffffd,"Handler did not preserve scratch registers");
            check(RefReg[7]==101 && RefReg[9]==32'hffffffc4 && RefReg[10]==20 && RefReg[11]==5,
                  "Position/arithmetic final values incorrect");
            check(RefReg[12]==32'hfffffffd && RefReg[13]==253 &&
                  RefReg[14]==32'hffffffc4 && RefReg[15]==65476,"Subword extension results incorrect");
            check(reference_word(DATA_BASE+4)==101 && reference_word(DATA_BASE+8)==100 &&
                  reference_word(DATA_BASE+16)==14,"Position/copy/subroutine final state incorrect");
            check(reference_word(DATA_BASE+256)==wanted_entries,"Handler event counter mismatch");
            check(reference_word(DATA_BASE+244)==0,"Poison location was modified");
            for(n=0;n<1024;n=n+1) check(RAM[n]===RefRAM[n],"Actual RAM differs from independent reference RAM");
            check(LEDValue===RefLED && SevenSegValue===RefSevenSeg,"MMIO display state mismatch");
            check(LEDValue==101,"Final LED test value must be 101");
            check(SevenSegValue==32'hffffffc4,"Final seven-segment test value must be ffffffc4");
            if(mode==3 || mode==4 || mode==10) check(drain_stalls>0,"Required MCycle stall during drain not covered");
            if(mode==5 || mode==6) check(drain_redirects>0,"Required branch/jump correction during drain not covered");
            passed=passed+1;
            $display("PASS mode=%0d entries=%0d retired=%0d stores=%0d cycles=%0d drain_stalls=%0d drain_redirects=%0d",
                     mode,entries,retired,stores,cycles,drain_stalls,drain_redirects);
        end
    endtask

    initial begin
        for(i=0;i<128;i=i+1) IROM[i]=32'h00000013;
    IROM[0] = 32'h10010a37; // lui x20,0x10010 # simulated data RAM base
    IROM[1] = 32'hffff0fb7; // lui x31,0xffff0 # MMIO base
    IROM[2] = 32'h200a0113; // addi x2,x20,512 # stack top
    IROM[3] = 32'h01400293; // addi x5,x0,20 # position/scale
    IROM[4] = 32'hffd00313; // addi x6,x0,-3 # signed velocity
    IROM[5] = 32'h0e5a2823; // sw x5,240(x20) # test startup marker
    IROM[6] = 32'h000a2383; // lw x7,0(x20) # initial position = 100
    IROM[7] = 32'h00138393; // addi x7,x7,1 # load-use dependency
    IROM[8] = 32'h007a2223; // sw x7,4(x20)
    IROM[9] = 32'h000a2403; // lw x8,0(x20)
    IROM[10] = 32'h008a2423; // sw x8,8(x20) # immediate load-to-store data dependency
    IROM[11] = 32'h026284b3; // mul x9,x5,x6 # -60
    IROM[12] = 32'h0264c533; // div x10,x9,x6 # 20
    IROM[13] = 32'h0253d5b3; // divu x11,x7,x5 # 5
    IROM[14] = 32'h006a0623; // sb x6,12(x20)
    IROM[15] = 32'h00ca0603; // lb x12,12(x20) # -3
    IROM[16] = 32'h00ca4683; // lbu x13,12(x20) # 253
    IROM[17] = 32'h009a1723; // sh x9,14(x20) # aligned halfword, high two lanes
    IROM[18] = 32'h00ea1703; // lh x14,14(x20) # -60
    IROM[19] = 32'h00ea5783; // lhu x15,14(x20) # 65476
    IROM[20] = 32'h00400813; // addi x16,x0,4
    IROM[21] = 32'h00000893; // addi x17,x0,0
    IROM[22] = 32'h00188893; // loop: addi x17,x17,1
    IROM[23] = 32'hfff80813; // addi x16,x16,-1
    IROM[24] = 32'hfe081ce3; // bne x16,x0,loop # train predictor, then exit
    IROM[25] = 32'h00088463; // beq x17,x0,poison # not taken
    IROM[26] = 32'h01188663; // beq x17,x17,safe # taken: skip poison instructions
    IROM[27] = 32'h0e6a2a23; // poison: sw x6,244(x20) # MUST NOT execute
    IROM[28] = 32'h3e700893; // addi x17,x0,999 # MUST NOT execute
    IROM[29] = 32'h00400937; // safe: lui x18,0x00400
    IROM[30] = 32'h18090913; // addi x18,x18,384 # aligned subroutine address
    IROM[31] = 32'h000900e7; // jalr x1,0(x18) # clears target bit 0
    IROM[32] = 32'h011a2823; // sw x17,16(x20) # 14 after subroutine
    IROM[33] = 32'h067fa023; // sw x7,96(x31) # LED write, 101
    IROM[34] = 32'h089fa023; // sw x9,128(x31) # seven-seg write, ffffffc4
    IROM[35] = 32'h00100993; // addi x19,x0,1
    IROM[36] = 32'h0f3a2e23; // sw x19,252(x20) # test completion marker
    IROM[37] = 32'h0000006f; // halt: jal x0,halt
    IROM[64] = 32'hfe512e23; // sw x5,-4(x2) # save scratch register
    IROM[65] = 32'hfe612c23; // sw x6,-8(x2)
    IROM[66] = 32'h100a2283; // lw x5,256(x20) # handled-event counter
    IROM[67] = 32'h00128293; // addi x5,x5,1
    IROM[68] = 32'h105a2023; // sw x5,256(x20)
    IROM[69] = 32'h085fa023; // sw x5,128(x31) # visible handler activity
    IROM[70] = 32'h00100313; // addi x6,x0,1
    IROM[71] = 32'h0a6fa823; // sw x6,176(x31) # TEST-ONLY IRQ acknowledgement
    IROM[72] = 32'hff812303; // lw x6,-8(x2) # restore scratch register
    IROM[73] = 32'hffc12283; // lw x5,-4(x2)
    IROM[74] = 32'h30200073; // mret
    IROM[75] = 32'h0e6a2a23; // sw x6,244(x20) # younger instruction: MUST be flushed
    IROM[76] = 32'h3e700893; // addi x17,x0,999 # MUST be flushed
    IROM[96] = 32'h00a88893; // subroutine: addi x17,x17,10
    IROM[97] = 32'h00008067; // jalr x0,0(x1)
        $display("Starting Neon Space Defender RV integration tests");
        $display("MMIO ACK at ffff00b0 is a TESTBENCH convention only.");
        // Baseline, ordinary IRQ, load hazard, MUL, DIV, branch, JALR, pending IRQ.
        for(scenario=0;scenario<=7;scenario=scenario+1) begin
            start_case(scenario);
            expected_entries=(scenario==0)?0:((scenario==7)?2:1);
            finish_case(expected_entries);
        end
        // Additional game-relevant boundaries: DIVU, load-to-store forwarding,
        // byte/halfword writes, and a warmed taken-branch prediction.
        for(scenario=10;scenario<=14;scenario=scenario+1) begin
            start_case(scenario);
            finish_case(1);
        end
        // Reset while draining a busy multiply; then restart from reset normally.
        start_case(8);
        wait_cycles=0;
        while(!(dut.StopFetchAdmission && dut.Busy) && wait_cycles<500) begin
            @(posedge CLK);#2;wait_cycles=wait_cycles+1;
        end
        check(wait_cycles<500,"Reset-during-drain setup was not reached");
        start_case(0);
        check(dut.IRQHandler1.EPC==0,"Reset did not clear EPC");
        finish_case(0);
        $display("PASS reset during busy drain, followed by complete restart");
        // Reset inside the handler, before its acknowledgement.
        start_case(9);
        wait_cycles=0;
        while(!(dut.ValidE && dut.PCE==HANDLER_PC+4) && wait_cycles<500) begin
            @(posedge CLK);#2;wait_cycles=wait_cycles+1;
        end
        check(wait_cycles<500,"Reset-in-handler setup was not reached");
        start_case(0);
        check(dut.IRQHandler1.EPC==0,"Reset in handler did not clear EPC");
        finish_case(0);
        $display("PASS reset inside handler, followed by complete restart");
        // Sweep IRQ timing over 81 different clock positions after startup.
        // Includes stalled cycles and arrivals close to pipeline transitions.
        for(scenario=20;scenario<=100;scenario=scenario+1) begin
            start_case(scenario);
            finish_case(1);
        end
        $display("--------------------------------------------------");
        $display("RV INTERRUPT PASS: all %0d completed runs passed",passed);
        $display("Includes 13 directed runs, 2 reset/restart runs, 81 IRQ-timing runs.");
        $display("Checks performed: %0d",checks);
        $display("--------------------------------------------------");
        $finish;
    end
    // Independent overall watchdog: even a stimulus wait must not hang forever.
    initial begin
        #2000000;
        $display("FAIL: global simulation timeout");
        $finish;
    end
endmodule
