# Neon Space Defender handoff — Person 3: byte/halfword instructions, metrics, and integration verification

Self-contained handoff for a fresh LLM chat. Give that chat this file and access to the current repository. The other handoff files are not required to understand this one.

**Assigned role:** Person 3: byte/halfword instructions, metrics, and integration verification. Read the shared context and then your detailed workstream below. Do not assume ownership of the other students' tasks.

## Shared project context

The team has three students working on NUS CG3207 Lab 4. Their starting design is a five-stage pipelined RISC-V CPU with forwarding, load-use stalls, branch flushing, and an MCycle multiply/divide unit. They originally considered a stored-video player, then rejected the memory-system complexity. They selected **Neon Space Defender**, an interactive VGA arcade game, to demonstrate processor enhancements.

The goal is a small, polished, playable game with defensible measurements of architectural improvements. The students own the enhancement design, implementation, understanding, and verification. A separate demo LLM/chat will implement the surrounding application and presentation. This split concerns responsibility, not a claim that an LLM cannot assist a student.

**Current task state:** these are planning handoffs. No predictor, interrupt support, subword support, counters, or game has been implemented as part of creating these files. Existing source was inspected, but no new simulation, synthesis, timing closure, or board verification was performed. Do not confuse proposed functionality with verified functionality.

### Chosen scope

- CPU executes movement, enemy updates, bullet updates, collision detection, health, score, and wave progression as RISC-V software.
- Start with one player, four enemies, and four bullets. Increase counts only after a working demo.
- VGA hardware draws CPU-provided object state. It must not secretly implement the game logic being used to demonstrate CPU performance.
- Use small on-chip program/data memories, sprite/font ROMs, and display registers.
- Use object registers and a sprite renderer, rather than a full software-painted framebuffer, for the first version.
- No DDR, cache, DMA, stored video, MP4 decoding, camera, OS, superscalar execution, or out-of-order execution.
- Audio is optional: short shot/explosion tones from a simple peripheral.
- Do not add another large enhancement merely to make the proposal sound impressive.
- Hardware performance figures and relative speedups must be measured, not invented.

### Inputs and outputs

| Interface | Intended function |
|---|---|
| Left/right buttons | Move the player; expose clean held levels |
| Fire button | Capture a clean press event; optionally software-controlled repeat |
| Start/reset | Begin/restart a round; distinguish game restart from CPU reset |
| Difficulty switches | Select enemy speed/object count |
| Comparison switches | Select predictor mode, polling/interrupt mode, or software routine |
| VGA monitor | Game, score, health, selected mode, performance overlay |
| LEDs/seven-segment | Useful debug/status/counter output |
| Audio jack, optional | Simple shot/explosion sounds |

Physical pin assignments, active polarity, exact button mapping, and board revision must be confirmed. Nexys4 DDR is the working assumption because the repository contains its constraints; the user confirmed VGA, not an exact board revision. Do not assume old button functions can remain unchanged. Apply comparison modes between rounds with a safe pipeline/software transition, not asynchronously in the middle of an ISR or prediction sequence.

### System outline

Legend: EXISTING = starting foundation; DEMO = separate demo LLM; HUMAN = student enhancement.

~~~text
Buttons / switches
    |
    +--> DEMO: synchronisers, debounce, held levels and clean event pulses
                 |
                 +--> HUMAN Person 2: timer/button pending interrupt controller
                 |          |
                 |          v
                 |     HUMAN Person 2: safe entry/return and resume PC
                 |
                 +--> DEMO: polling-readable input registers

EXISTING local instruction/data memories <--> EXISTING five-stage RV + MCycle
                                                      |
                         HUMAN Person 1: branch prediction / recovery
                         HUMAN Person 3: byte/halfword data path
                         HUMAN Person 3: performance event counters
                                                      |
                                      DEMO: adapted MMIO wrapper
                                                      |
                   +----------------------------------+-------------------+
                   |                                  |                   |
           Object/display registers             Debug outputs       Optional tones
                   |
           DEMO: sprites + VGA timing + HUD
                   |
                VGA monitor

