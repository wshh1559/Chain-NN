/*
    NAME:
        stdcore_rfifo.v
        
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
        14.08.17    Becomes a wrapper of stdcore_rfifo_pre which does not have the p_prdy port
        
*/

`timescale 1ns/1ps

module stdcore_rfifo
#(parameter DW = 1,
            DEPTH = 1,
            PRE = 0,
            AW = 9)
(
  
  clk,
  arst_n,
  rst_n,
  
  p,
  p_val,
  p_rdy,
  //p_prdy,
  
  c,
  c_val,
  c_rdy
  
);

//parameter           DW = 1;
//parameter           DEPTH = 1;
//parameter           PRE = 0;    // Must be 0
//parameter           AW = 9;     // enlarge me if DEPTH > 512 - 2


input               clk;
input               arst_n;
input               rst_n;

input   [DW-1:0]    p;
input               p_val;
//output              p_prdy;
output              p_rdy;

output  [DW-1:0]    c;
output              c_val;
input               c_rdy;

// synopsys translate_off
stdcore_rfifo_pre #(DW,DEPTH,PRE,AW) rfifo_pre(
  
  .clk(clk),
  .arst_n(arst_n),
  .rst_n(rst_n),
  
  .p(p),
  .p_val(p_val),
  .p_rdy(p_rdy),
  .p_prdy(),
  
  .c(c),
  .c_val(c_val),
  .c_rdy(c_rdy)
  
);


initial if(PRE!=0) begin $display("PRE must be 0 for stdcore_rfifo. Use stdcore_rfifo_pre if you need PRE>0!"); $stop; end
// synopsys translate_on

endmodule



