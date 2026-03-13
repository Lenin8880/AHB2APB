module Bridge_Top (
    input  logic        Hclk,
    input  logic        Hresetn,
    input  logic        Hwrite,
    input  logic        Hreadyin,
    input  logic [1:0]  Htrans,
    input  logic [31:0] Hwdata,
    input  logic [31:0] Haddr,
    output logic [31:0] Hrdata,
    output logic [1:0]  Hresp,
    output logic        Hreadyout,
    input  logic [31:0] Prdata,
    output logic [31:0] Pwdata,
    output logic [31:0] Paddr,
    output logic [3:0]  Pselx,
    output logic        Pwrite,
    output logic        Penable
);

  typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_t;
  state_t state;

  logic [31:0] haddr_lat;
  logic [31:0] hwdata_lat;
  logic        hwrite_lat;
  logic [3:0]  psel_dec;
  logic [31:0] hrdata_lat;
  logic        addr_err;

  function automatic logic [3:0] decode_psel(input logic [31:0] addr);
    case (addr[15:12])
      4'h0: decode_psel = 4'b0001;
      4'h1: decode_psel = 4'b0010;
      4'h2: decode_psel = 4'b0100;
      4'h3: decode_psel = 4'b1000;
      default: decode_psel = 4'b0000;
    endcase
  endfunction

  always_ff @(posedge Hclk or negedge Hresetn) begin
    if (!Hresetn) begin
      state     <= IDLE;
      haddr_lat <= '0;
      hwdata_lat<= '0;
      hwrite_lat<= 1'b0;
      psel_dec  <= '0;
      addr_err  <= 1'b0;
      hrdata_lat<= '0;
    end else begin
      case (state)
        IDLE: begin
          if (Hreadyin && Htrans[1]) begin
            haddr_lat  <= Haddr;
            hwdata_lat <= Hwdata;
            hwrite_lat <= Hwrite;
            psel_dec   <= decode_psel(Haddr);
            addr_err   <= (decode_psel(Haddr) == 4'b0000);
            state      <= SETUP;
          end
        end
        SETUP: begin
          state <= ACCESS;
        end
        ACCESS: begin
          hrdata_lat <= Prdata;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

  always_comb begin
    Hreadyout = 1'b1;
    Hresp     = 2'b00;
    Paddr     = haddr_lat;
    Pwdata    = hwdata_lat;
    Pwrite    = hwrite_lat;
    Pselx     = 4'b0000;
    Penable   = 1'b0;
    Hrdata    = hrdata_lat;

    case (state)
      IDLE: begin
        Hreadyout = 1'b1;
      end
      SETUP: begin
        Hreadyout = 1'b0;
        Pselx     = psel_dec;
        Penable   = 1'b0;
      end
      ACCESS: begin
        Hreadyout = 1'b0;
        Pselx     = psel_dec;
        Penable   = 1'b1;
      end
      default: ;
    endcase

    if (state != IDLE && addr_err) begin
      Hresp = 2'b01;
    end
  end

endmodule
