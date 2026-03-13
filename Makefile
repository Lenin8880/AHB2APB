# Makefile for AHB2APB Bridge Verification
# Cocotb-based testbench with proper time precision

# Simulator configuration
SIM ?= iverilog
WAVES ?= 1

# Cocotb timing configuration - CRITICAL for precision
# Setting timescale to picoseconds (ps) for accurate nanosecond (ns) simulation
COCOTB_RESOLUTION = ps
COCOTB_TIMEUNIT = 1ps
COCOTB_TIMEPRECISION = 1ps

# Iverilog simulator flags for SystemVerilog support
EXTRA_ARGS ?= -g2009 -gspecify

# Top module
TOPLEVEL = Bridge_Top
TOPLEVEL_LANG = verilog

# Verilog source files
VERILOG_SOURCES += $(PWD)/ahb_apb_top.sv

# Testbench settings
MODULE = test_ahb2apb
TESTDIR = tb

# Python path for test discovery
export PYTHONPATH := $(PYTHONPATH):$(PWD)/tb

# Default target
.PHONY: all
all: test

# Run tests target
.PHONY: test
test: 
	COCOTB_RESOLUTION=$(COCOTB_RESOLUTION) \
	COCOTB_TIMEUNIT=$(COCOTB_TIMEUNIT) \
	COCOTB_TIMEPRECISION=$(COCOTB_TIMEPRECISION) \
	SIM=$(SIM) \
	WAVES=$(WAVES) \
	python -m pytest $(TESTDIR)/test_runner.py -v --tb=short

# Run with verbose logging
.PHONY: test-verbose
test-verbose:
	COCOTB_RESOLUTION=$(COCOTB_RESOLUTION) \
	COCOTB_TIMEUNIT=$(COCOTB_TIMEUNIT) \
	COCOTB_TIMEPRECISION=$(COCOTB_TIMEPRECISION) \
	COCOTB_LOG_LEVEL=DEBUG \
	SIM=$(SIM) \
	WAVES=$(WAVES) \
	python -m pytest $(TESTDIR)/test_runner.py -v -s

# Clean build artifacts
.PHONY: clean
clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name '*.pyc' -delete
	find . -type f -name '*.fst' -delete
	find . -type f -name '*.vvp' -delete
	rm -rf $(TESTDIR)/__pycache__
	rm -rf build/

.PHONY: help
help:
	@echo "AHB2APB Bridge Verification - Available Targets:"
	@echo "  make test          - Run all tests with standard logging"
	@echo "  make test-verbose  - Run tests with debug logging"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make help          - Show this help message"
	@echo ""
	@echo "Configuration Environment Variables:"
	@echo "  SIM=iverilog       - Simulator selection (default: iverilog)"
	@echo "  WAVES=1            - Enable waveform generation (default: 1)",