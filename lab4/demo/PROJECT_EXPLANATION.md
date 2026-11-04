# Neon Space Defender: game, processor enhancements and performance

This guide explains the current implementation for group members preparing to demonstrate the project. It distinguishes what the hardware does, what the game exercises, and what the measurements establish.

## 1. What runs on our processor?

Neon Space Defender runs its gameplay on our five-stage RISC-V processor. The CPU executes `software/game.asm`, which handles player movement, shooting, collisions, enemy movement, waves, health and scoring.

Separate graphics hardware draws the game state published by the CPU. The processor performs the game calculations while the renderer continuously produces VGA pixels.

| Enhancement | Contribution |
|---|---|
| Subword instructions | Efficient access to small fields in packed game objects |
| Branch prediction | Fewer wasted cycles when executing repeated decisions and loops |
| Interrupt handling | Controlled servicing of timer and button events without corrupting ongoing execution |

The hardware performance monitor measures selected CPU activity so we can demonstrate effects rather than simply claim that the enhancements help.

Our team's main work is the processor and architectural enhancements. The assembly game, rendering, supporting demo integration and performance-monitor infrastructure are generated supporting work. This is a project-level ownership distinction, not a claim that every line of the CPU was written from scratch; the design also uses the supplied lab components.

## 2. How the complete game operates

```text
Physical buttons
      ↓
Synchronization and debouncing
      ↓
Input registers and event counters
      ↓
CPU executes game.asm
      ↓
Updates gameplay state in data RAM
      ↓
Writes object descriptions and HUD values to display registers
      ↓
Requests publication of the new display state
      ↓
Display registers publish it at vertical blank
      ↓
Renderer generates pixels from the published state
      ↓
VGA monitor
```

Game state and display state serve different purposes. Game state lives in data RAM and contains the information the CPU needs for gameplay. Display state contains the descriptions and statistics needed to draw the screen.

For example, when a bullet hits an enemy:

1. The CPU reads the bullet's and enemy's coordinates.
2. The assembly compares their positions to determine whether they overlap.
3. The CPU changes the bullet's active flag and the enemy's health.
4. If the enemy is destroyed, the CPU updates the score.
5. The assembly publishes the resulting object descriptions.
6. The renderer draws the updated scene.

The renderer does not decide whether a collision occurred or award points.

### Main modules and their roles

Paths in this table are relative to `lab4/`.

| Module | Role in the game |
|---|---|
| `demo/rtl/NeonTop.v` | Connects board pins, generates the shared 25 MHz clock/reset, connects video modules and scans the seven-segment display |
| `demo/rtl/GameSoC.v` | Connects the CPU to instruction ROM, data RAM and memory-mapped peripherals |
| `RV.v` | Executes the assembly using the five-stage pipeline and integrated enhancements |
| `demo/rtl/GameInputs.v` | Synchronizes physical inputs and instantiates button debouncers |
| `ButtonDebouncer.v` | Produces stable held states and one-cycle press events |
| `Timer.v` | Produces periodic tick events and a readable cumulative tick count |
| `InterruptController.v` | Latches pending events, applies the enable mask and asserts IRQ |
| `IRQHandler.v` | Controls pipeline draining, interrupt entry and return inside the CPU |
| `BranchPredictor.v` | Predicts the next instruction address and learns resolved control flow |
| `Subword.v` | Extracts/extends loads and positions/masks stores in the Memory stage |
| `HazardUnit.v` | Controls dependency forwarding, stalls and misprediction flushes |
| `MCycle.v` | Performs multi-cycle multiplication and division |
| `demo/rtl/PerformanceCounters.v` | Counts CPU cycles/events and exposes coherent snapshots |
| `demo/rtl/DisplayRegisters.v` | Holds shadow display state and publishes it at vertical blank |
| `demo/rtl/VgaTiming.v` | Generates pixel coordinates, visibility, synchronization and frame-boundary signals |
| `demo/rtl/GameRenderer.v` | Calculates pixel colours from published object/HUD state |
| `demo/rtl/Font5x7.v` | Supplies character glyphs for displayed text |