DEMO RISC-V program runs on RV:
input handling -> gameplay update -> write object state and HUD -> repeat
~~~

The HUD uses counter values read by CPU software and written to display registers. The renderer does not fabricate CPU performance numbers.

## Starting repository and source evidence

Original workspace:
`C:/Users/USER/Desktop/Y4 S1/Computer Arch/Project/CG3207`

Snapshot inspected on 2026-10-28, Asia/Singapore. Git HEAD at inspection:
`4dafa7c87727d3aaffa8c86fe86bbd3a8ed549ee`

Paths below are repository-relative so this handoff remains portable:

| Source | What to inspect |
|---|---|
| `lab4/RV.v` | Current core, memory outputs, PC selection, forwarding muxes, MCycle launch |
| `lab4/HazardUnit.v` | Forwarding, load-use stalls, branch flushes, MCycle stalls |
| `lab4/MCycle.v` | Existing multiply/divide sequencing |
| `lab4/Pipline_Resgisters/{D,E,M,W}Register.v` | Pipeline metadata and enables; directory spelling is intentional |
| `lab4/lab4_pipeline.asm` | Existing pipeline/MCycle smoke test; retain as a regression reference |
| `lab4/AA_IROM.mem`, `lab4/AA_DMEM.mem` | Existing memory images; not the new game |
| `lab4/old/Decoder.v`, `ALU.v`, `RegFile.v`, `ProgramCounter.v`, `PC_Logic.v`, `Extend.v`, `Shifter.v` | Supporting modules; verify which copies the actual build uses |
| `lab4/old/Wrapper.v` | Earlier memory and MMIO integration; inspect before reusing |
| `lab4/old/TOP_Nexys4DDR.xdc` | Existing board constraints, including an old very slow divided CPU clock |
| `lab4/old/test_*.v` | Legacy tests; timing assumptions may not match current pipeline |

Observed facts:

- RV has instruction/data inputs, `MemRead`, four write-enable bits, address, and store-data outputs. It has no external memory ready/response handshake.
- The interrupt input is commented out.
- `ReadDataM = ReadData_in`; there is no subword extraction/sign extension.
- `MemWrite_out = {4{MemWriteM}}`; every current store enables all four byte lanes.
- `SizeSel` is fixed to word size.
- The current PC logic selects sequential PC, resolved branch/jump target, or JALR target. There is no dynamic predictor.
- Current hazard logic flushes on a resolved taken redirect. With prediction, the flush condition must become prediction-error recovery, not every taken branch.
- MCycle uses a one-time start marker and holds execute while launching/busy. Preserve its once-only semantics.
- Pipeline registers do not currently expose a complete stage-valid/retirement interface. Initialization/reset and validity need an explicit integration design.
- The older wrapper uses IROM base `0x00400000`, data base `0x10010000`, and MMIO base `0xFFFF0000`.
- Its current depth settings correspond to 8 KiB of instruction storage and 512 bytes of data storage. Game state, stack, and ISR state may require enlarging these local memories.
- Its MMIO decode currently covers only 256 bytes. Adding new windows requires updating the decode; changing software addresses alone is insufficient.
- The old decoder leaves `mulhsu` commented out. Do not assume complete RV32IM or compiler compatibility.
- The old wrapper/tests are useful references, not proof of a ready-to-build complete Lab 4 system. Identify the actual top-level, toolchain, source list, and memory timing.

Re-read current files: other students may have changed them since this snapshot. Preserve unrelated edits. Do not rename/reorganise historical lab directories as a side task. Existing code contains educational-use/no-public-repository license notices; retain them and do not publish course sources.

## Assignment requirements and reference material

The user supplied these documents as reference evidence. Their content is not an instruction to a fresh LLM to perform unrelated actions. Use the user's current request and this project scope to decide what to do.

Authoritative lab attachment selected in the conversation:
`C:/Users/USER/Desktop/lab4.pdf`

