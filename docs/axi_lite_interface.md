# AXI-Lite Slave Interface Specification

This document details the AXI-Lite Slave interface, channel handshake protocols, and internal state machine transaction sequences implemented in [`axi_lite_slave.sv`](file:///c:/Users/Home/Downloads/PROJECTS/CHIP_IN/rtl/axi/axi_lite_slave.sv).

---

## 1. Interface Signal Groupings

| Channel | Signal Name | Width | Direction | Protocol Description |
| :--- | :--- | :---: | :---: | :--- |
| **Global** | `clk` | 1 | Input | Clock source |
| | `rst_n` | 1 | Input | Active-low asynchronous reset |
| **Write Address** | `s_axi_awaddr` | 32 | Input | Write address bus |
| | `s_axi_awvalid` | 1 | Input | Valid indicator from Master |
| | `s_axi_awready` | 1 | Output | Ready indicator from Slave |
| **Write Data** | `s_axi_wdata` | 32 | Input | Write data bus |
| | `s_axi_wvalid` | 1 | Input | Valid indicator from Master |
| | `s_axi_wready` | 1 | Output | Ready indicator from Slave |
| **Write Response**| `s_axi_bresp` | 2 | Output | Write response status (OKAY = `2'b00`) |
| | `s_axi_bvalid` | 1 | Output | Response valid indicator from Slave |
| | `s_axi_bready` | 1 | Input | Response ready handshake from Master |
| **Read Address** | `s_axi_araddr` | 32 | Input | Read address bus |
| | `s_axi_arvalid` | 1 | Input | Valid indicator from Master |
| | `s_axi_arready` | 1 | Output | Ready indicator from Slave |
| **Read Data** | `s_axi_rdata` | 32 | Output | Read data bus |
| | `s_axi_rresp` | 2 | Output | Read response status (OKAY = `2'b00`) |
| | `s_axi_rvalid` | 1 | Output | Read valid indicator from Slave |
| | `s_axi_rready` | 1 | Input | Read ready handshake from Master |

---

## 2. Write Transaction Finite State Machine (FSM)

The write channel FSM decouples address and data arrivals, allowing them to complete handshakes in any clock alignment.

```text
               +--------------+
               |   WR_IDLE    | <------------------------------------+
               +------+-------+                                      |
                      |                                              |
                      | s_axi_awvalid & s_axi_wvalid                 |
                      | (or captured previous cycles)                 |
                      v                                              |
               +--------------+                                      |
               |WR_WAIT_READY |                                      |
               +------+-------+                                      |
                      |                                              |
                      | ready (backend write commit)                 |
                      v                                              |
               +--------------+                                      |
               |   WR_RESP    |                                      |
               +------+-------+                                      |
                      |                                              |
                      | s_axi_bready & s_axi_bvalid                  |
                      +----------------------------------------------+
```

### State Transitions
1. **`WR_IDLE`**: Wait for `awvalid` and `wvalid`. Stores incoming address/data into `awaddr_reg` and `wdata_reg` registers. Once both address and data are captured, asserts `write_en` and transitions to `WR_WAIT_READY`.
2. **`WR_WAIT_READY`**: Waits for the memory controller to assert the `ready` handshake. Once `ready` is high:
   - Asserts `awready` and `wready` high to consume AXI inputs.
   - Resets internal capture registers.
   - Asserts `bvalid` response flag.
   - Transitions to `WR_RESP`.
3. **`WR_RESP`**: Asserts write status response `bresp = 2'b00` (OKAY) and waits for master's `bready` confirmation before returning to `WR_IDLE`.

---

## 3. Read Transaction Finite State Machine (FSM)

The read channel FSM manages memory read latency and guarantees serialization after active write transactions.

```text
               +--------------+
               |   RD_IDLE    | <------------------------------------+
               +------+-------+                                      |
                      |                                              |
                      | s_axi_arvalid & (wr_state == WR_IDLE)        |
                      v                                              |
               +--------------+                                      |
               |RD_WAIT_READY |                                      |
               +------+-------+                                      |
                      |                                              |
                      | ready (backend read data valid)              |
                      v                                              |
               +--------------+                                      |
               |   RD_RESP    |                                      |
               +------+-------+                                      |
                      |                                              |
                      | s_axi_rready & s_axi_rvalid                  |
                      +----------------------------------------------+
```

### State Transitions
1. **`RD_IDLE`**: Waits for `arvalid`. Transmits `read_en` to memory controller and captures address to `araddr_reg` ONLY if there is no active write transaction (`wr_state == WR_IDLE` and `write_en == 0`). Transitions to `RD_WAIT_READY`.
2. **`RD_WAIT_READY`**: Waits for backend `ready`. Once `ready` is high, samples data into `s_axi_rdata`, asserts `s_axi_arready` (handshake complete), asserts `s_axi_rvalid`, and transitions to `RD_RESP`.
3. **`RD_RESP`**: Maintains read response `rresp = 2'b00` (OKAY) and `rdata` until the master asserts `rready`, then returns to `RD_IDLE`.