The CPU accesses peripherals using ordinary loads and stores to memory-mapped addresses. There are no special “draw spaceship” ISA instructions.

## 3. How the processor executes the game

| Pipeline stage | Role |
|---|---|
| Fetch | Reads the next instruction from instruction ROM |
| Decode | Identifies the operation and reads register operands |
| Execute | Performs arithmetic, calculates addresses or resolves branches |
| Memory | Accesses game RAM or memory-mapped peripherals |
| Writeback | Writes a result back to the register file when required |

The hazard unit maintains correctness when instructions depend on earlier results. It forwards results where possible and stalls when necessary.

The multi-cycle unit handles multiplication and division. For example, the demo uses division when calculating averages and converting values for display. Display formatting happens outside the main performance measurement window.

These mechanisms work together: an interrupt must respect an unfinished multi-cycle operation, a branch misprediction must flush younger instructions, and a subword load must participate correctly in dependency handling.

## 4. Enhancement switches

The switches select real execution modes. These are implemented comparisons, not predicted results.

| Switch | OFF | ON |
|---|---|---|
| SW0: branch prediction | Fetch uses sequential `PC + 4` prediction | Fetch uses the predictor's proposed next PC |
| SW1: interrupts | Main program polls timer information | Timer/fire interrupt sources are enabled and the handler is used |
| SW2: subwords | Software accesses packed fields using word operations, shifts and masks | Software uses direct byte/halfword instructions |
| SW3: replay | Interactive play | Deterministic replay |

Set the switches and press **BTND/reset** to apply the configuration. The mode is captured at reset. **BTNU** restarts a round; it does not recapture the mode switches. SW5:4 select difficulty and should be held constant during comparisons.

The switches change how existing hardware is used. They do not remove hardware from the FPGA. For example, disabling prediction bypasses the predicted fetch address; the predictor's table can still train.

## 5. Subword enhancement: efficient access to compact objects

### Record layout

Enemy and bullet arrays use eight-byte records:

| Field | Size | Meaning |
|---|---:|---|
| X position | 2 bytes | Horizontal coordinate |
| Y position | 2 bytes | Vertical coordinate |
| Health / active | 1 byte | Enemy health or whether a bullet is active |
| Horizontal velocity | 1 byte | Signed movement value |
| Kind | 1 byte | Object-kind field |
| Reserved | 1 byte | Reserved space |
| **Total** | **8 bytes** | |

Not every field is used by every object type. The reserved field is a **byte**, not a bit. This is the enemy/bullet record layout; the player and global variables are stored separately.

Four enemies and four bullet slots occupy:

```text
8 records × 8 bytes = 64 bytes
```

This is the size of those arrays, not the entire game's memory usage.

### Instructions used

```asm
lhu    # Load an unsigned 16-bit coordinate
lbu    # Load an unsigned 8-bit health/active value
lb     # Load a signed 8-bit horizontal velocity
sh     # Store a 16-bit coordinate
sb     # Store an 8-bit field
```

A halfword is 16 bits and a byte is 8 bits. A half-byte would be 4 bits; that is not this enhancement.

### Load data flow

```text
Assembly requests a byte or halfword
      ↓
CPU calculates its address
      ↓
RAM returns the containing 32-bit word
      ↓
Subword.v selects the requested bytes
      ↓
Sign extension or zero extension produces a 32-bit result
      ↓
Result reaches Writeback and a CPU register
```

Sign extension matters for velocity: a negative eight-bit velocity must become the corresponding negative 32-bit value. Coordinates and health use zero extension.

### Store data flow

```text
CPU provides address and field value
      ↓
Subword.v positions the value in the correct byte lanes
      ↓
Subword.v generates WriteMask
      ↓
RAM updates only those bytes
```

Updating one field therefore preserves neighbouring fields.

### What happens with SW2 off?

The assembly still uses the same eight-byte records. Its fallback macros emulate each access using ordinary word instructions:

- A load reads the containing word, shifts the field into position, and masks or sign-extends it.
- A store reads the containing word, clears the old field, merges in the new value, and writes the word back.

For example, a word can contain both coordinates:

