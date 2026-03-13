import os
from pathlib import Path

from cocotb_test.simulator import run


def test_ahb2apb_regression():
    repo = Path(__file__).resolve().parents[1]
    rtl = repo / "rtl" / "bridge_top.sv"

    run(
        verilog_sources=[str(rtl)],
        toplevel="Bridge_Top",
        module="test_ahb2apb",
        sim=os.getenv("SIM", "iverilog"),
        waves=1,
        extra_env={"COCOTB_LOG_LEVEL": "INFO"},
    )
