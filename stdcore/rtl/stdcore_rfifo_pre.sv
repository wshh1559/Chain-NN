/*
    NAME:
        stdcore_rfifo_pre.v
        
    DESCRIPTION:
        
    NOTES:
        
    TO DO:
        
    AUTHOR:
        Dajiang Zhou
        
	REVISION HISTORY:
        11.07.13    Revised from uhv_rfifo_ar.v
        11.11.18    Revised from stdcore_rfifoar.v
        12.03.08    Added "c_" so that c will keep the lastest valid value
        12.04.09    "c" is not registered output
        14.05.22    Val/Rdy handshake
        14.08.17    Renamed to stdcore_rfifo_pre (for separating PRE support)
        
*/

`timescale 1ns/1ps

module stdcore_rfifo_pre
#(parameter           DW = 1,
                      DEPTH = 1,
                      PRE = 0,
                      AW = 9     // enlarge me if DEPTH > 512 - 2
)
(
  
  clk,
  arst_n,
  rst_n,
  
  p,
  p_val,
  p_rdy,
  p_prdy,
  
  c,
  c_val,
  c_rdy
  
);




input               clk;
input               arst_n;
input               rst_n;

input   [DW-1:0]    p;
input               p_val;
output              p_prdy;
output              p_rdy;

output  [DW-1:0]    c;
output              c_val;
input               c_rdy;

reg     [DW-1:0]    mem [0:DEPTH-1];
reg     [AW-1:0]    ptp;
reg     [AW-1:0]    ptc, ptc_;
reg     [AW-1:0]    ptc_p1;
reg     [AW-1:0]    st;
reg     [AW-1:0]    st_;

reg                 c_val;
reg                 p_rdy, p_prdy;

reg     [DW-1:0]    c;


wire                p_we, c_we;

assign p_we = p_val && p_rdy;
assign c_we = c_val && c_rdy;

always @ (*) begin
  st_ = st + p_we - c_we;
  ptc_ = c_we ? ptc_p1 : ptc;
end

always @ (posedge clk or negedge arst_n)
  if(~arst_n) begin
    ptp <= #0.1 0;
    ptc <= #0.1 0;
    ptc_p1 <= #0.1 1;
    st <= #0.1 0;
    c_val <= #0.1 0;
    p_rdy <= #0.1 0; p_prdy <= #0.1 0;
    c <= #0.1 0;
  end
  else
  if(~rst_n) begin
    ptp <= #0.1 0;
    ptc <= #0.1 0;
    ptc_p1 <= #0.1 1;
    st <= #0.1 0;
    c_val <= #0.1 0;
    p_rdy <= #0.1 0; p_prdy <= #0.1 0;
    c <= #0.1 0;
  end
  else begin
    if(p_we)
      ptp <= #0.1 (ptp == DEPTH-1) ? 0 : (ptp + 1);
    ptc <= #0.1 ptc_;
    ptc_p1 <= #0.1 c_we ? ((ptc_p1 == DEPTH-1) ? 0 : (ptc_p1 + 1)) : ptc_p1;
    st <= #0.1 st_;
    c_val <= #0.1 st_ != 0;
    p_prdy <= #0.1 st_ < (DEPTH - PRE);
	p_rdy <= #0.1 st_ < (DEPTH);
    if(st_ != 0)
      //c <= #0.1 (p_we && ((st == 1 && c_we) || (st == 0 && !c_we))) ? p : (c_we ? mem[ptc_p1] : mem[ptc]);//mem[ptc_];
      c <= #0.1 (p_we && (st - c_we == 0)) ? p : mem[ptc_];
  end

always @ (posedge clk)
  if(p_we) begin
    mem[ptp] <= #0.1 p;
  end


endmodule



