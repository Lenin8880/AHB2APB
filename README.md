# AHB2APB Bridge — UVM Verification Environment

This repository now uses a reusable **SystemVerilog UVM testbench** for verifying `rtl/bridge_top.sv`.

## What changed

- Replaced the prior Python/cocotb `tb/` content with a UVM-based structure.
- Converted the original 4 checks into UVM tests:
  - `test_basic_write_read`
  - `test_invalid_address`
  - `test_back_to_back`
  - `test_hreadyin_gating`
- Added 2 additional regression tests:
  - `test_all_psel_windows`
  - `test_random_regression`
- Updated Makefile for multi-simulator usage (Questa, VCS, Xcelium).

## Testbench layout

```text
tb/
  tb.f                     # file list
  top_tb.sv                # UVM top and DUT hookup
  uvm/
    ahb_apb_if.sv          # testbench interface
    ahb_apb_pkg.sv         # agent/env/model/tests
```

## Running with EDA tools

### Questa (recommended default)

```bash
make regression SIM=questa
```

### Synopsys VCS

```bash
make regression SIM=vcs UVM_HOME=/path/to/uvm
```

### Cadence Xcelium

```bash
make regression SIM=xcelium UVM_HOME=/path/to/uvm
```

## Single-test execution

```bash
make run SIM=questa TEST=test_hreadyin_gating
```

## Notes for GitHub Codespaces / open-source setups

UVM class-based regression typically requires a full-featured simulator (Questa/VCS/Xcelium). In Codespaces, use a container image with one of these installed and licensed, then run the same Make targets.
