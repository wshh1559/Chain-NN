`timescale 1ns/1ps
module dcnn_mems
#(parameter DW = 32,
            AW = 32,
            PARA = 576,
            K_BITS = 4,
            MAX_PARA_OUT = 64,
            MAX_PARA_OUT_BIT = 7)
(
  clk,
  rst_n,
  arst_n,
  
  
  // input inner cache
  w_inner_vld,
  w_inner_rdy,
  w_inner_data,
  r_inner_vld,
  r_inner_rdy,
  r_inner_data,
  
  
  // row_info fifo
  row_info_w_vld,
  row_info_w_rdy,
  row_info_w_data,
  row_info_r_vld,
  row_info_r_rdy,
  row_info_r_data,
  
  // input cache fifo
  cache_fifo_r_vld,
  cache_fifo_r_rdy,
  cache_fifo_r_data,
  cache_fifo_w_vld,
  cache_fifo_w_rdy,
  cache_fifo_w_data,
  
  // Output ping-pong
  output_ping_r_vld,
  output_ping_r_rdy,
  output_ping_r_data,
  output_ping_w_vld,
  output_ping_w_rdy,
  output_ping_w_data,
  output_pong_r_vld,
  output_pong_r_rdy,
  output_pong_r_data,
  output_pong_w_vld,
  output_pong_w_rdy,
  output_pong_w_data,
  
  gp_k_size
);

//`define SRAM_TYPE

input                       clk;
input                       rst_n;
input                       arst_n;

// if with input reuse cache
input                     w_inner_vld[0:1];
output  logic             w_inner_rdy[0:1];
input         [DW-1:0]    w_inner_data[0:1];
output  logic             r_inner_vld[0:1];
input                     r_inner_rdy[0:1];
output  logic [DW-1:0]    r_inner_data[0:1];

// row_info fifo
input                         row_info_w_vld;
output  logic                 row_info_w_rdy;
input           [2:0]         row_info_w_data;
output  logic                 row_info_r_vld;
input                         row_info_r_rdy;
output  logic   [2:0]         row_info_r_data;

// input cache fifo
output  logic                 cache_fifo_r_vld[0:1];
input                         cache_fifo_r_rdy[0:1];
output  logic   [DW-1:0]      cache_fifo_r_data[0:1];
input                         cache_fifo_w_vld[0:1];
output  logic                 cache_fifo_w_rdy[0:1];
input           [DW-1:0]      cache_fifo_w_data[0:1];

// Output ping-pong
output  logic [MAX_PARA_OUT-1:0]        output_ping_r_vld;
input         [MAX_PARA_OUT-1:0]        output_ping_r_rdy;
output  logic [DW-1:0]                  output_ping_r_data[0:MAX_PARA_OUT-1];
input         [MAX_PARA_OUT-1:0]        output_ping_w_vld;
output  logic [MAX_PARA_OUT-1:0]        output_ping_w_rdy;
input         [DW-1:0]                  output_ping_w_data[0:MAX_PARA_OUT-1];
output  logic [MAX_PARA_OUT-1:0]        output_pong_r_vld;
input         [MAX_PARA_OUT-1:0]        output_pong_r_rdy;
output  logic [DW-1:0]                  output_pong_r_data[0:MAX_PARA_OUT-1];
input         [MAX_PARA_OUT-1:0]        output_pong_w_vld;
output  logic [MAX_PARA_OUT-1:0]        output_pong_w_rdy;
input         [DW-1:0]                  output_pong_w_data[0:MAX_PARA_OUT-1];

input         [K_BITS-1:0]  gp_k_size;

///////////////////////////////
// FIFO inst

`ifndef SMIC40LL
  //stdcore_rfifo #(DW,128,0,7) inner_cache_odd(
  stdcore_rfifo #(DW,2048,0,11) inner_cache_odd(
  .clk      (clk),
`else
  stdcore_rfifo_sram #(DW,256,8) inner_cache_odd(
  .pclk     (clk),
  .cclk     (clk),
`endif
  .arst_n   (arst_n),
  .rst_n    (rst_n),
  .p        (w_inner_data[0]),
  .p_val    (w_inner_vld[0]),
  .p_rdy    (w_inner_rdy[0]),
  .c        (r_inner_data[0]),
  .c_val    (r_inner_vld[0]),
  .c_rdy    (r_inner_rdy[0])
);

`ifndef SMIC40LL
  //stdcore_rfifo #(DW,128,0,7) inner_cache_even(
  stdcore_rfifo #(DW,2048,0,11) inner_cache_even(
  .clk      (clk),
