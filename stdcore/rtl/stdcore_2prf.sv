/*
    NAME:
        stdcore_2prf.v
        
    DESCRIPTION:
        
    NOTES:
        
    TO DO:
        
    AUTHOR:
        Dajiang Zhou
        
	REVISION HISTORY:
        11.07.07    Initial.
        
*/

`timescale 1ns/1ps

module stdcore_2prf
#(parameter     DW = 1,
                AW = 1,
                DEPTH = 1
)(
  
  wclk,
  wdata,
  waddr,
  we_n,
`ifdef SMIC40LL
  arst_n, 
  rst_n,
`endif
  
  rclk,
  rdata,
  raddr,
  re_n
  
);




input               wclk;
input   [DW-1:0]    wdata;
input   [AW-1:0]    waddr;
input               we_n;

`ifdef SMIC40LL
input               arst_n;
input               rst_n;
`endif
  
input               rclk;
output  [DW-1:0]    rdata;
input   [AW-1:0]    raddr;
input               re_n;

`ifdef SMIC40LL

`define RF2P(W,D,M,N) \
wire    [W-1:0] rdata_``N, wdata_``N; \
rf_2p_``W``x``D``m``M m``N (    \
  .QA           (rdata_``N),    \
  .DB           (wdata_``N),    \
  .CLKA         (rclk),         \
  .CENA         (re_n),         \
  .AA           (raddr),        \
  .CLKB         (wclk),         \
  .CENB         (we_n),         \
  .AB           (waddr),        \
  .EMAA         (3'd3),         \
  .EMASA         (1'd0),         \
  .EMAB         (3'd3),         \
  .RET1N        (1'b1),         \
  .COLLDISN     (1'b1)          \
); \
initial $display("INFO: SMIC40LL rf_2p_%0dx%0dm%0d instantiated as %m.m%0d",W,D,M,N);

`define RF2PB(W,D,M,N) \
wire    [W-1:0] rdata_``N, wdata_``N; \
rf_2p_``W``x``D``m``M``b m``N (    \
  .QA           (rdata_``N),    \
  .DB           (wdata_``N),    \
  .CLKA         (rclk),         \
  .CENA         (re_n),         \
  .AA           (raddr),        \
  .CLKB         (wclk),         \
  .CENB         (we_n),         \
  .WENB         (W'b0),         \
  .AB           (waddr),        \
  .EMAA         (3'd3),         \
  .EMASA         (1'd0),         \
  .EMAB         (3'd3),         \
  .RET1N        (1'b1),         \
  .COLLDISN     (1'b1)          \
); \
initial $display("INFO: SMIC40LL rf_2p_%0dx%0dm%0db instantiated as %m.m%0d",W,D,M,N);