```text
Byte offset:       0       1       2       3
                 ┌───────────────┬───────────────┐
                 │ X: 16 bits    │ Y: 16 bits    │
                 └───────────────┴───────────────┘
```

Reading Y with direct access uses `lhu destination, 2(base)`. Conceptually, the fallback loads the full word and shifts it right by 16 bits. The actual general-purpose fallback macro also calculates alignment and field position.

Packing and subword support are separate:

- **Packing determines how much space the data occupies.**
- **Subword instructions determine how efficiently the CPU accesses the packed data.**

Both modes use the same 64-byte enemy/bullet arrays. Turning SW2 on does not reduce allocated RAM or change the record layout.

Subword support also does not reduce physical shifting/masking hardware. It adds dedicated access logic that avoids executing a longer software sequence on the general CPU datapath. Because both modes are compiled into the comparison firmware, this switch is not a demonstration of a smaller program image either.

**Explanation to use:**

> Our game uses compact records because most object fields do not need 32 bits. The subword enhancement allows the processor to access those fields directly. We keep the layout identical in both modes and measure the instructions and cycles saved by replacing software extraction and merging with hardware byte and halfword accesses.

## 6. Branch prediction: keeping useful instructions moving

The game repeatedly asks:

- Is this bullet active?
- Has it left the play area?
- Does it overlap an enemy?
- Does the enemy still have health?
- Has an enemy reached a movement boundary?
- Are there more objects to process?
- Have all enemies been destroyed?

These become conditional branches in the assembly.

### Static sites versus runtime branches

The reviewed source contains:

| Region | Explicit conditional branch sites |
|---|---:|
| `update_game` | 31 |
| Checksum routine | 3 |
| Whole program, outside macro definitions | 58 |

There are also 33 subword macro invocation sites across the program. Each expands to an additional conditional branch selecting the access mode; 23 are inside `update_game`.

These are source-site counts, not a disassembly audit of a particular bitstream. A branch inside a loop executes repeatedly, so runtime counts are much larger. The documented 120-update replay executed **17,241 conditional branches within the measured windows**. That includes measured checksum and mode-selection work, not only gameplay decisions.

### Predictor operation

The predictor has 32 entries. Each stores an instruction-address tag, a predicted target, a jump indicator and a two-bit conditional-branch counter.

At Fetch, it looks up the current PC and proposes a next address. A matching jump entry predicts its target; a matching conditional entry uses the counter to decide whether to predict the target. Otherwise fetch proceeds sequentially.

In Execute, the CPU determines the actual outcome and next PC:

```text
Fetch:
Look up current PC → predict next PC → continue fetching

Execute:
Resolve branch → calculate actual next PC
                      ↓
        Compare actual PC with prediction
                      ↓
Correct: continue
Wrong: redirect fetch and flush younger instructions
                      ↓
Update predictor information
```

The two-bit counter saturates toward taken or not taken based on observed outcomes. Repeated loops often have a learnable pattern: the loop branch is taken repeatedly and then not taken at the end.

Prediction does not remove the game's decisions or reduce the useful instruction count. It reduces cycles spent recovering from incorrect fetch choices.

**Explanation to use:**

> With prediction enabled, the same workload retired the same number of instructions but completed in fewer cycles and experienced fewer conditional-branch misses.

The predictor also supports jumps, but the branch/miss performance counters specifically count conditional branches, not every control-flow change. Their miss definition is a mismatch between predicted and actual next PC.

## 7. Interrupt enhancement: events without corrupting execution

### Sources and request generation

| Source | Event |
|---|---|
| Timer | Normally approximately 60 events per second |
| Fire button | One event per accepted, debounced press |

`InterruptController.v` remembers events in pending bits and applies an enable mask. If an enabled event is pending, it asserts IRQ.

### Safe entry

Inside the CPU, `IRQHandler.v` manages entry:

```text
Peripheral event
      ↓
InterruptController records pending request
      ↓
IRQ asserted
      ↓
CPU stops admitting new instructions
      ↓
Previously admitted instructions finish
      ↓
Pipeline and multi-cycle unit become empty
      ↓
Save resume address
      ↓
Redirect execution to interrupt vector at 0x00400100
```

