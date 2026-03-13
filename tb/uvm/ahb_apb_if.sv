interface ahb_apb_if(input logic Hclk);
  logic        Hresetn;
  logic        Hwrite;
  logic        Hreadyin;
  logic [1:0]  Htrans;
  logic [31:0] Hwdata;
  logic [31:0] Haddr;
  logic [31:0] Hrdata;
  logic [1:0]  Hresp;
  logic        Hreadyout;

  logic [31:0] Prdata;
  logic [31:0] Pwdata;
  logic [31:0] Paddr;
  logic [3:0]  Pselx;
  logic        Pwrite;
  logic        Penable;

  task automatic init_signals();
    Hwrite   <= 1'b0;
    Hreadyin <= 1'b1;
    Htrans   <= 2'b00;
    Hwdata   <= '0;
    Haddr    <= '0;
    Prdata   <= '0;
  endtask
endinterface
