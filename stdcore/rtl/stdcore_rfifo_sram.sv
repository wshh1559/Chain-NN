/*
    NAME:
        stdcore_rfifo_sram.v
        
    DESCRIPTION:
        
    NOTES:
        
    TO DO:
        
    AUTHOR:
        Shihao Wang
        
	REVISION HISTORY:
        16.03.28    initial
        
*/

`timescale 1ns/1ps

module stdcore_rfifo_sram
#(parameter DW = 16,
            DEPTH = 4,    // DEPTH == 2**AW
            AW = 16)
(
  
  pclk,
  cclk,
  arst_n,
  rst_n,
  
  p,
  p_val,
  p_rdy,
  
  c,
  c_val,
  c_rdy
  
);

//parameter           DW = 1;
//parameter           DEPTH = 1;
//parameter           PRE = 0;    // Must be 0
//parameter           AW = 9;     // enlarge me if DEPTH > 512 - 2


input               pclk;
input               cclk;
input               arst_n;
input               rst_n;

input           [DW-1:0]    p;
input                       p_val;
output  logic               p_rdy;

output  logic   [DW-1:0]    c;
output  logic               c_val;
input                       c_rdy;

logic               sram_rd;
logic               s_val, s_rdy;
logic   [AW-1:0]    waddr, raddr, st, st_;
logic   [DW-1:0]    rdata;
assign  st_ = st + (p_val&p_rdy) - (sram_rd & s_rdy);


always_ff@(posedge cclk or negedge arst_n)
if(!arst_n) begin
  waddr     <= 'b0;
  raddr     <= 'b0;
  p_rdy     <= 'b0;
  sram_rd   <= 'b0;
  s_val     <= 'b0;
  st        <= 'b0;
end else if(!rst_n) begin
  waddr     <= 'b0;
  raddr     <= 'b0;
  p_rdy     <= 'b0;
  sram_rd   <= 'b0;
  s_val     <= 'b0;
  st        <= 'b0;
end else begin
  if(waddr + (p_val && p_rdy) == DEPTH)
    waddr <= 0;
  else
    waddr <= waddr + (p_val && p_rdy);
  p_rdy <= (st_ < DEPTH-1);
  if(s_rdy) begin
    if(raddr + (sram_rd && s_rdy) == DEPTH)
      raddr <= 0;
    else 
      raddr <= raddr + (sram_rd && s_rdy);
    sram_rd   <= st_ != 0;
    s_val <= sram_rd;
  end
  
  st <= st_;
end

stdcore_2prf #(DW,AW,DEPTH) sram_buf_0(
  .wclk     (pclk),
  .wdata    (p),
  .waddr    (waddr),
  .we_n     (!(p_val&p_rdy)),

`ifdef SMIC40LL
  .arst_n   (arst_n),
  .rst_n    (rst_n),
`endif
  
  .rclk     (cclk),
  .rdata    (rdata),
  .raddr    (raddr),
  .re_n     (!(sram_rd&s_rdy))
);


stdcore_rfifo_pre #(DW,2,0,2)
urfifo_0(
  .clk      (cclk),
  .arst_n   (arst_n),
  .rst_n    (rst_n),

  .p        (rdata),
  .p_val    (s_val&s_rdy),
  .p_rdy    (),
  .p_prdy   (s_rdy),

  .c        (c),
  .c_val    (c_val),
  .c_rdy    (c_rdy)
  
);

endmodule