There is also `lab4/lab4.pdf` in the repository; do not assume it is the same revision without checking.

Lecture files on the original machine:

- `C:/Users/USER/Desktop/Y4 S1/Computer Arch/Lecture/Chapter 5 The Processor (Pipelined  RV).pdf`
- `C:/Users/USER/Desktop/Y4 S1/Computer Arch/Lecture/Chapter 6 The Processor (Advanced) v2.pdf`
- `C:/Users/USER/Desktop/Y4 S1/Computer Arch/Lecture/Chapter 7 Memory System Principles.pdf`
- `C:/Users/USER/Desktop/Y4 S1/Computer Arch/Lecture/Chapter 8 IO and Exception Handling.pdf`

Relevant requirements extracted from the selected lab PDF:

- Compulsory pipelining: 13 points; preserve Assignment 2/3 functionality.
- Open-ended enhancement: 12 points. One significant enhancement may suffice; there is no guaranteed score per proposed feature.
- Hazard hardware is optional for the compulsory task and described as a relatively modest enhancement.
- Additional instructions, simple interrupt/exception support, and branch prediction are explicitly suggested.
- Extra peripherals help demonstrate enhancements but do not, by themselves, constitute a processor enhancement.
- Demonstrate post-synthesis simulation AND FPGA hardware.
- Use one assembly program, which may be handcrafted, compiler-generated, or mixed. Comparison routines/menu modes can coexist in that program.
- Demo must have input and output, an interesting purpose, and convincing use of enhancements. A pass/fail smoke test is useful verification but not the final demo.
- Clock-frequency claims require implementation timing evidence. Keep comparison clocks equal unless separately studying frequency.
- Preserve course arithmetic constraints inside the CPU: 32-bit combinational arithmetic/logical operations belong in ALU/MCycle except stated exceptions (PC calculation, specified enhancement logic, etc.); do not introduce extra ALU adders casually. The lab permits operators on 32-bit values outside RV, for example wrapper address decoding, so this is not a ban on peripheral counters. The lab prohibits synthesizable variable multiplication using `*` in place of the required MCycle implementation. Constant arithmetic is allowed. Read the exact restrictions before changing arithmetic hardware.
- Simple interrupts need not implement the complete privileged RISC-V architecture.
- Initial halfword/word accesses must be aligned. The subword list contains an apparent `sbu` typo; the intended standard stores are `sb` and `sh`. There is no standard unsigned-byte store variant.
- Submission includes RTL/testbenches, software sources/assembly, demonstrated bitfiles, and 3-6 presentation slides. Verify the actual deadline/schedule separately; do not infer it from this handoff date.

Reference focus: Chapter 5 slides 21-37 for hazards; Chapter 6 slides 4-11 for prediction; Chapter 8 slides 17-23 for interrupt entry/return. Chapter 7 is background only because cache/memory enhancements were deliberately excluded.

Do not treat source presence as verification, or lecture simplifications as automatically correct implementation details. If choosing standard RISC-V CSRs/encodings, check their actual semantics rather than copying a simplified diagram.

## Parallel ownership

| Track | Accountable owner | Main responsibility |
|---|---|---|
| Prediction | Person 1 | Predictor, fetch metadata, execute validation, recovery requests, focused tests |
| Interrupts | Person 2 | Timer/button controller, safe entry/return, resume PC, central redirect integration |
| Subword + metrics | Person 3 | Subword datapath, counters, integration regression coordination |
| Demo | Separate demo LLM/chat, reviewed by team | Game software, VGA/sprites/HUD, input conditioning, wrapper/top-level, optional sound |

Workload is approximately balanced by giving Person 3 counters and integration verification in addition to the smaller subword feature. Each person still fixes and validates their own enhancement; Person 3 is not responsible for debugging everyone else's design.

### What the separate demo LLM owns

