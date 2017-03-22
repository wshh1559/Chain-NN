`timescale 1ns/1ps
module dcnn_top
#(parameter DW = 16,
            PARA = 576,
            AW = 32,
            K_BITS = 4,
            M_BITS = 10,
            MAX_PARA_OUT = 64,
            MAX_PARA_OUT_BIT = 7)
(
  clk,
  rst_n,
  arst_n,
  
  // high-level control
  layer_start,
  layer_finish,
  
  // kernel fifo
  k_rfifo_vld,
  k_rfifo_rdy,
  k_rfifo_data,
  
  // fin fifo
  r_vld_odd,
  r_rdy_odd,
  r_data_odd,
  r_vld_even,
  r_rdy_even,
  r_data_even,
  
  // Output fifo to dram 
  dram_w_vld,
  dram_w_rdy,
  dram_w_data,
  dram_w_last,
  
`ifdef FPGA
  test_status,
`endif
  
  // global signal
  gp_fin_num,
  gp_fout_num,
  gp_fin_stride,
  gp_fout_stride,
  gp_k_depth_num,
  gp_k_read_num,
  gp_b_size,
  gp_k_size,
  gp_m_size,
  gp_n_size,
  gp_s_size,
  gp_para_out_num
);

input                       clk;
input                       rst_n;
input                       arst_n;

// high-level control
input                       layer_start;
output  logic               layer_finish;

// kernel fifo
input                       k_rfifo_vld;
output  logic               k_rfifo_rdy;
input         [DW-1:0]      k_rfifo_data;

// if with fin fifo 
input                       r_vld_odd;
output  logic               r_rdy_odd;
input         [DW-1:0]      r_data_odd;
input                       r_vld_even;
output  logic               r_rdy_even;
input         [DW-1:0]      r_data_even;

// if with dram output fifo
output  logic               dram_w_vld;
input                       dram_w_rdy;
output  logic [DW-1:0]      dram_w_data;
output  logic               dram_w_last;

`ifdef FPGA
output  logic [2:0]         test_status;
`endif

// global signal
input         [9:0]         gp_fin_num;
input         [9:0]         gp_fout_num;
input         [2:0]         gp_fin_stride;
input         [6:0]         gp_fout_stride;
input         [AW-1:0]      gp_k_depth_num;
input         [3:0]         gp_k_read_num;
input         [8:0]         gp_b_size;
input         [K_BITS-1:0]  gp_k_size;
input         [M_BITS-1:0]  gp_m_size;
input         [M_BITS-1:0]  gp_n_size;
input         [M_BITS-1:0]  gp_s_size;
input         [MAX_PARA_OUT_BIT-1:0]  gp_para_out_num;

/////////////////////////
// Internal logic

// if with input reuse cache
logic              w_inner_vld[0:1];
logic              w_inner_rdy[0:1];
logic  [DW-1:0]    w_inner_data[0:1];
logic              r_inner_vld[0:1];
logic              r_inner_rdy[0:1];
logic  [DW-1:0]    r_inner_data[0:1];

// if with input fifo
logic             cache_fifo_r_vld[0:1];
logic             cache_fifo_r_rdy[0:1];
logic [DW-1:0]    cache_fifo_r_data[0:1];
logic [AW-1:0]    cache_fifo_r_addr[0:1];
logic             cache_fifo_w_vld[0:1];
logic             cache_fifo_w_rdy[0:1];
logic [DW-1:0]    cache_fifo_w_data[0:1];
logic [AW-1:0]    cache_fifo_w_addr[0:1];

// if with kernel fifo
logic               k_wfifo_vld;
logic               k_wfifo_rdy;
logic [DW-1:0]      k_wfifo_data;
logic [AW-1:0]      k_wfifo_addr;

// if with row fifo
logic               row_info_vld;
logic               row_info_rdy;
logic [2:0]         row_info_data;
logic               row_task_vld;
logic               row_task_rdy;
logic [2:0]         row_task_data;

// control signal
logic                         pe_chain_cfg;
logic                         pe_chain_cfg_done;

// if with s2
logic [DW-1:0]    psum_para_out[0:MAX_PARA_OUT-1];
logic             psum_para_out_vld[0:MAX_PARA_OUT-1];


logic             image_stream_out_vld[0:1];
logic [1:0]       image_stream_out_valid;
logic             image_stream_out_rdy[0:1];
logic [DW-1:0]    image_stream_out[0:1];

// Output ping-pong
/*logic [MAX_PARA_OUT-1:0]        output_fifo_r_vld[0:1];
logic [MAX_PARA_OUT-1:0]        output_fifo_r_rdy[0:1];
logic [DW*MAX_PARA_OUT-1:0]     output_fifo_r_data[0:1];
logic [AW-1:0]                  output_fifo_r_addr[0:1];
logic [MAX_PARA_OUT-1:0]        output_fifo_w_vld[0:1];
logic [MAX_PARA_OUT-1:0]        output_fifo_w_rdy[0:1];
logic [DW*MAX_PARA_OUT-1:0]     output_fifo_w_data[0:1];
logic [AW-1:0]                  output_fifo_w_addr[0:1];*/
logic [MAX_PARA_OUT-1:0]        output_ping_r_vld;
logic [MAX_PARA_OUT-1:0]        output_ping_r_rdy;
logic [DW-1:0]                  output_ping_r_data[0:MAX_PARA_OUT-1];
logic [MAX_PARA_OUT-1:0]        output_ping_w_vld;
logic [MAX_PARA_OUT-1:0]        output_ping_w_rdy;
logic [DW-1:0]                  output_ping_w_data[0:MAX_PARA_OUT-1];
logic [MAX_PARA_OUT-1:0]        output_pong_r_vld;
logic [MAX_PARA_OUT-1:0]        output_pong_r_rdy;
logic [DW-1:0]                  output_pong_r_data[0:MAX_PARA_OUT-1];
logic [MAX_PARA_OUT-1:0]        output_pong_w_vld;
logic [MAX_PARA_OUT-1:0]        output_pong_w_rdy;
logic [DW-1:0]                  output_pong_w_data[0:MAX_PARA_OUT-1];

dcnn_s0 #(DW,AW,K_BITS,M_BITS,PARA)
s0(
  .clk              (clk),
  .rst_n            (rst_n),
  .arst_n           (arst_n),
  
  // high-level control
  .layer_start      (layer_start),
  .layer_finish     (layer_finish),
  
  // PE china configure
  .pe_chain_cfg     (pe_chain_cfg),
  .pe_chain_cfg_done(pe_chain_cfg_done),
  
  // stream data in
  .stream_r_vld              ({r_vld_even, r_vld_odd}),
  .stream_r_rdy              ({r_rdy_even, r_rdy_odd}),
  .stream_r_data             ({r_data_even, r_data_odd}),
  
  .w_inner_vld        (w_inner_vld),
  .w_inner_rdy        (w_inner_rdy),
  .w_inner_data       (w_inner_data),
  .r_inner_vld        (r_inner_vld),
  .r_inner_rdy        (r_inner_rdy),
  .r_inner_data       (r_inner_data),
  
  // INPUT cache interface
  .cache_fifo_r_vld   (cache_fifo_r_vld),
  .cache_fifo_r_rdy   (cache_fifo_r_rdy),
  .cache_fifo_r_data  (cache_fifo_r_data),
  .cache_fifo_r_addr  (cache_fifo_r_addr),
  .cache_fifo_w_vld   (cache_fifo_w_vld),
  .cache_fifo_w_rdy   (cache_fifo_w_rdy),
  .cache_fifo_w_data  (cache_fifo_w_data),
  .cache_fifo_w_addr  (cache_fifo_w_addr),
  
  // kernel fifo
  .k_rfifo_vld      (k_rfifo_vld),
  .k_rfifo_rdy      (k_rfifo_rdy),
  .k_rfifo_data     (k_rfifo_data),
  .k_wfifo_vld      (k_wfifo_vld),
  .k_wfifo_rdy      (k_wfifo_rdy),
  .k_wfifo_data     (k_wfifo_data),
  .k_wfifo_addr     (k_wfifo_addr),
  
  // relay fifo to stage_c
  .row_info_vld     (row_info_vld),
  .row_info_rdy     (row_info_rdy),
  .row_info_data    (row_info_data),
  
  // Image
  .image_stream_out_vld     (image_stream_out_vld),
  .image_stream_out_valid   (image_stream_out_valid),
  .image_stream_out_rdy     (image_stream_out_rdy),
  .image_stream_out         (image_stream_out),
  
`ifdef FPGA
  .test_status              (test_status),