Draining matters because an event may arrive during a dependency stall, a memory operation or multiply/divide. The CPU must preserve already-admitted work.

### Handler and return

The assembly handler:

1. Saves the temporary registers it will modify.
2. Reads the timer tick count and fire-press sequence.
3. Records those values in RAM.
4. Acknowledges pending interrupt sources.
5. Restores the temporary registers and stack pointer.
6. Executes the project's interrupt-return instruction.

The CPU restores the saved execution address and continues. Nested interrupt entry is suppressed while handling the current interrupt.

The firmware uses the project's supported `uret` encoding. This is a custom, limited interrupt mechanism, not a complete standard RISC-V privileged architecture.

Gameplay updates remain in the main program. The handler records and acknowledges events; it does not perform collision detection or rendering.

### What the comparison demonstrates

- Polling mode reads the hardware timer count.
- Interrupt mode reads tick information published by the handler.
- Both modes use the common hardware fire-press sequence in the main loop. Preserving short fire presses is therefore not an IRQ-exclusive benefit.

The current interrupt mode still waits in a software loop. Do not claim that it eliminates all polling, saves power, or necessarily reduces cycles per update.

Its demonstrated contribution is **correct event servicing and safe interruption/resumption**. IRQ latency separately measures request-to-accepted-entry time, including pipeline draining. It does not measure physical button-to-response time or include the entire handler execution.

The documented 600-update enhanced simulation recorded **601 interrupt entries across the run**. This demonstrates repeated servicing, not 601 measured speed improvements. Multiple pending sources can be serviced together, and repeated events can coalesce in pending bits, so event and entry counts need not match.

**Explanation to use:**

> Interrupts let hardware notify the CPU of events. Our drain-and-return mechanism preserves correct execution even when an event arrives during a multi-cycle operation or pipeline hazard. We demonstrate successful servicing and measure entry latency separately from game-update speed.

## 8. How performance is measured

The monitor observes hardware activity rather than estimating cost from source-code length.

| Counter | Definition |
|---|---|
| Cycles | Clock cycles in the enabled window |
| Retired instructions | Valid instructions reaching Writeback, including branches and stores |
| Conditional branches | Valid conditional branches resolving in Execute |
| Conditional misses | Those branches whose actual next PC differs from the prediction |
| Load stalls | Decode-stall cycles excluding MCycle stalls |
| MCycle stalls | Multiply/divide stall cycles, including launch |
| Interrupt entries / returns | Accepted entry/return events inside the window |

Counters operate in parallel. One cycle can count retirement, a branch and a miss simultaneously. Bubbles are excluded using stage-valid signals; stalled Execute instructions are excluded from repeated branch counting.

### Measurement window

The assembly writes `3` to `0xFFFF0200` to clear and enable counters, then writes `4` to snapshot and stop:

```text
Clear and enable counters
      ↓
Update gameplay
      ↓
Increment completed-update count
      ↓
Calculate gameplay checksum
      ↓
Snapshot and stop counters
      ↓
Read snapshots and accumulate totals
      ↓
Format and publish the HUD
```

Waiting, input preparation, HUD formatting and display publication are outside the window. An interrupt handler overlapping the window contributes to its measured cost.

All counters are snapshotted together. Software can read the values using several loads without mixing measurements from different times. Control-command cycles do not count. Counters are 32-bit and wrap on overflow.

The HUD shows integer averages of accumulated measured cycles and instructions per completed update, rather than only the latest update's values.

### Boundaries and interpretation

Counter control stores take effect in Memory, retirement is observed in Writeback, and branches are observed in Execute. Instructions overlap these boundaries. These are hardware measurement windows, not exact counts of only the instructions textually inside one function. Using the same boundaries in every mode supports consistent comparison.

The counter RTL and existing testbench have been inspected. The peripheral test includes hand-counted events, enable/disable, snapshot stability, priority and overflow checks. Those tests were not rerun as part of preparing this explanation; Icarus was not available on the current PATH during the review.

## 9. Demonstrating a fair comparison