`define SRDP(W,D,M,N) \
wire    [W-1:0] rdata_``N, wdata_``N; \
wire            en_``N; \
wire    [11:0]  raddr_``N, waddr_``N; \
dp_``W``x``D``m``M m``N (    \
  .QA           (rdata_``N),    \
  .DB           (wdata_``N),    \
  .CLKA         (rclk),         \
  .CENA         (re_n | en_``N),\
  .AA           (raddr_``N),    \
  .CLKB         (wclk),         \
  .CENB         (we_n | en_``N),\
  .AB           (waddr_``N),    \
  .EMAA         (3'd3),         \
  .EMAWA        (2'd1),         \
  .EMASA        (1'd0),         \
  .EMAB         (3'd3),         \
  .EMAWB        (2'd1),         \
  .EMASB        (1'd0),         \
  .RET1N        (1'b1),         \
  .COLLDISN     (1'b1),          \
  .QB           (),             \
  .DA           (W'b0),         \
  .WENA         (1'b1),         \
  .WENB         (1'b0),         \
  .TAA(), .TAB(), .TDA(), .TDB(), .TCENA(1'b1), .TCENB(1'b1), .TENA(1'b1), .TENB(1'b1), \
  .TWENA(1'b1), .TWENB(1'b1), .SEA(1'b0), .SEB(1'b0), .SIA(), .SIB(), .DFTRAMBYP(1'b0), \
  .CENYA(), .CENYB(), .WENYA(), .WENYB(), .AYA(), .AYB(), .SOA(), .SOB()    \
); \
initial $display("INFO: SMIC40LL dp_%0dx%0dm%0d instantiated as %m.m%0d",W,D,M,N);
  // TSMC28
  //.TWENA(1'b1), .TWENB(1'b1), .SEA(1'b0), .SEB(1'b0), .SIA(), .SIB(), .DFTRAMBYP(1'b0), \
  //.CENYA(), .CENYB(), .WENYA(), .WENYB(), .AYA(), .AYB(), .SOA(), .SOB()    \
  // TSMC40
  //.TWENA(1'b1), .TWENB(1'b1), .CENYA(), .CENYB(), .WENYA(), .WENYB(), .AYA(), .AYB(), \
  //.DYA(), .DYB(), .BENA(), .TQA(), .BENB(), .TQB(), .STOVA(), .STOVB() \
logic rd_sel;
always_ff@(posedge rclk or negedge arst_n)
if(!arst_n)         rd_sel <= 'b0;
else if(!rst_n)     rd_sel <= 'b0;
else                if(!re_n) rd_sel <= raddr[12];

`define SINGLE  assign                  wdata_0  = wdata; assign rdata =                  rdata_0 ;
`define DOUBLE  assign {        wdata_1,wdata_0} = wdata; assign rdata = {        rdata_1,rdata_0};
`define TRIPLE  assign {wdata_2,wdata_1,wdata_0} = wdata; assign rdata = {rdata_2,rdata_1,rdata_0};
`define DOUBLE_MUX assign wdata_1 = wdata; assign wdata_0 = wdata; assign rdata = rd_sel ? rdata_1 : rdata_0; \
        assign {en_0,en_1} = {(raddr[12] & waddr[12]), (!raddr[12] & !waddr[12])}; assign {raddr_0, raddr_1} = {raddr[11:0],raddr[11:0]}; assign {waddr_0, waddr_1} = {waddr[11:0],waddr[11:0]};

generate
  if (DW ==  16 && DEPTH ==  96)  begin `RF2P( 16, 96,1,0) `SINGLE end else
  if (DW ==  16 && DEPTH ==  256) begin `RF2P( 16,256,1,0) `SINGLE end else
`undef  RF2P
`undef  RF2PB
  if (DW == 16  && DEPTH == 8192) begin `SRDP(16,4096,16,0) `SRDP(16,4096,16,1) `DOUBLE_MUX end else
  //if (DW ==  10 && DEPTH == 1970) begin `SRDP(10,2048,8,0) `SINGLE end else
  //if (DW ==  95 && DEPTH == 2048) begin `SRDP(32,2048,8,0) `SRDP(32,2048,8,1) `SRDP(32,2048,8,2) `TRIPLE end else
  //if (DW ==  32 && DEPTH == 2048) begin `SRDP(32,2048,8,0) `SINGLE end else
`undef  SRDP
`undef  SINGLE
`undef  DOUBLE
`undef  TRIPLE
  begin: generic
`endif
//synopsys translate_off

reg		[DW-1:0]	rdata_reg;
reg		[DW-1:0]	mem [DEPTH-1:0];

assign  rdata = rdata_reg;

always @ (posedge wclk)
  if ( ~we_n ) begin
    mem[waddr] <= #1 wdata;
    if ( ~re_n && raddr == waddr ) $display("ERROR: R/W address conflict at %m @ %t", $time);
  end

always @ (posedge rclk)
  if ( ~re_n ) begin
    rdata_reg <= #1 mem[raddr];
  end

initial begin
	$display("INFO: stdcore_2prf_%0dx%0d created as %m", DW, DEPTH);
	if ( AW == 1 && DEPTH == 1)
		$display("INFO: parameters may not be properly defined for %m");
end

//synopsys translate_on
`ifdef SMIC40LL
  end
endgenerate
`endif




endmodule



