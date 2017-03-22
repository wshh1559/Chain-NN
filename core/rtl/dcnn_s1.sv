`timescale 1ns/1ps
module dcnn_s1
#(parameter DW = 32,
            PARA = 16,
            AW = 32,
            K_BITS = 4,
            M_BITS = 10,
            MAX_PARA_OUT = 64,
            MAX_PARA_OUT_BIT = 7)
(
  clk,
  rst_n,
  arst_n,
  
  k_size,
  m_size,
  
  image_stream_out_vld,
  image_stream_out_valid,
  image_stream_out_rdy,
  image_stream_out,
  
  // control signal
  para_out_num,
  pe_chain_cfg,
  pe_chain_cfg_done,
  mode_kernel_load,
  
  // Output
  psum_para_out,
  psum_para_out_vld
);

input                       clk;
input                       rst_n;
input                       arst_n;

// if with s0
input         [K_BITS-1:0]    k_size;
input         [M_BITS-1:0]    m_size;

// control signal
input         [MAX_PARA_OUT_BIT-1:0]  para_out_num;
input                     pe_chain_cfg;
output  logic             pe_chain_cfg_done;
input                     mode_kernel_load;

// if with s2
output  logic [DW-1:0]    psum_para_out[0:MAX_PARA_OUT-1];
output  logic             psum_para_out_vld[0:MAX_PARA_OUT-1];

input                     image_stream_out_vld[0:1];
input         [1:0]       image_stream_out_valid;
output  logic             image_stream_out_rdy[0:1];
input         [DW-1:0]    image_stream_out[0:1];

assign    image_stream_out_rdy = {'b1,'b1};   //FIXME

dcnn_s1_chain #(DW,PARA,K_BITS,M_BITS,MAX_PARA_OUT,MAX_PARA_OUT_BIT) 
s1_chain(
  .clk          (clk),
  .rst_n        (rst_n),
  .arst_n       (arst_n),
  
  // control signal
  .para_out_num       (para_out_num),
  .pe_chain_cfg       (pe_chain_cfg),
  .pe_chain_cfg_done  (pe_chain_cfg_done),
  .kernel_load        (mode_kernel_load),
  
  // kernel_size
  .k_size       (k_size),
  
  // Image
  .image_para_in_odd  (image_stream_out[0]),  //FIXME: DW ?=32
  .image_para_in_even (image_stream_out[1]),
  .image_para_in_vld  (image_stream_out_valid),
  //.image_para_in_odd  ({32'b0,32'b0,32'b0,image_stream_out[0]}),  //FIXME: DW ?=32
  //.image_para_in_even ({32'b0,32'b0,32'b0,image_stream_out[1]}),
  //.image_para_in_vld  ({2'b0,2'b0,2'b0,image_stream_out_valid}),
  
  // Output
  .psum_para_out      (psum_para_out),
  .psum_para_out_vld  (psum_para_out_vld)
);

endmodule