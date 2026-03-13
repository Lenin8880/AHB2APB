"""
AHB2APB Bridge Test Runner
Pytest-based test execution framework with proper Cocotb integration

This module orchestrates the execution of all testbenches with:
- Proper timing precision configuration
- Comprehensive environment setup
- Industry-standard test reporting
"""

import subprocess
import sys
import os
from pathlib import Path

# Configure logging
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
log = logging.getLogger(__name__)


class CocotbTestRunner:
    """Manages Cocotb simulation and test execution."""
    
    def __init__(self):
        """Initialize test runner with proper environment."""
        self.repo_root = Path(__file__).parent.parent
        self.test_dir = Path(__file__).parent
        self.build_dir = self.repo_root / "build"
        
        # Timing configuration for precision
        self.timing_config = {
            "COCOTB_RESOLUTION": "ps",      # Picosecond resolution
            "COCOTB_TIMEUNIT": "1ps",       # 1 picosecond unit
            "COCOTB_TIMEPRECISION": "1ps",  # 1 picosecond precision
            "COCOTB_LOG_LEVEL": "INFO",     # Standard logging level
        }
        
    def setup_environment(self):
        """Configure environment variables for Cocotb execution."""
        for key, value in self.timing_config.items():
            os.environ[key] = value
            log.info(f"Set {key}={{value}}")
    
    def run_tests(self, verbose=False, specific_test=None):
        """
        Execute the test suite.
        
        Args:
            verbose (bool): Enable verbose output
            specific_test (str): Run specific test by name
            
        Returns:
            int: Exit code (0 = success, non-zero = failure)
        """
        self.setup_environment()
        
        # Build pytest command
        cmd = [
            sys.executable,
            "-m",
            "pytest",
            str(self.test_dir / "test_runner.py::test_ahb2apb_regression"),
        ]
        
        if verbose:
            cmd.append("-v")
            cmd.append("-s")
        else:
            cmd.append("-v")
        
        cmd.append("--tb=short")
        
        log.info(f"Executing: {{' '.join(cmd)}}")
        log.info("=" * 70)
        
        result = subprocess.run(cmd, cwd=str(self.repo_root))
        
        log.info("=" * 70)
        if result.returncode == 0:
            log.info("✓ All tests PASSED")
        else:
            log.error("✗ Some tests FAILED")
        
        return result.returncode


def test_ahb2apb_regression():
    """
    Main pytest test function that invokes Cocotb testbench.
    
    This function:
    - Configures Cocotb with proper timing precision
    - Runs SystemVerilog simulation
    - Validates test results
    """
    import cocotb
    from cocotb.runner import get_runner
    
    log.info("Starting AHB2APB Bridge Regression Test Suite")
    log.info("-" * 70)
    
    # Get the runner
    runner = get_runner(sim_name="iverilog")
    
    # Set up environment with timing configuration
    extra_env = {
        "COCOTB_RESOLUTION": "ps",
        "COCOTB_TIMEUNIT": "1ps",
        "COCOTB_TIMEPRECISION": "1ps",
        "COCOTB_LOG_LEVEL": "INFO",
    }
    
    log.info("Cocotb Timing Configuration:")
    for key, value in extra_env.items():
        log.info(f"  {{key}} = {{value}}")
    
    # Build the testbench
    log.info("-" * 70)
    log.info("Building testbench...")
    
    runner.build(
        verilog_sources=[
            str(Path(__file__).parent.parent / "ahb_apb_top.sv"),
        ],
        vhdl_sources=[],
        includes=[str(Path(__file__).parent.parent)],
        extra_args=["-g2009", "-gspecify"],
        build_dir=str(Path(__file__).parent.parent / "build"),
        always=True,  # Always rebuild
    )
    
    log.info("✓ Build successful")
    
    # Run the tests
    log.info("-" * 70)
    log.info("Running simulation tests...")
    
    runner.test(
        test_module="test_ahb2apb",
        test_dir=str(Path(__file__).parent),
        waves=True,  # Enable waveform generation
        extra_env=extra_env,
    )
    
    log.info("✓ Simulation tests completed")
    log.info("-" * 70)
    log.info("Regression Test Suite Execution Summary")
    log.info("=" * 70)


if __name__ == "__main__":
    """Direct test runner execution."""
    runner = CocotbTestRunner()
    
    verbose_mode = "--verbose" in sys.argv or "-v" in sys.argv
    exit_code = runner.run_tests(verbose=verbose_mode)
    
    sys.exit(exit_code)