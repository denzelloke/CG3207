# Neon Space Defender handoff — Person 1: branch prediction and recovery

Self-contained handoff for a fresh LLM chat. Give that chat this file and access to the current repository. The other handoff files are not required to understand this one.

**Assigned role:** Person 1: branch prediction and recovery. Read the shared context and then your detailed workstream below. Do not assume ownership of the other students' tasks.

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

You own a **small dynamic branch predictor** that improves real game code while preserving architectural correctness. This is the main new performance enhancement in your track. The existing taken-branch flush mechanism is the baseline, not already a dynamic predictor.

### Deliverables

- Predictor RTL (suggested module name: BranchPredictor; name is a proposal).
- Fetch lookup and prediction metadata integration.
- Execute-stage validation/recovery interface to Person 2's central redirect controller.
- Correct once-per-instruction predictor training.
- Enable/bypass and reset behaviour for controlled comparisons.
- Focused self-checking predictor and CPU integration tests.
- A short explanation of tag/index/target/counter design and measured effects.

### Recommended first architecture

- Approximately 32 direct-mapped entries.
- Index from selected aligned PC bits; tag from remaining identifying bits.
- Valid bit, conditional-branch target, and two-bit saturating direction counter per entry.
- Valid/tag miss predicts sequential execution.
- Fetch chooses predicted target only for a valid matching entry whose direction predicts taken.
- Start by predicting conditional branches only. Handle JAL/JALR correctly through the existing resolution path; predicting them is optional later.
- Save the exact predicted next PC and relevant prediction metadata with the fetched instruction. Hold/flush it with that instruction.
- In E, compute actual next PC and compare against the recorded predicted next PC. Check wrong direction AND wrong target.
- The central controller redirects on a real mismatch and squashes younger wrong-path instructions before side effects.
- A correct predicted-taken conditional branch must not trigger the old unconditional taken-branch flush.
- Train only when the branch really resolves/advances; never repeatedly while MCycle or another stall holds E.
- If a stale/incorrect prediction reaches a nonbranch instruction, recover correctly; do not assume table lookup proves instruction type.
- Reset all valid bits. Define counter initial state and warm-up policy.
- Runtime bypass can force baseline sequential prediction while still retaining correct branch resolution.

Do not design a direction predictor without a target supply and call it a completed fetch predictor. Do not merely modify prediction statistics while leaving fetch/control behaviour unchanged.

### Proposed port/event contract

| Direction | Conceptual signal | Meaning |
|---|---|---|
| Input | fetch_pc | PC being considered for the next accepted instruction |
| Input | predictor_enable | Stable mode selected at a safe boundary |
| Output | predicted_next_pc | Sequential PC or predicted branch destination |
| Output | prediction_metadata | Lookup hit/taken information carried with the instruction |
| Input | resolve_fire | One pulse for the valid resolving instruction |
| Input | resolve_pc, actual_next_pc, actual_taken, conditional_branch | Training and validation data |
| Output | recover_valid, recover_pc | Request to the central controller; not another independent PC writer |
| Output | conditional_branch_event, conditional_mispredict_event | Once-only statistics to Person 3 |

Exact bus timing/port names must be agreed with Persons 2/3. Distinguish a lookup from an accepted fetch: a stalled fetch may be looked up repeatedly but is not multiple instructions.

### Integration hotspots

- RV.v currently computes PC_IN directly from PCSrcE; Person 2 will own the combined selector.
- HazardUnit currently uses RedirectE = nonzero PCSrcE, gated by MCycle stall. Replace the prediction-related flush trigger with a real recovery event while retaining baseline behaviour when prediction is bypassed.
- D/E pipeline registers must carry prediction data. Do not overwrite unrelated subword or validity changes.
- Existing load-use flushes and branch recovery can coincide. Define priorities and preserve the correct decode instruction when only a load-use stall occurs.
- Coordinate predictor lookup timing with instruction memory timing; do not add an unaccounted cycle.
- Person 2's drain must honour older branch corrections before interrupt entry/resume-PC selection.
- Document behaviour for predictor lookup/update to the same entry in a cycle.
- Preserve JAL/JALR link values and their actual target semantics.

### Required tests

1. Mostly-taken and mostly-not-taken branches; first encounter and loop exit.
2. A short loop with repeated re-entry, demonstrating two-bit hysteresis.
3. Alternating outcomes (correctness even if prediction accuracy is poor).
4. Two different PCs sharing an index, including a nonbranch fetch at a conflicting PC.
5. Correct direction with an incorrect target; recovery must still occur.
6. Wrong-path register write, store, and MMIO command must not execute.
7. Branch operands dependent on recent ALU/load results.
8. Branch adjacent to MCycle launch/busy/completion and load-use stalls.
9. JAL/JALR, including link-register consumers; predictor bypass mode.
10. Interrupt requested during predicted flow and during misprediction recovery, with Person 2.
11. Once-only counter/training pulses when E or F is held.
12. Reset, table invalidation, and safe mode changes.

Use a sequential architectural reference or expected register/memory trace where practical. A good prediction rate is not evidence of correct execution.

### Demo contract and proof

Give the demo LLM the enable/control interface and metric definitions, not a promised speedup. Request a deterministic wave with repeated enemy/bullet loops and meaningful collision branches. Compare the same update workload, clock, initial state, and branch warm-up policy. Record total cycles, resolved conditional branches, mispredictions, and final game state.

Person 3 supplies counter MMIO/snapshots. The demo LLM displays cycles/update and mispredictions and provides the same replay in both modes. Never ask the demo LLM to slow the baseline artificially.

### What you owe the other tracks

- Person 2: recovery signal semantics, prediction timing, stage metadata, and drain interaction requirements.
- Person 3: once-only branch/misprediction pulses and predictor-control requirements.
- Demo LLM: how to select/reset modes, how to interpret metrics, and a suitable deterministic workload.
- Team: source list, tests/commands/results, timing impact, and known limitations.

### Suggested first useful session

Inspect current control flow and baseline tests, then specify a small standalone predictor with a self-checking table test. Integrate with prediction bypass available. First prove architectural equivalence; measure performance only after wrong-path effects and recovery are correct.

### Definition of done

- [ ] Standalone predictor tests pass.
- [ ] Baseline pipeline/MCycle regression still passes.
- [ ] Prediction-enabled execution has identical expected architectural results.
- [ ] Correct predictions actually avoid the relevant flushes.
- [ ] Wrong predictions and stale targets recover without side effects.
- [ ] Prediction updates/statistics fire once per instruction.
- [ ] Combined interrupt/subword tests pass with the other owners.
- [ ] Simulation, post-synthesis, timing, and board evidence are separately recorded.
- [ ] Student can explain the predictor and the measured game comparison.