`endif
  
  // global signal
  .gp_fin_num       (gp_fin_num),
  .gp_fout_num      (gp_fout_num),
  .gp_fin_stride    (gp_fin_stride),
  .gp_fout_stride   (gp_fout_stride),
  .gp_k_depth_num   (gp_k_depth_num),
  .gp_k_read_num    (gp_k_read_num),
  .gp_b_size        (gp_b_size),
  .gp_k_size        (gp_k_size),
  .gp_m_size        (gp_m_size)
);

logic   [DW-1:0]      s1_input[0:1];
assign  s1_input[0] = k_wfifo_vld ? k_wfifo_data            : image_stream_out[0];
assign  s1_input[1] = k_wfifo_vld ? (k_wfifo_addr[15:0]+1)  : image_stream_out[1];
dcnn_s1 #(DW,PARA,AW,K_BITS,M_BITS,MAX_PARA_OUT,MAX_PARA_OUT_BIT)
s1(
  .clk                (clk),
  .rst_n              (rst_n),
  .arst_n             (arst_n),
  
  .k_size             (gp_k_size),
  .m_size             (gp_m_size),
  
  // Image
  .image_stream_out_vld     (image_stream_out_vld),
  .image_stream_out_valid   (image_stream_out_valid),
  .image_stream_out_rdy     (image_stream_out_rdy),
  .image_stream_out         (s1_input),
  
  // control signal
  .para_out_num       (gp_para_out_num),
  .pe_chain_cfg       (pe_chain_cfg),
  .pe_chain_cfg_done  (pe_chain_cfg_done),
  .mode_kernel_load   (k_wfifo_vld),
  
  // Output
  .psum_para_out      (psum_para_out),
  .psum_para_out_vld  (psum_para_out_vld)
);

dcnn_s2_memif_output #(DW,AW,K_BITS,M_BITS,MAX_PARA_OUT,MAX_PARA_OUT_BIT,PARA)
s2 (
  .clk                (clk),
  .rst_n              (rst_n),
  .arst_n             (arst_n),
  
  .para_out_num       (gp_para_out_num),
  
  // row task FIFO interface
  .row_task_vld       (row_task_vld),
  .row_task_rdy       (row_task_rdy),
  .row_task_data      (row_task_data),
  
  .psum_out           (psum_para_out),
  .psum_out_vld       (psum_para_out_vld),
  
  // OUTPUT cache interface
  /*.output_fifo_r_vld  (output_fifo_r_vld),
  .output_fifo_r_rdy  (output_fifo_r_rdy),
  .output_fifo_r_data (output_fifo_r_data),
  .output_fifo_r_addr (output_fifo_r_addr),
  .output_fifo_w_vld  (output_fifo_w_vld),
  .output_fifo_w_rdy  (output_fifo_w_rdy),
  .output_fifo_w_data (output_fifo_w_data),
  .output_fifo_w_addr (output_fifo_w_addr),*/
  .output_ping_r_vld   (output_ping_r_vld),
  .output_ping_r_rdy   (output_ping_r_rdy),
  .output_ping_r_data  (output_ping_r_data),
  .output_ping_w_vld   (output_ping_w_vld),
  .output_ping_w_rdy   (output_ping_w_rdy),
  .output_ping_w_data  (output_ping_w_data),
  .output_pong_r_vld   (output_pong_r_vld),
  .output_pong_r_rdy   (output_pong_r_rdy),
  .output_pong_r_data  (output_pong_r_data),
  .output_pong_w_vld   (output_pong_w_vld),
  .output_pong_w_rdy   (output_pong_w_rdy),
  .output_pong_w_data  (output_pong_w_data),
  
  
  // Output fifo to dram 
  .dram_w_vld         (dram_w_vld),
  .dram_w_rdy         (dram_w_rdy),
  .dram_w_data        (dram_w_data),
  .dram_w_last        (dram_w_last),
  
  // gp
  .gp_fout_num        (gp_fout_num),
  .gp_fout_stride     (gp_fout_stride),
  .gp_k_size          (gp_k_size),
  .gp_m_size          (gp_m_size),
  .gp_n_size          (gp_n_size)
);

dcnn_mems #(DW,AW,PARA,K_BITS,MAX_PARA_OUT,MAX_PARA_OUT_BIT)
mems_fifo(
  .clk                  (clk),
  .rst_n                (rst_n),
  .arst_n               (arst_n),
  
  .w_inner_vld        (w_inner_vld),
  .w_inner_rdy        (w_inner_rdy),
  .w_inner_data       (w_inner_data),
  .r_inner_vld        (r_inner_vld),
  .r_inner_rdy        (r_inner_rdy),
  .r_inner_data       (r_inner_data),
  
  // row_info fifo
  .row_info_w_vld       (row_info_vld),
  .row_info_w_rdy       (row_info_rdy),
  .row_info_w_data      (row_info_data),
  .row_info_r_vld       (row_task_vld),
  .row_info_r_rdy       (row_task_rdy),
  .row_info_r_data      (row_task_data),
  
  // input cache fifo
  .cache_fifo_r_vld     (cache_fifo_r_vld),
  .cache_fifo_r_rdy     (cache_fifo_r_rdy),
  .cache_fifo_r_data    (cache_fifo_r_data),
  .cache_fifo_w_vld     (cache_fifo_w_vld),
  .cache_fifo_w_rdy     (cache_fifo_w_rdy),
  .cache_fifo_w_data    (cache_fifo_w_data),
  
  // Output ping-pong
  /*.output_fifo_r_vld    (output_fifo_r_vld),
  .output_fifo_r_rdy    (output_fifo_r_rdy),
  .output_fifo_r_data   (output_fifo_r_data),
  .output_fifo_w_vld    (output_fifo_w_vld),
  .output_fifo_w_rdy    (output_fifo_w_rdy),
  .output_fifo_w_data   (output_fifo_w_data)*/
  .output_ping_r_vld   (output_ping_r_vld),
  .output_ping_r_rdy   (output_ping_r_rdy),
  .output_ping_r_data  (output_ping_r_data),
  .output_ping_w_vld   (output_ping_w_vld),
  .output_ping_w_rdy   (output_ping_w_rdy),
  .output_ping_w_data  (output_ping_w_data),
  .output_pong_r_vld   (output_pong_r_vld),
  .output_pong_r_rdy   (output_pong_r_rdy),
  .output_pong_r_data  (output_pong_r_data),
  .output_pong_w_vld   (output_pong_w_vld),
  .output_pong_w_rdy   (output_pong_w_rdy),
  .output_pong_w_data  (output_pong_w_data),
  
  .gp_k_size            (gp_k_size)
  //.gp_k_size            (4'd5)
);
/*
#(parameter DW = 16,
            PARA = 576,
            AW = 32,
            K_BITS = 4,
            M_BITS = 10,
            MAX_PARA_OUT = 64,
            MAX_PARA_OUT_BIT = 7)*/

endmodule