`else
  stdcore_rfifo_sram #(DW,256,8) inner_cache_even(
  .pclk     (clk),
  .cclk     (clk),
`endif
  .arst_n   (arst_n),
  .rst_n    (rst_n),
  .p        (w_inner_data[1]),
  .p_val    (w_inner_vld[1]),
  .p_rdy    (w_inner_rdy[1]),
  .c        (r_inner_data[1]),
  .c_val    (r_inner_vld[1]),
  .c_rdy    (r_inner_rdy[1])
);

// row_info fifo
defparam row_info.DW    = 3;
defparam row_info.DEPTH = 8;
defparam row_info.AW    = 3;
stdcore_rfifo_pre row_info(
  .clk(clk),.arst_n(arst_n),.rst_n(rst_n),
  .p      (row_info_w_data),
  .p_val  (row_info_w_vld),
  .p_rdy  (row_info_w_rdy),
  .p_prdy (),
  .c      (row_info_r_data),
  .c_val  (row_info_r_vld),
  .c_rdy  (row_info_r_rdy)
);

`ifndef SMIC40LL
  stdcore_rfifo #(DW,8192,0,13) fifo_odd(
  .clk      (clk),
`else
  stdcore_rfifo_sram #(DW,8192,13) fifo_odd(
  .pclk     (clk),
  .cclk     (clk),
`endif
  .arst_n   (arst_n),
  .rst_n    (rst_n),
  .p        (cache_fifo_w_data[0]),
  .p_val    (cache_fifo_w_vld[0]),
  .p_rdy    (cache_fifo_w_rdy[0]),
  .c        (cache_fifo_r_data[0]),
  .c_val    (cache_fifo_r_vld[0]),
  .c_rdy    (cache_fifo_r_rdy[0])
);

`ifndef SMIC40LL
  stdcore_rfifo #(DW,8192,0,13) fifo_even(
  .clk      (clk),
`else
  stdcore_rfifo_sram #(DW,8192,13) fifo_even(
  .pclk     (clk),
  .cclk     (clk),
`endif
  .arst_n   (arst_n),
  .rst_n    (rst_n),
  .p        (cache_fifo_w_data[1]),
  .p_val    (cache_fifo_w_vld[1]),
  .p_rdy    (cache_fifo_w_rdy[1]),
  .c        (cache_fifo_r_data[1]),
  .c_val    (cache_fifo_r_vld[1]),
  .c_rdy    (cache_fifo_r_rdy[1])
);

// Output ping-pong
logic   [DW-1:0]                    comb_pi_p[MAX_PARA_OUT-1:0];//
logic                               comb_pi_p_val[MAX_PARA_OUT-1:0];//
logic                               comb_pi_p_rdy[MAX_PARA_OUT-1:0];
logic   [DW-1:0]                    comb_pi_c[MAX_PARA_OUT-1:0];
logic                               comb_pi_c_val[MAX_PARA_OUT-1:0];
logic                               comb_pi_c_rdy[MAX_PARA_OUT-1:0];//

