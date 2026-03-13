.PHONY: help compile run regression clean

SIM ?= questa
TEST ?= test_basic_write_read
TB_TOP ?= top_tb
TB_DIR := tb
RTL_DIR := rtl
FILELIST := $(TB_DIR)/tb.f

# Set UVM_HOME for simulators that do not preload UVM (VCS/Xcelium)
UVM_HOME ?=

help:
	@echo "AHB2APB UVM Verification"
	@echo "  make compile SIM=questa|vcs|xcelium"
	@echo "  make run TEST=<uvm_test_name> SIM=questa|vcs|xcelium"
	@echo "  make regression SIM=questa|vcs|xcelium"
	@echo "  make clean"
	@echo ""
	@echo "Regression tests:"
	@echo "  test_basic_write_read"
	@echo "  test_invalid_address"
	@echo "  test_back_to_back"
	@echo "  test_hreadyin_gating"
	@echo "  test_all_psel_windows"
	@echo "  test_random_regression"

compile:
ifeq ($(SIM),questa)
	vlib work
	vlog -sv -f $(FILELIST)
else ifeq ($(SIM),vcs)
	@if [ -z "$(UVM_HOME)" ]; then echo "Set UVM_HOME for VCS flow"; exit 1; fi
	vcs -sverilog -ntb_opts uvm -full64 -timescale=1ns/1ps \
		+incdir+$(TB_DIR)/uvm +incdir+$(UVM_HOME)/src \
		$(UVM_HOME)/src/uvm_pkg.sv -f $(FILELIST) -l vcs_compile.log -o simv
else ifeq ($(SIM),xcelium)
	@if [ -z "$(UVM_HOME)" ]; then echo "Set UVM_HOME for Xcelium flow"; exit 1; fi
	xrun -64bit -sv -timescale 1ns/1ps -uvm \
		+incdir+$(TB_DIR)/uvm +incdir+$(UVM_HOME)/src \
		-f $(FILELIST) -elaborate -l xrun_compile.log
else
	@echo "Unsupported SIM=$(SIM). Use questa, vcs, or xcelium."; exit 1
endif

run: compile
ifeq ($(SIM),questa)
	vsim -c $(TB_TOP) +UVM_TESTNAME=$(TEST) -do "run -all; quit -f" -l questa_run.log
else ifeq ($(SIM),vcs)
	./simv +UVM_TESTNAME=$(TEST) -l vcs_run.log
else ifeq ($(SIM),xcelium)
	xrun -64bit -R +UVM_TESTNAME=$(TEST) -l xrun_run.log
endif

regression: compile
	@for t in test_basic_write_read test_invalid_address test_back_to_back test_hreadyin_gating test_all_psel_windows test_random_regression; do \
		echo "Running $$t"; \
		$(MAKE) run SIM=$(SIM) TEST=$$t || exit 1; \
	done

clean:
	rm -rf work transcript vsim.wlf *.log simv simv.daidir xrun.d xcelium.d INCA_libs ucli.key
