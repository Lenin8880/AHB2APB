# AHB2APB Bridge — Real-Time Verification Environment

This repository now includes a **deployable, runnable EDA verification environment** for an AHB2APB bridge with:

- Synthesizable bridge RTL (`rtl/bridge_top.sv`)
- Real-time cocotb verification with APB memory model (`tb/test_ahb2apb.py`)
- Automated regression (`pytest` + `cocotb-test`)
- CI pipeline (`.github/workflows/ci.yml`)
- Dockerized execution (`Dockerfile`, `docker-compose.yml`)

---

## 1) What this environment verifies

The testbench checks core protocol behavior and practical corner cases:

1. **Basic write/read correctness**
   - AHB write reaches APB
   - AHB read returns APB data
2. **Address decode and error handling**
   - Invalid APB window returns ERROR response (`Hresp=2'b01`)
3. **Back-to-back mixed traffic**
   - Burst-like sequential write/read patterns over all valid APB selects
4. **Input ready gating (`Hreadyin`)**
   - Bridge must not launch APB transaction while upstream is not ready

In each accepted transfer, the bridge inserts setup/access phases and drives APB handshake signals (`Pselx`, `Penable`, `Pwrite`, `Paddr`, `Pwdata`) consistently.

---

## 2) Quick start (native)

```bash
python -m pip install -r requirements.txt
make test
```

Verbose, real-time logs:

```bash
make test-verbose
# or
./scripts/run_live.sh
```

---

## 3) Quick start (Docker)

```bash
docker compose up --build
```

This makes it portable across software environments and CI runners without local EDA setup complexity.

---

## 4) Waveform debug flow

Regression produces simulator artifacts under `sim_build/`.

Open waveform with GTKWave:

```bash
gtkwave sim_build/*.vcd
```

Suggested debug signals:

- AHB side: `Htrans`, `Haddr`, `Hwrite`, `Hwdata`, `Hreadyin`, `Hreadyout`, `Hresp`, `Hrdata`
- APB side: `Pselx`, `Penable`, `Pwrite`, `Paddr`, `Pwdata`, `Prdata`

---

## 5) Project structure

```text
rtl/
  bridge_top.sv          # AHB2APB bridge RTL

 tb/
  test_ahb2apb.py        # cocotb tests + APB memory model
  test_runner.py         # pytest entry invoking simulator

scripts/
  run_live.sh            # real-time regression runner

.github/workflows/
  ci.yml                 # CI regression pipeline
```

---

## 6) Notes for hardware/firmware/software teams

- **Software validation**: use Docker or local Python + Icarus to run tests in any dev machine.
- **Firmware validation**: extend cocotb sequences to mirror register-level firmware flows.
- **Hardware validation**: replace `rtl/bridge_top.sv` with your implementation and keep tests to validate protocol compliance.

This creates a single verification language shared by hardware, firmware, and system teams.
