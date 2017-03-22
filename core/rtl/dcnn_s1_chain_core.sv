`timescale 1ns/1ps
module dcnn_s1_chain_core
#(parameter DW = 16,
            K_BITS = 4,
            M_BITS = 10,
            PARA = 9)
(
  clk,
  rst_n,
  arst_n,
  
  // control signal
  en_flag,
  en_attribute,
  mode_kernel_load,
  
  // kernel_size
  k_size,
  
  // Image
  image_in_odd,
  image_in_even,
  image_in_vld,
  
  // Output
  psum_out,
  psum_out_vld
);

input                       clk;
input                       rst_n;
input                       arst_n;

input                       en_flag[0:PARA-1];
input                       en_attribute[0:PARA-1];
input                       mode_kernel_load;

input         [K_BITS-1:0]  k_size;

input         [DW-1:0]      image_in_odd[0:PARA-1];
input         [DW-1:0]      image_in_even[0:PARA-1];
input         [1:0]         image_in_vld[0:PARA-1];
output  logic [DW-1:0]      psum_out[0:PARA-1];
output  logic [1:0]         psum_out_vld[0:PARA-1];
  


//logic   [DW-1:0]    x_out[0:PARA-1];
logic   [DW-1:0]    xout_chain_odd[0:PARA-1];
logic   [DW-1:0]    xout_chain_even[0:PARA-1];
//logic               x_vld_chain[0:PARA-1];

logic   [9:0]   idx_pe_last, idx_pe_first;
assign idx_pe_last = PARA;
assign idx_pe_first = 1;


//FIXME DW ?=32
logic   [DW-1:0]    x_entrance_0[0:1], x_out_0[0:1];
assign  {x_entrance_0[0],x_entrance_0[1]} = {image_in_odd[0],image_in_even[0]};
assign  {xout_chain_odd[0],xout_chain_even[0]} = {x_out_0[0],x_out_0[1]};
dcnn_s1_chain_core_pe #(DW,K_BITS,M_BITS,PARA) pe_0    (clk, rst_n, arst_n, en_flag[0],      en_attribute[0],  mode_kernel_load, idx_pe_last,      k_size, 
  {{DW{1'b0}},{DW{1'b0}}},      x_entrance_0,                   x_out_0,
  {DW{1'b0}},                image_in_vld[0], image_in_vld[0],     psum_out[0],      psum_out_vld[0]);

logic   [DW-1:0]    x_entrance_last[0:1], x_out_last[0:1], x_in_last[0:1];
assign  {x_in_last[0],x_in_last[1]} = {xout_chain_odd[PARA-2],xout_chain_even[PARA-2]};
assign  {x_entrance_last[0],x_entrance_last[1]} = {image_in_odd[PARA-1],image_in_even[PARA-1]};
assign  {xout_chain_odd[PARA-1],xout_chain_even[PARA-1]} = {x_out_last[0],x_out_last[1]};
dcnn_s1_chain_core_pe #(DW,K_BITS,M_BITS,PARA) pe_last (clk, rst_n, arst_n, en_flag[PARA-1], en_attribute[PARA-1],   mode_kernel_load, idx_pe_first, k_size, 
  x_in_last,  x_entrance_last,   x_out_last,
  psum_out[PARA-2],   psum_out_vld[PARA-2], image_in_vld[PARA-1],  psum_out[PARA-1], psum_out_vld[PARA-1]);

generate
	for(genvar i = 1; i < PARA-1; i++ ) begin: chain
			logic  							entrance_flag;
			logic  							entrance_attribute;
			logic [9:0]				  idx_pe;
      logic [DW-1:0]      x_in[0:1];
      logic [DW-1:0]      x_entrance[0:1];
      logic [1:0]         y_entrance_vld;
      logic [DW-1:0]      x_out[0:1];
      logic [DW-1:0]      y_in;
      logic [1:0]         y_in_vld;
      logic [DW-1:0]      y_out;
      logic [1:0]         y_out_vld;

			assign  entrance_flag       = en_flag[i];
			assign  entrance_attribute  = en_attribute[i];
      assign  idx_pe              = PARA-i;
			assign  {x_in[0],x_in[1]}   = {xout_chain_odd[i-1],xout_chain_even[i-1]};
			assign  {x_entrance[0],x_entrance[1]}     = {image_in_odd[i],image_in_even[i]};
			assign  y_in                = psum_out[i-1];
			assign  y_in_vld            = psum_out_vld[i-1];
      assign  y_entrance_vld      = image_in_vld[i];
      assign  psum_out[i]         = y_out;
      assign  psum_out_vld[i]     = y_out_vld;
      assign  xout_chain_odd[i]   = x_out[0];
      assign  xout_chain_even[i]  = x_out[1];

			dcnn_s1_chain_core_pe #(DW,K_BITS,M_BITS,PARA) pe (
        .clk,
        .rst_n,
        .arst_n,
        .entrance_flag,
        .entrance_attribute,
        .mode_kernel_load,
        .idx_pe,
        .k_size,
        .x_in,
        .x_entrance,
        .x_out,
        .y_in,
        .y_in_vld,
        .y_entrance_vld,
        .y_out,
        .y_out_vld
      );
	end
endgenerate



endmodule