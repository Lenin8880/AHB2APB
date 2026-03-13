`timescale 1ns/1ps
module top_tb;
  import uvm_pkg::*;
  import ahb_apb_pkg::*;

  logic Hclk;
  ahb_apb_if vif(Hclk);

  Bridge_Top dut (
    .Hclk(vif.Hclk),
    .Hresetn(vif.Hresetn),
    .Hwrite(vif.Hwrite),
    .Hreadyin(vif.Hreadyin),
    .Htrans(vif.Htrans),
    .Hwdata(vif.Hwdata),
    .Haddr(vif.Haddr),
    .Hrdata(vif.Hrdata),
    .Hresp(vif.Hresp),
    .Hreadyout(vif.Hreadyout),
    .Prdata(vif.Prdata),
    .Pwdata(vif.Pwdata),
    .Paddr(vif.Paddr),
    .Pselx(vif.Pselx),
    .Pwrite(vif.Pwrite),
    .Penable(vif.Penable)
  );

  initial begin
    Hclk = 1'b0;
    forever #5 Hclk = ~Hclk;
  end

  initial begin
    uvm_config_db#(virtual ahb_apb_if)::set(null, "*", "vif", vif);
    run_test();
  end
endmodule
