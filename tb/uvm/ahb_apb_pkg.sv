package ahb_apb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class ahb_apb_seq_item extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;
    rand int unsigned stall_cycles;

    bit [1:0]  resp;
    bit [31:0] rdata;
    bit        stall_ok;

    `uvm_object_utils_begin(ahb_apb_seq_item)
      `uvm_field_int(addr, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(write, UVM_ALL_ON)
      `uvm_field_int(stall_cycles, UVM_ALL_ON)
      `uvm_field_int(resp, UVM_ALL_ON)
      `uvm_field_int(rdata, UVM_ALL_ON)
      `uvm_field_int(stall_ok, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_stall { stall_cycles inside {[0:5]}; }

    function new(string name = "ahb_apb_seq_item");
      super.new(name);
    endfunction
  endclass


  class ahb_apb_single_seq extends uvm_sequence #(ahb_apb_seq_item);
    `uvm_object_utils(ahb_apb_single_seq)
    ahb_apb_seq_item req_h;
    ahb_apb_seq_item rsp_h;

    function new(string name = "ahb_apb_single_seq");
      super.new(name);
    endfunction

    virtual task body();
      start_item(req_h);
      finish_item(req_h);
      get_response(rsp_h);
    endtask
  endclass

  class ahb_apb_sequencer extends uvm_sequencer #(ahb_apb_seq_item);
    `uvm_component_utils(ahb_apb_sequencer)
    function new(string name = "ahb_apb_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
  endclass

  class ahb_apb_driver extends uvm_driver #(ahb_apb_seq_item);
    `uvm_component_utils(ahb_apb_driver)
    virtual ahb_apb_if vif;

    function new(string name = "ahb_apb_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function bit is_valid_addr(bit [31:0] addr);
      return (addr[15:12] inside {4'h0,4'h1,4'h2,4'h3});
    endfunction

    task run_phase(uvm_phase phase);
      ahb_apb_seq_item req, rsp;
      forever begin
        seq_item_port.get_next_item(req);
        drive_item(req, rsp);
        seq_item_port.item_done();
        seq_item_port.put_response(rsp);
      end
    endtask

    task drive_item(ahb_apb_seq_item req, output ahb_apb_seq_item rsp);
      rsp = ahb_apb_seq_item::type_id::create("rsp");
      rsp.copy(req);
      rsp.stall_ok = 1'b1;

      for (int i = 0; i < req.stall_cycles; i++) begin
        @(posedge vif.Hclk);
        vif.Hreadyin <= 1'b0;
        vif.Haddr    <= req.addr;
        vif.Hwrite   <= req.write;
        vif.Hwdata   <= req.data;
        vif.Htrans   <= 2'b10;
        if (vif.Pselx !== 4'b0000)
          rsp.stall_ok = 1'b0;
      end

      @(posedge vif.Hclk);
      vif.Hreadyin <= 1'b1;
      vif.Haddr    <= req.addr;
      vif.Hwrite   <= req.write;
      vif.Hwdata   <= req.data;
      vif.Htrans   <= 2'b10;

      @(posedge vif.Hclk);
      vif.Htrans   <= 2'b00;
      vif.Hwrite   <= 1'b0;

      while (vif.Hreadyout !== 1'b1)
        @(posedge vif.Hclk);

      rsp.resp  = vif.Hresp;
      rsp.rdata = vif.Hrdata;

      if (is_valid_addr(req.addr) && (rsp.resp != 2'b00))
        `uvm_error(get_type_name(), $sformatf("Unexpected ERROR for valid addr 0x%08h", req.addr))
      if (!is_valid_addr(req.addr) && (rsp.resp != 2'b01))
        `uvm_error(get_type_name(), $sformatf("Expected ERROR for invalid addr 0x%08h", req.addr))
    endtask
  endclass

  class apb_responder extends uvm_component;
    `uvm_component_utils(apb_responder)
    virtual ahb_apb_if vif;
    bit [31:0] mem [bit[31:0]];

    function new(string name = "apb_responder", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.Hclk);
        if (!vif.Hresetn) begin
          mem.delete();
          vif.Prdata <= '0;
        end else begin
          if ((vif.Pselx != 4'b0) && vif.Penable) begin
            if (vif.Pwrite)
              mem[vif.Paddr] = vif.Pwdata;
            else if (mem.exists(vif.Paddr))
              vif.Prdata <= mem[vif.Paddr];
            else
              vif.Prdata <= 32'h0;
          end else begin
            vif.Prdata <= 32'h0;
          end
        end
      end
    endtask
  endclass

  class ahb_apb_agent extends uvm_component;
    `uvm_component_utils(ahb_apb_agent)
    ahb_apb_sequencer seqr;
    ahb_apb_driver    drv;
    virtual ahb_apb_if vif;

    function new(string name = "ahb_apb_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      seqr = ahb_apb_sequencer::type_id::create("seqr", this);
      drv  = ahb_apb_driver::type_id::create("drv", this);
      if (!uvm_config_db#(virtual ahb_apb_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "Virtual interface not set")
      uvm_config_db#(virtual ahb_apb_if)::set(this, "drv", "vif", vif);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  class ahb_apb_env extends uvm_env;
    `uvm_component_utils(ahb_apb_env)
    ahb_apb_agent agent;
    apb_responder model;
    virtual ahb_apb_if vif;

    function new(string name = "ahb_apb_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ahb_apb_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "Virtual interface not set")
      uvm_config_db#(virtual ahb_apb_if)::set(this, "agent", "vif", vif);
      model = apb_responder::type_id::create("model", this);
      uvm_config_db#(virtual ahb_apb_if)::set(this, "model", "vif", vif);
      agent = ahb_apb_agent::type_id::create("agent", this);
    endfunction
  endclass

  class ahb_apb_base_test extends uvm_test;
    `uvm_component_utils(ahb_apb_base_test)
    ahb_apb_env env;
    virtual ahb_apb_if vif;

    function new(string name = "ahb_apb_base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ahb_apb_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "Virtual interface not set")
      uvm_config_db#(virtual ahb_apb_if)::set(this, "env", "vif", vif);
      env = ahb_apb_env::type_id::create("env", this);
    endfunction

    task reset_dut();
      vif.Hresetn <= 1'b0;
      vif.init_signals();
      repeat (3) @(posedge vif.Hclk);
      vif.Hresetn <= 1'b1;
      repeat (2) @(posedge vif.Hclk);
    endtask

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      reset_dut();
      phase.drop_objection(this);
    endtask

    task automatic issue_txn(input bit [31:0] addr,
                             input bit write,
                             input bit [31:0] data,
                             input int stall_cycles,
                             output ahb_apb_seq_item rsp);
      ahb_apb_single_seq seq;
      seq = ahb_apb_single_seq::type_id::create("seq");
      seq.req_h = ahb_apb_seq_item::type_id::create("req_h");
      seq.req_h.addr = addr;
      seq.req_h.write = write;
      seq.req_h.data = data;
      seq.req_h.stall_cycles = stall_cycles;
      seq.start(env.agent.seqr);
      rsp = seq.rsp_h;
    endtask
  endclass

  class test_basic_write_read extends ahb_apb_base_test;
    `uvm_component_utils(test_basic_write_read)
    function new(string name="test_basic_write_read", uvm_component parent=null);
      super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
      ahb_apb_seq_item r1, r2;
      phase.raise_objection(this);
      reset_dut();
      issue_txn(32'h0000_0010, 1'b1, 32'hA5A5_1234, 0, r1);
      issue_txn(32'h0000_0010, 1'b0, 32'h0, 0, r2);
      if (r2.resp != 2'b00 || r2.rdata != 32'hA5A5_1234)
        `uvm_fatal(get_type_name(), $sformatf("Readback mismatch resp=%0h data=%08h", r2.resp, r2.rdata))
      phase.drop_objection(this);
    endtask
  endclass

  class test_invalid_address extends ahb_apb_base_test;
    `uvm_component_utils(test_invalid_address)
    function new(string name="test_invalid_address", uvm_component parent=null);
      super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
      ahb_apb_seq_item r;
      phase.raise_objection(this);
      reset_dut();
      issue_txn(32'hF000_0010, 1'b1, 32'hDEAD_BEEF, 0, r);
      if (r.resp != 2'b01)
        `uvm_fatal(get_type_name(), "Invalid address should return ERROR response")
      phase.drop_objection(this);
    endtask
  endclass

  class test_back_to_back extends ahb_apb_base_test;
    `uvm_component_utils(test_back_to_back)
    function new(string name="test_back_to_back", uvm_component parent=null);
      super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
      ahb_apb_seq_item r;
      bit [31:0] addr;
      bit [31:0] data;
      phase.raise_objection(this);
      reset_dut();
      for (int i=0; i<8; i++) begin
        addr = {16'h0, i[3:0], 12'h020};
        data = 32'h1000_0000 + i;
        issue_txn(addr, 1'b1, data, 0, r);
        issue_txn(addr, 1'b0, 32'h0, 0, r);
        if (r.rdata != data)
          `uvm_fatal(get_type_name(), $sformatf("Back2back mismatch i=%0d", i))
      end
      phase.drop_objection(this);
    endtask
  endclass

  class test_hreadyin_gating extends ahb_apb_base_test;
    `uvm_component_utils(test_hreadyin_gating)
    function new(string name="test_hreadyin_gating", uvm_component parent=null);
      super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
      ahb_apb_seq_item r;
      phase.raise_objection(this);
      reset_dut();
      issue_txn(32'h0000_0020, 1'b1, 32'hCAFE_BABE, 3, r);
      if (!r.stall_ok)
        `uvm_fatal(get_type_name(), "Bridge started APB transaction while Hreadyin=0")
      issue_txn(32'h0000_0020, 1'b0, 32'h0, 0, r);
      if (r.rdata != 32'hCAFE_BABE)
        `uvm_fatal(get_type_name(), "Hreadyin gating test readback failed")
      phase.drop_objection(this);
    endtask
  endclass

  class test_all_psel_windows extends ahb_apb_base_test;
    `uvm_component_utils(test_all_psel_windows)
    function new(string name="test_all_psel_windows", uvm_component parent=null);
      super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
      ahb_apb_seq_item r;
      bit [31:0] data;
      phase.raise_objection(this);
      reset_dut();
      for (int sel = 0; sel < 4; sel++) begin
        data = 32'hAB00_0000 + sel;
        issue_txn({16'h0, sel[3:0], 12'h044}, 1'b1, data, 0, r);
        issue_txn({16'h0, sel[3:0], 12'h044}, 1'b0, 32'h0, 0, r);
        if (r.rdata != data)
          `uvm_fatal(get_type_name(), $sformatf("PSEL window %0d data mismatch", sel))
      end
      phase.drop_objection(this);
    endtask
  endclass

  class test_random_regression extends ahb_apb_base_test;
    `uvm_component_utils(test_random_regression)
    function new(string name="test_random_regression", uvm_component parent=null);
      super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
      ahb_apb_seq_item r;
      bit [31:0] exp_mem [bit[31:0]];
      bit [31:0] addr;
      bit [31:0] data;
      bit write;
      phase.raise_objection(this);
      reset_dut();
      for (int i=0; i<30; i++) begin
        addr = {$urandom_range(0,3), 12'h0A0};
        data = $urandom;
        write = $urandom_range(0,1);
        if (write) begin
          issue_txn(addr, 1'b1, data, $urandom_range(0,2), r);
          exp_mem[addr] = data;
        end else begin
          issue_txn(addr, 1'b0, 32'h0, $urandom_range(0,2), r);
          if (exp_mem.exists(addr) && r.rdata != exp_mem[addr])
            `uvm_fatal(get_type_name(), "Random regression read mismatch")
        end
      end
      phase.drop_objection(this);
    endtask
  endclass

endpackage