1. Select deterministic replay with SW3.
2. Keep difficulty and replay length identical.
3. Change one enhancement at a time and reset to apply it.
4. Compare cycles, instructions and conditional misses.
5. Confirm that final gameplay checksums match and check for dropped update intervals.

Matching checksums provide evidence that the modes produced the same final gameplay state. They are a useful check, not a proof of every intermediate operation.

For branch prediction, hold subword mode fixed. For subword access, hold prediction fixed. Keep interrupt mode fixed when isolating either effect.

## 10. Recorded measurements and supported claims

These are previously documented **simulation measurements** from `TESTING.md` for the 120-update replay. They are not fresh board measurements or a certification that a particular stored bitstream matches the reviewed source.

| Configuration | Cycles | Retired instructions | Conditional branches | Conditional misses |
|---|---:|---:|---:|---:|
| Prediction off, subword fallback | 139,974 | 106,186 | 17,241 | 12,765 |
| Prediction on, subword fallback | 123,924 | 106,186 | 17,241 | 4,838 |
| Prediction off, direct subwords | 96,672 | 68,399 | 17,241 | 6,663 |
| Prediction on, direct subwords | 80,410 | 68,399 | 17,241 | 3,255 |

Percentage reduction is calculated as:

```text
100 × (baseline − enhanced) / baseline
```

Supported conclusions:

- **Prediction alone:** 11.5% fewer cycles with unchanged retired instruction count, and 62.1% fewer conditional misses.
- **Subwords alone:** 35.6% fewer retired instructions and 30.9% fewer cycles.
- **Both together:** 42.6% fewer measured cycles.
- **Interrupts:** demonstrate servicing, safe entry/return and latency separately. The update-window measurements do not establish an interrupt speedup.

The subword change also changes the executed instruction path, so its miss count can change even with prediction bypassed. The clean predictor comparison holds subword mode fixed.

Polling and IRQ modes had the same update-window measurements in this documented replay. That does not establish identical whole-program overhead: most waiting and event servicing can happen outside the measured window.

VGA refresh is fixed and gameplay is timer-paced. The appropriate claim is **less CPU work for the same game update**, leaving more time before the next update deadline. Do not describe the cycle reduction as an increase in VGA FPS or a measured speedup of the entire program.

## 11. Quick answers for presentation questions

| Question | Answer |
|---|---|
| Does the CPU actually run the game? | Yes. Assembly handles movement, collisions, scoring and waves; hardware renders the published state. |
| Are the enhancement switches real? | Yes. Set them and reset; the program and fetch logic use the captured mode. |
| Does SW2 reduce RAM usage? | No. Both modes use the same packed layout. It reduces the software work needed to access it. |
| Why is packing useful? | Small fields share words instead of each requiring a separate 32-bit slot. Subword instructions make those fields efficient to access. |
| Does subword support remove masking hardware? | No. Dedicated load/store logic replaces a longer sequence of software operations. |
| Why can prediction save cycles without saving instructions? | It reduces wrong-path execution and recovery while preserving the useful instruction sequence. |
| Are all jumps included in the branch-miss number? | No. This monitor counts conditional-branch next-PC misses. |
| Do interrupts make this replay faster? | The current update-window results do not establish that. Demonstrate event handling, safe return and entry latency. |
| Does IRQ mode eliminate busy waiting? | No. This implementation still waits in a software loop. |
| Does 42.6% fewer cycles mean 42.6% more FPS? | No. It measures CPU work in update/checksum windows; VGA refresh remains fixed. |

## Source references

- [Game assembly](software/game.asm)
- [CPU and event definitions](../RV.v)
- [Subword unit](../Subword.v)
- [Branch predictor](../BranchPredictor.v)
- [Interrupt controller](../InterruptController.v)
- [CPU interrupt handler control](../IRQHandler.v)
- [GameSoC and memory-mapped integration](rtl/GameSoC.v)
- [Performance counters](rtl/PerformanceCounters.v)
- [Counter and peripheral tests](tests/test_peripherals.v)
- [Testing documentation and recorded results](TESTING.md)