- RISC-V game logic and compact object data structures.
- Both polling and interrupt application paths using Person 2's agreed interface.
- ISR software prologue/epilogue drafted in consultation with Person 2; Person 2 owns correctness of the interrupt ABI.
- Packed-data fallback routines and enhanced routines using Person 3's exact load/store semantics.
- VGA timing, sprite/font rendering, score/health display, explosions, starfield, mode labels.
- Clean input levels/events; button synchronisation and debounce precede the CPU-side interrupt controller.
- MMIO wrapper/top-level wiring, software register definitions, memory images, and required board constraints.
- Display shadow/active state and safe frame-boundary updates, including coherent clock-domain crossing if CPU and pixel clocks differ.
- Counter display and deterministic replay/stress mode.
- Optional tone generator. It remains peripheral/demo work, not a claimed processor enhancement.

The demo LLM may use temporary register/software stubs while hardware is unavailable. Mark stubs clearly and do not report them as completed enhancements. Baseline game should run using word accesses, polling, and the existing no-prediction CPU before new modes are integrated.

## Shared interfaces: proposals to agree before integration

These are coordination proposals, not already implemented RTL or a frozen ABI. Keep isolated module work moving while exact integration choices are settled. Each owner should return a concrete interface table to the team/demo chat; do not independently invent incompatible versions.

1. **Stage validity and advance events.** Define validD/E/M/W, instruction advancement, bubble injection, and reset semantics (names may differ). A held instruction must not create repeated predictor updates, stores, interrupt entries, or retirement events. A real executed NOP counts as an instruction; an invalid pipeline bubble does not.
2. **One central PC/redirect controller.** Person 2 owns integration of reset, prediction, recovery, drain, entry, and return. Person 1 supplies predicted-PC and recovery requests. Do not build three conflicting PC muxes.
3. **Interrupt boundary.** Prefer asynchronous interrupt drain-to-empty, then entry. Older redirects must resolve before choosing the resume PC. Freezing fetch and replaying the same held instruction into decode is not draining.
4. **Memory timing.** Preserve the existing fixed-latency contract unless the integrated wrapper explicitly changes it. Synchronous block RAM cannot silently replace an asynchronous read with no pipeline adjustment.
5. **Counter events.** Person 1 emits branch-resolution/misprediction events; Person 2 emits entry/return/timestamps; all agree with Person 3 on valid retirement and cycle definitions.
6. **Return ABI.** A custom interrupt-return operation or equivalent simplified return is possible, but its encoding, state changes, saved PC, register preservation, and interrupt re-enable behaviour must be agreed before assembly is written. No assumption that CSR/mret exists.
7. **Mode changes.** Configure comparisons at a safe round boundary; clear/reset relevant state consistently.
8. **External signals.** Synchronise async inputs. Maintain independent display/audio timing when the CPU stalls. No display clock derived from an MCycle stall enable.

Suggested non-overlapping MMIO windows, subject to one team agreement:

| Window | Proposed purpose |
|---|---|
| `0xFFFF0000-0xFFFF00FF` | Existing legacy peripheral addresses; preserve used addresses |
| `0xFFFF0100-0xFFFF01FF` | Timer/interrupt control and event timestamps, Person 2 |
| `0xFFFF0200-0xFFFF02FF` | Performance control/snapshot/counters, Person 3 |
| `0xFFFF0300-0xFFFF03FF` | Game/display control, HUD, mode/capability values, demo |
| `0xFFFF0400-0xFFFF04FF` | Display-object register bank, demo; e.g. 16 slots of 16 bytes |
| `0xFFFF0500-0xFFFF05FF` | Optional sound control, demo |

Register offsets, access rights, byte-enable handling, clear/ack behaviour, and reset values are still to be specified. Keep display/control registers 32-bit initially; packed subword game state can live in data RAM. The wrapper currently decodes only the legacy window, so these proposals require real decoder changes. Share a single generated/header/include definition where practical.

## Verification, measurement, and integration