logic   [6:0]   j,k;
always_comb begin
  case(gp_k_size)
    4'd3: begin
      for(j=0;j<MAX_PARA_OUT;j=j+1) begin
        comb_pi_p[j]               = output_ping_w_data[j];
        comb_pi_p_val[j]           = output_ping_w_vld[j];
        output_ping_w_rdy[j]    = comb_pi_p_rdy[j];
        output_ping_r_data[j]   = comb_pi_c[j];
        output_ping_r_vld[j]    = comb_pi_c_val[j];
        comb_pi_c_rdy[j]           = output_ping_r_rdy[j];
      end
    end
    4'd5: begin
      for(j=0;j<MAX_PARA_OUT/2;j=j+1) begin
        comb_pi_p[j]                             = comb_pi_c[j+MAX_PARA_OUT/2];
        comb_pi_p[j+MAX_PARA_OUT/2]              = output_ping_w_data[j];
        
        comb_pi_p_val[j]                         = comb_pi_c_val[j+MAX_PARA_OUT/2] & comb_pi_p_rdy[j];
        comb_pi_p_val[j+MAX_PARA_OUT/2]          = output_ping_w_vld[j];
        
        comb_pi_c_rdy[j]                         = output_ping_r_rdy[j];
        comb_pi_c_rdy[j+MAX_PARA_OUT/2]          = comb_pi_p_rdy[j];
        
        output_ping_w_rdy[j]                  = comb_pi_p_rdy[j+MAX_PARA_OUT/2];
        output_ping_w_rdy[(j+MAX_PARA_OUT/2)]   = 'b0;
        
        output_ping_r_data[j]                 = comb_pi_c[j];
        output_ping_r_data[j+MAX_PARA_OUT/2]  = 'b0;
        
        output_ping_r_vld[j]                  = comb_pi_c_val[j];
        output_ping_r_vld[j+MAX_PARA_OUT/2]   = 'b0;
      end
    end
    default: begin
      // j==0
      comb_pi_p[0]                            = comb_pi_c[1];
      comb_pi_p_val[0]                        = comb_pi_c_val[1] & comb_pi_p_rdy[0];
      comb_pi_c_rdy[0]                        = output_ping_r_rdy[0];
      output_ping_w_rdy[0]                    = comb_pi_p_rdy[MAX_PARA_OUT-1];
      output_ping_r_data[0]                   = comb_pi_c[0];
      output_ping_r_vld[0]                    = comb_pi_c_val[0];
      
      for(j=1;j<MAX_PARA_OUT-1;j=j+1) begin
        comb_pi_p[j]                             = comb_pi_c[j+1];
        comb_pi_p_val[j]                         = comb_pi_c_val[j+1] & comb_pi_p_rdy[j];
        comb_pi_c_rdy[j]                         = comb_pi_p_rdy[j-1];
        output_ping_w_rdy[j]                  = 'b0;
        output_ping_r_data[j]                 = 'b0;
        output_ping_r_vld[j]                  = 'b0;
      end
      // j==MAX_PARA_OUT-1
        comb_pi_p[MAX_PARA_OUT-1]             = output_ping_w_data[0];
        comb_pi_p_val[MAX_PARA_OUT-1]         = output_ping_w_vld[0];
        comb_pi_c_rdy[MAX_PARA_OUT-1]         = comb_pi_p_rdy[MAX_PARA_OUT-2];
        output_ping_w_rdy[MAX_PARA_OUT-1]     = 'b0;
        output_ping_r_data[MAX_PARA_OUT-1]    = 'b0;
        output_ping_r_vld[MAX_PARA_OUT-1]     = 'b0;
      
      /*
      for(j=0;j<4;j=j+1) begin
        comb_pi_p[j]                             = comb_pi_c[j+4];
        comb_pi_p_val[j]                         = comb_pi_c_val[j+4];
        comb_pi_c_rdy[j]                         = output_ping_r_rdy[j];
        output_ping_w_rdy[j]                  = comb_pi_p_rdy[j+MAX_PARA_OUT-4];
        output_ping_r_data[j]                 = comb_pi_c[j];
        output_ping_r_vld[j]                  = comb_pi_c_val[j];
      end
      for(j=4;j<MAX_PARA_OUT-4;j=j+1) begin
        comb_pi_p[j]                             = comb_pi_c[j+4];
        comb_pi_p_val[j]                         = comb_pi_c_val[j+4];
        comb_pi_c_rdy[j]                         = comb_pi_p_rdy[j-4];
        output_ping_w_rdy[j]                  = 'b0;
        output_ping_r_data[j]                 = 'b0;
        output_ping_r_vld[j]                  = 'b0;
      end
      for(j=MAX_PARA_OUT-4;j<MAX_PARA_OUT;j=j+1) begin
        comb_pi_p[j]                             = output_ping_w_data[j+4-MAX_PARA_OUT];
        comb_pi_p_val[j]                         = output_ping_w_vld[j+4-MAX_PARA_OUT];
        comb_pi_c_rdy[j]                         = comb_pi_p_rdy[j-4];
        output_ping_w_rdy[j]                  = 'b0;
        output_ping_r_data[j]                 = 'b0;
        output_ping_r_vld[j]                  = 'b0;
      end
      */
    end
  endcase
end

