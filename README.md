# PLIC (RISC-V Platform-Level Interrupt Controller)

Compatible with RISC-V PLIC Specification version 1.0.0 (Ratified), March 11, 2023 .

A parametrizable, modular, and pipelined RISC-V Platform-Level Interrupt Controller (PLIC) implementation Designed for seamless integration into multi context SoC architectures.

This implementation supports configurable interrupt sources, contexts, priority levels, and both edge-sensitive and level-sensitive interrupt gateways, adhering to the standard RISC-V PLIC memory map.

---

## Features

- **Parametrizable Architecture**: Configurable number of interrupt sources (`NUM_SOURCES`), contexts (`NUM_CONTEXTS`), and priority width (`PRIORITY_WIDTH`).

- **Edge & Level Sensitivity**: Per source configurability for level sensitive or rising edge sensitive interrupts via the `EDGE_MASK` parameter.

- **Pipelined Arbiter**: Optimized to break the critical path in large scale configurations by grouping sources and pipelining the first stage of priority comparison.

- **Standard Memory Map**: Fully compatible with the standard RISC-V PLIC specification memory map layout.

---

## Synthesis

This core has been verified with post-synthesis simulation and synthesized using open-source tools:

| Tool | Purpose |
|------|---------|
| **Slang** | SystemVerilog linting/elaboration |
| **Yosys/Slang** | Logic synthesis |

---

## Parameters

| Parameter | Type | Description |
| :--- | :---: | :--- |
| `NUM_SOURCES` | `int` | Total number of external interrupt sources (Source 0 is reserved by the RISC-V spec). |
| `NUM_CONTEXTS` | `int` | Number of interrupt contexts (e.g., M-mode and S-mode harts). |
| `PRIORITY_WIDTH` | `int` | Width of the priority value for each interrupt source |
| `EDGE_MASK` | `bit [NUM_SOURCES-1:0]`| Bitmask configuring each source as edge-sensitive (`1`) or level-sensitive (`0`). |

---

## Memory Map

The PLIC registers are memory-mapped. Below is the address decoding layout:

| Address Range | Register | Access | Description |
| :--- | :--- | :---: | :--- |
| `0x0000_0004` – `0x0000_0FFC` | Priority | R/W | 32-bit priority register per source (offset = `source_id * 4`). Source 0 is reserved. |
| `0x0000_1000` – `0x0000_107C` | Pending | R/O | Read-only bit array indicating pending interrupts (32 sources per 32-bit word). |
| `0x0000_2000` – `0x001F_1FFC` | Enable | R/W | Interrupt enable bits per context. Stride of `0x80` bytes per context. |
| `0x0020_0000` + `(c << 12)` + `0x000` | Threshold | R/W | Priority threshold for context `c`. Interrupts ≤ this value are masked. |
| `0x0020_0000` + `(c << 12)` + `0x004` | Claim/Complete | R/W | **Read**: Claims the highest priority pending interrupt ID. **Write**: Completes the specified interrupt ID. |

> **Note:** Context `c` ranges from `0` to `NUM_CONTEXTS - 1`. The stride between contexts in the Threshold/Claim region is `4 KiB` (`0x1000`).

---
## Ports

| Port Name | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | System clock. |
| `rst` | Input | 1 | Asynchronous active-high reset. |
| `irq_i` | Input | `NUM_SOURCES` | Raw interrupt signals from external peripherals. |
| `irq_o` | Output | `NUM_CONTEXTS` | Asserted interrupt request to each respective context. |
| `readRequest` | Input | 1 | Asserted during a valid memory-mapped read transaction. |
| `writeRequest` | Input | 1 | Asserted during a valid memory-mapped write transaction. |
| `address` | Input | 32 | Memory-mapped byte address. |
| `dataIn` | Input | 32 | Write data bus. |
| `dataOut` | Output | 32 | Read data bus. |

---

# Software Integration

For a comprehensive guide, C macros, and complete bare-metal integration examples, please refer to the software documentation:

**[Software Integration Guide](doc/software.md)**