- Preserve the original smoke test; add small self-checking tests for each enhancement.
- Do not interpret legacy testbench timing assumptions as a specification of the new pipeline.
- First run the existing CPU regression and record actual commands/tools/results. If tools are missing, state what remains unverified.
- Build each isolated enhancement with a reproducible source manifest. Avoid compiling duplicate module names from lab2/lab3/lab4/old.
- Coordinate stage-valid changes early. Then integrate subword+metrics, prediction, and interrupts in small verified steps; exact merge order may change if documented.
- Test prediction+interrupt, subword+interrupt, and all features with MCycle. Add wrong-path and interrupted-store sentinels.
- Start VGA/game integration early with the baseline CPU; do not wait for all enhancements.
- Preserve the same game update interval in comparison modes. Faster execution creates headroom, not faster enemy motion.
- Use deterministic seeds/input replay for performance comparisons. Compare equal work and identical final game state.
- Measure cycles per update, conditional branches/mispredictions, interrupt service latency, and missed update deadlines.
- Count conditional branch predictions separately from jump redirects. State whether ISR work is included in each measurement.
- A pending bit can coalesce repeated events; use a timer tick count or defined overrun mechanism if measuring missed deadlines.
- Compare polling against interrupts with the same input conditioning/event latches and documented polling cadence. Do not deliberately cripple polling or promise interrupts always win.
- Compare subword support against correct word/mask/shift software on the same packed layout. Keep interrupt/shared-data semantics equivalent.
- Do not turn off hazard handling and run unsafe code as a baseline. Use correctly padded software if demonstrating hazard-hardware benefit.
- Do not fabricate speedups through busy waits. VGA refresh caps displayed FPS; cycles per game update are usually a better metric.
- Synthesis and implementation timing must be checked after integration; the old slow clock constraint is not a performance target.
- Keep explicit records of RTL simulation, post-synthesis simulation, timing/resource reports, and board results. Unrun checks remain unrun.

## Expectations for this fresh LLM chat and the student

This chat supports the student identified at the top of this file. The student's workstream remains human-owned. Help explain the design, inspect code, develop tests, review reasoning, and debug. If the student asks you to implement code, do so within the agreed ownership and explain the result; do not silently take over every enhancement or the demo.

The student must understand and be able to explain the datapath/control changes, corner cases, verification evidence, and measured results. LLM-generated code alone is not the deliverable. The team should follow any course policy on AI assistance; this handoff makes no claim about that policy.

Do not assume access to the original chat, another student's private chat, the board, or the PDFs. This document is sufficient to understand the plan; verify available source before implementation. If files are missing, ask for only the files needed for the immediate step. Local paths may differ on another machine.

Do not message other chats, spawn agents, publish code, or create new tasks just because parallel work is described here. Coordination is through the humans unless separately authorised.

First response/work session should:
1. Identify your student's workstream and restate its boundary briefly.
2. Inspect the current source and instructions in that checkout; distinguish snapshot facts from changed files.
3. Identify the actual simulator/Vivado source set and run or describe the baseline regression.
4. Present the smallest concrete module/interface design and any unresolved cross-team decisions.
5. Continue independent design/tests while humans coordinate shared contracts.
6. Finish with exact changed files, validation performed, remaining uncertainties, and what other owners need to receive.

After meaningful work, update the local handoff with completed changes, frozen ABI decisions, commands/results, and remaining tasks. Do not leave future chats guessing whether a proposal became implemented code.


## Your workstream in detail

You own **byte/halfword memory operations** and **honest performance measurement**, and coordinate the shared regression runs. This is deliberately a larger package than just enabling sb/lbu, to balance workload with prediction and interrupts.

You coordinate integration verification, but each other student remains responsible for correcting their own feature. Do not rewrite their predictor/interrupt implementation without agreement.

### Deliverables

- lb, lbu, lh, lhu, sb, sh support, preserving existing lw/sw behaviour.
- Size/sign/offset pipeline metadata and correct load-result forwarding.
- Byte-write enables and aligned store-data generation.
- A small performance counter/snapshot interface.
- Counter event contracts shared with Persons 1/2.
- Focused subword tests plus a reproducible combined regression source list.
- Software data-layout/fallback specifications for the demo LLM.