generate
	for(genvar i = 0; i < MAX_PARA_OUT; i++ ) begin: ping_fifo
    logic   [DW-1:0]          p;
    logic                     p_val;
    logic                     p_rdy;
    logic                     p_prdy;
    logic   [DW-1:0]          c;
    logic                     c_val;
    logic                     c_rdy;
    
    //assign  p     = output_ping_w_data[i];
    //assign  p_val = output_ping_w_vld[i];
    //assign  output_ping_w_rdy[i] = p_rdy;
    //assign  output_ping_r_data[i]     = c;
    //assign  output_ping_r_vld[i] = c_val;
    //assign  c_rdy = output_ping_r_rdy[i];
    assign  p     = comb_pi_p[i];
    assign  p_val = comb_pi_p_val[i];
    //assign  comb_pi_p_rdy[i] = p_rdy;
    assign  comb_pi_p_rdy[i] = p_prdy;
    assign  comb_pi_c[i]     = c;
    assign  comb_pi_c_val[i] = c_val;
    assign  c_rdy = comb_pi_c_rdy[i];
    
    `ifndef SMIC40LL
      stdcore_rfifo_pre #(DW,256,3,8) ping(
        .clk,
        .arst_n,
        .rst_n,
        .p,
        .p_val,
        .p_rdy,
        .p_prdy,
        .c,
        .c_val,
        .c_rdy
      );
    `else
      stdcore_rfifo_sram #(DW,96,7) ping(.pclk(clk),.cclk(clk),.*);
    `endif
  end
endgenerate


logic   [DW-1:0]                    comb_po_p[MAX_PARA_OUT-1:0];//
logic                               comb_po_p_val[MAX_PARA_OUT-1:0];//
logic                               comb_po_p_rdy[MAX_PARA_OUT-1:0];
logic   [DW-1:0]                    comb_po_c[MAX_PARA_OUT-1:0];
logic                               comb_po_c_val[MAX_PARA_OUT-1:0];
logic                               comb_po_c_rdy[MAX_PARA_OUT-1:0];//
always_comb begin
  case(gp_k_size)
    4'd3: begin
      for(k=0;k<MAX_PARA_OUT;k=k+1) begin
        comb_po_p[k]               = output_pong_w_data[k];
        comb_po_p_val[k]           = output_pong_w_vld[k];
        output_pong_w_rdy[k]    = comb_po_p_rdy[k];
        output_pong_r_data[k]   = comb_po_c[k];
        output_pong_r_vld[k]    = comb_po_c_val[k];
        comb_po_c_rdy[k]           = output_pong_r_rdy[k];
      end
    end
    4'd5: begin
      for(k=0;k<MAX_PARA_OUT/2;k=k+1) begin
        comb_po_p[k]                             = comb_po_c[k+MAX_PARA_OUT/2];
        comb_po_p[k+MAX_PARA_OUT/2]              = output_pong_w_data[k];
        
        comb_po_p_val[k]                         = comb_po_c_val[k+MAX_PARA_OUT/2] & comb_po_p_rdy[k];
        comb_po_p_val[k+MAX_PARA_OUT/2]          = output_pong_w_vld[k];
        
        comb_po_c_rdy[k]                         = output_pong_r_rdy[k];
        comb_po_c_rdy[k+MAX_PARA_OUT/2]          = comb_po_p_rdy[k];
        
        output_pong_w_rdy[k]                  = comb_po_p_rdy[k+MAX_PARA_OUT/2];
        output_pong_w_rdy[(k+MAX_PARA_OUT/2)]   = 'b0;
        
        output_pong_r_data[k]                 = comb_po_c[k];
        output_pong_r_data[k+MAX_PARA_OUT/2]  = 'b0;
        
        output_pong_r_vld[k]                  = comb_po_c_val[k];
        output_pong_r_vld[k+MAX_PARA_OUT/2]   = 'b0;
      end
    end
    default: begin
      // k==0
      comb_po_p[0]                            = comb_po_c[1];
      comb_po_p_val[0]                        = comb_po_c_val[1] & comb_po_p_rdy[0];
      comb_po_c_rdy[0]                        = output_pong_r_rdy[0];
      output_pong_w_rdy[0]                    = comb_po_p_rdy[MAX_PARA_OUT-1];
      output_pong_r_data[0]                   = comb_po_c[0];
      output_pong_r_vld[0]                    = comb_po_c_val[0];
      
      for(k=1;k<MAX_PARA_OUT-1;k=k+1) begin
        comb_po_p[k]                             = comb_po_c[k+1];
        comb_po_p_val[k]                         = comb_po_c_val[k+1] & comb_po_p_rdy[k];
        comb_po_c_rdy[k]                         = comb_po_p_rdy[k-1];
        output_pong_w_rdy[k]                  = 'b0;
        output_pong_r_data[k]                 = 'b0;
        output_pong_r_vld[k]                  = 'b0;
      end
      // k==MAX_PARA_OUT-1
        comb_po_p[MAX_PARA_OUT-1]             = output_pong_w_data[0];
        comb_po_p_val[MAX_PARA_OUT-1]         = output_pong_w_vld[0];
        comb_po_c_rdy[MAX_PARA_OUT-1]         = comb_po_p_rdy[MAX_PARA_OUT-2];
        output_pong_w_rdy[MAX_PARA_OUT-1]     = 'b0;
        output_pong_r_data[MAX_PARA_OUT-1]    = 'b0;
        output_pong_r_vld[MAX_PARA_OUT-1]     = 'b0;
      
      /*
      for(k=0;k<4;k=k+1) begin
        comb_po_p[k]                             = comb_po_c[k+4];
        comb_po_p_val[k]                         = comb_po_c_val[k+4];
        comb_po_c_rdy[k]                         = output_pong_r_rdy[k];
        output_pong_w_rdy[k]                  = comb_po_p_rdy[k+MAX_PARA_OUT-4];
        output_pong_r_data[k]                 = comb_po_c[k];
        output_pong_r_vld[k]                  = comb_po_c_val[k];
      end
      for(k=4;k<MAX_PARA_OUT-4;k=k+1) begin
        comb_po_p[k]                             = comb_po_c[k+4];
        comb_po_p_val[k]                         = comb_po_c_val[k+4];
        comb_po_c_rdy[k]                         = comb_po_p_rdy[k-4];
        output_pong_w_rdy[k]                  = 'b0;
        output_pong_r_data[k]                 = 'b0;
        output_pong_r_vld[k]                  = 'b0;
      end
      for(k=MAX_PARA_OUT-4;k<MAX_PARA_OUT;k=k+1) begin
        comb_po_p[k]                             = output_pong_w_data[k+4-MAX_PARA_OUT];
        comb_po_p_val[k]                         = output_pong_w_vld[k+4-MAX_PARA_OUT];
        comb_po_c_rdy[k]                         = comb_po_p_rdy[k-4];
        output_pong_w_rdy[k]                  = 'b0;
        output_pong_r_data[k]                 = 'b0;
        output_pong_r_vld[k]                  = 'b0;
      end
      */
    end
  endcase
end
generate
	for(genvar i = 0; i < MAX_PARA_OUT; i++ ) begin: pong_fifo
    logic   [DW-1:0]          p;
    logic                     p_val;
    logic                     p_rdy;
    logic                     p_prdy;
    logic   [DW-1:0]          c;
    logic                     c_val;
    logic                     c_rdy;

    //assign  p     = output_pong_w_data[i];
    //assign  p_val = output_pong_w_vld[i];
    //assign  output_pong_w_rdy[i] = p_rdy;
    //assign  output_pong_r_data[i]     = c;
    //assign  output_pong_r_vld[i] = c_val;
    //assign  c_rdy = output_pong_r_rdy[i];
    assign  p     = comb_po_p[i];
    assign  p_val = comb_po_p_val[i];
    //assign  comb_po_p_rdy[i] = p_rdy;
    assign  comb_po_p_rdy[i] = p_prdy;
    assign  comb_po_c[i]     = c;
    assign  comb_po_c_val[i] = c_val;
    assign  c_rdy = comb_po_c_rdy[i];
    
    `ifndef SMIC40LL
      stdcore_rfifo_pre #(DW,256,3,8) pong(
        .clk,
        .arst_n,
        .rst_n,
        .p,
        .p_val,
        .p_rdy,
        .p_prdy,
        .c,
        .c_val,
        .c_rdy
      );
    `else
      stdcore_rfifo_sram #(DW,96,7) pong(.pclk(clk),.cclk(clk),.*);
    `endif
  end