### Subword implementation requirements

The starting core currently forwards ReadData_in without formatting and asserts all four byte enables for stores. The old wrapper already has byte-column writing logic, but verify it is selected and connected correctly.

Carry the relevant funct3/size/sign and low address bits with the instruction into the stage where formatting occurs. Prefer formatting a captured word in W if that matches the pipeline timing; ensure ResultW and all W forwarding paths receive the final extended value.

Use little-endian word lanes unless the verified baseline says otherwise:

| Operation | Aligned address offset | Expected effect |
|---|---|---|
| lb/lbu | 0,1,2,3 | Select addressed byte; sign/zero extend respectively |
| lh/lhu | 0 or 2 | Select addressed halfword; sign/zero extend respectively |
| sb | 0,1,2,3 | Enable exactly one byte lane; put rs2[7:0] in that lane |
| sh | 0 or 2 | Enable exactly two adjacent lanes; place rs2[15:0] there |
| lw/sw | 0 | Existing full-word behaviour |

For byte offset 2, sb should use mask 0100 with its byte in bits 23:16. For halfword offset 2, sh should use mask 1100 with its halfword in bits 31:16. Untouched memory bytes must remain unchanged.

Stores are not signed/unsigned variants. Do not implement an invented sbu instruction.

Only aligned halfword/word accesses are required initially. Define and test what unsupported misaligned accesses do; do not silently wrap across a word or introduce an unrequested exception architecture. Automated split accesses are out of scope.

### Forwarding and pipeline hazards

- A load result must be correctly sign/zero extended before consumers receive it.
- Audit E-stage load forwarding: the M-stage ALU value is the load address, not the loaded data.
- Preserve load-use stalling and W-to-E/W-to-D bypass.
- Existing load-to-store forwarding uses ResultW in M. Apply subword store alignment after selecting the correct forwarded store value.
- Extend lw-to-sw fast-path assumptions carefully to lb/lh followed by sb/sh/sw; verify source dependency guards.
- Store base-address dependencies still need normal hazards even when store-data forwarding is available.
- Hold/flush size and offset metadata with its instruction; a flushed byte store must not enable a memory/MMIO lane.
- Cooperate with Person 2 on validity and once-only store execution.
- Do not make a general memory wait-state/cache redesign for this feature.

### Counter and event design

Proposed minimum counters:

| Metric | Definition to agree |
|---|---|
| Cycles | CPU clock cycles while measurement is enabled; include or exclude paused time explicitly |
| Retired instructions | One valid architecturally completed instruction, including stores/branches/NOPs; not just RegWriteW |
| Conditional branches | Once per valid resolved conditional branch |
| Conditional mispredictions | Wrong predicted next PC for a counted conditional branch |
| Load-use stall cycles | Cycles with this stall cause; define overlap with MCycle stalls |
| MCycle stall cycles | Cycles stalled for launch/busy; distinguish this from an instruction count |
| IRQ entries | Once per actual handler entry |
| Latency samples | Explicit event-to-entry or event-to-software-marker definition |

Person 1 supplies branch/misprediction events. Person 2 supplies entry/return and event timestamps. Jointly design valid completion/retirement with both, because the core currently lacks a full retirement interface.

A branch/store must not disappear from retired-instruction totals merely because RegWrite is false. A held stage must not count repeatedly. Wrong-path instructions and invalid bubbles do not count. Document handling of any synchronous fault if one is later added.

Use a simple enable/clear/snapshot interface. A frozen snapshot allows software to read multiple metrics consistently. Choose counter width and overflow behaviour explicitly; 32-bit counters with bounded measurement intervals are sufficient initially. Counters are MMIO peripherals, not an assertion that standard cycle/instret CSRs are implemented. Likewise, the existing module named MCycle is a multiply/divide unit, not a cycle CSR.

Game updates and deadline misses can be software-maintained statistics. Do not infer missed ticks from a single pending bit; coordinate the timebase/overrun semantics with Person 2.