endgenerate    

// synopsys translate_off
always_ff@(posedge clk)
begin 
  if(row_info_w_vld & !row_info_w_rdy)  $display("Row_info fifo write conflict; @",$time);
  if(row_info_r_rdy & !row_info_r_vld)   $display("Row_info fifo read conflict; @",$time);
  if(cache_fifo_w_vld[0] & !cache_fifo_w_rdy[0])  $display("Cache_fifo_odd fifo write conflict; @",$time);
  if(cache_fifo_r_rdy[0] & !cache_fifo_r_vld[0])  $display("Cache_fifo_odd fifo read conflict; @",$time);
  if(cache_fifo_w_vld[1] & !cache_fifo_w_rdy[1])  $display("Cache_fifo_EVEN fifo write conflict; @",$time);
  if(cache_fifo_r_rdy[1] & !cache_fifo_r_vld[1])  $display("Cache_fifo_EVEN fifo read conflict; @",$time);
  if(output_ping_w_vld[0] & !output_ping_w_rdy[0])  $display("Ping fifo write conflict; @",$time);
  if(output_ping_r_rdy[0] & !output_ping_r_vld[0])  $display("Ping fifo read conflict; @",$time);
  if(output_pong_w_vld[0] & !output_pong_w_rdy[0])  $display("Pong fifo write conflict; @",$time);
  if(output_pong_r_rdy[0] & !output_pong_r_vld[0])  $display("Pong fifo read conflict; @",$time); 
end
// synopsys translate_on

endmodule