### Required tests

1. All four byte lanes with 00, 7F, 80, FF values.
2. Both halfword positions with 0000, 7FFF, 8000, FFFF.
3. sb/sh preserve neighbouring byte sentinels.
4. lw/sw remain unchanged.
5. Immediate load consumers in ALU, branch, address generation, and stores.
6. lb/lbu/lh/lhu followed immediately by sb/sh/sw with matching source register.
7. Base-address hazards independently of store-data hazards.
8. Flush/reset/interrupt while subword metadata is in flight.
9. MMIO byte-enable handling: no accidental neighbouring register effects.
10. Misaligned input follows the agreed unsupported-access policy.
11. Hand-counted short instruction traces match cycles/retired/branch counts.
12. Stall and misprediction tests do not double-count or count wrong-path work.
13. Snapshot, clear, enable, rollover, and reset semantics.
14. All features together with interrupts and MCycle under deterministic replay.

### Demo data and comparison contract

Suggest compact object state such as unsigned-byte health/type, signed-byte small velocity increments, and aligned halfword coordinates/timers. Share exact field offsets, alignment, and signedness with the demo LLM; do not silently impose a layout on existing software.

The application should have both:
- enhanced direct subword access; and
- correct lw/sw plus mask/shift/extract/merge fallback on the same packed layout.

Use all implemented operation types in meaningful code if claiming they are demonstrated. For example, signed velocity uses lb, unsigned health uses lbu, signed halfword velocity/timer delta can use lh if the design actually needs it, and positive coordinates can use lhu. Do not add pointless operations just to inflate coverage; explain any instructions verified in tests but not exercised by the main game.

A read-modify-write fallback can have different atomicity from sb/sh. Keep benchmark data private to the main loop or use equivalent exclusion in both modes. Never manufacture a speed comparison by allowing the baseline to corrupt shared state.

The demo LLM displays snapshots and cycles per game update. It cannot invent the metric values or equate raw clock speed with useful work.

### Integration coordination

- Establish a reproducible compile/source list and exclude duplicate legacy module definitions.
- Record baseline regression, isolated feature regressions, pairwise combinations, then all features.
- Agree common valid metadata with Person 2 early; account for Person 1's prediction metadata.
- Coordinate minimal patches to RV/Decoder/pipeline registers, rather than letting every branch replace whole files.
- Check source/program-memory sizes, software stack, handler region, and exported memory images.
- Work with demo LLM on wrapper address decode and software include/header consistency.
- Record post-synthesis simulation, implementation timing/resource reports, and board checks without claiming unrun stages passed.
- Each feature owner investigates their own failures; preserve a clear failing test and result.

### What you owe the other tracks

- Person 1: branch counter event requirements and snapshot semantics.
- Person 2: stage-valid/completion requirements, MMIO byte enables, IRQ timestamp/counter needs.
- Demo LLM: subword semantics, packed-layout agreement, counter registers, software comparison rules.
- Team: source manifest, regression matrix, measured resource/timing evidence, and outstanding integration issues.

### Suggested first useful session

Start by testing load formatting and store masks as small combinational blocks, then integrate size/offset metadata through the current pipeline. Prove dependent-load/store forwarding before adding counters. Draft the once-only event/valid contract in parallel with Persons 1/2.

### Definition of done

- [ ] All six subword instructions and existing word accesses pass directed tests.
- [ ] Sign/zero extension, byte lanes, and neighbouring bytes are correct.
- [ ] Forwarded subword results and load-to-store sequences are correct.
- [ ] Unsupported misalignment behaviour is explicit.
- [ ] Counters match short hand-counted traces and consistent snapshots.
- [ ] Game fallback and enhanced routines operate on equivalent data correctly.
- [ ] Combined regression matrix and source manifest are reproducible.
- [ ] Simulation, post-synthesis, timing, and board evidence are separately recorded.
- [ ] Student can explain datapath changes, measurement definitions, and limitations.

