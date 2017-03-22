`timescale 1ns/1ps
module dcnn_s0
#(parameter DW = 32,
            AW = 32,
            K_BITS = 4,
            M_BITS = 10,
            PARA = 9)
(
  clk,
  rst_n,
  arst_n,
  
  // high-level control
  layer_start,
  layer_finish,
  
  // PE china configure
  pe_chain_cfg,
  pe_chain_cfg_done,
  
  // stream data in
  stream_r_vld,
  stream_r_rdy,
  stream_r_data,
  
  w_inner_vld,
  w_inner_rdy,
  w_inner_data,
  r_inner_vld,
  r_inner_rdy,
  r_inner_data,
  
  // INPUT cache interface
  cache_fifo_r_vld,
  cache_fifo_r_rdy,
  cache_fifo_r_data,
  cache_fifo_r_addr,
  cache_fifo_w_vld,
  cache_fifo_w_rdy,
  cache_fifo_w_data,
  cache_fifo_w_addr,
  
  // kernel fifo
  k_rfifo_vld,
  k_rfifo_rdy,
  k_rfifo_data,
  k_wfifo_vld,
  k_wfifo_rdy,
  k_wfifo_data,
  k_wfifo_addr,
  
  // Image
  image_stream_out_vld,
  image_stream_out_valid,
  image_stream_out_rdy,
  image_stream_out,
  
  // relay fifo to stage_c
  row_info_vld,
  row_info_rdy,
  row_info_data,
  
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
  gp_m_size
);

input                       clk;
input                       rst_n;
input                       arst_n;

// high-level control
input                       layer_start;
output  logic               layer_finish;

// PE china configure
output  logic               pe_chain_cfg;
input                       pe_chain_cfg_done;

// if with fin fifo 
input                     stream_r_vld[0:1];
output  logic             stream_r_rdy[0:1];
input         [DW-1:0]    stream_r_data[0:1];

// if with input reuse cache
output  logic             w_inner_vld[0:1];
input                     w_inner_rdy[0:1];
output  logic [DW-1:0]    w_inner_data[0:1];
input                     r_inner_vld[0:1];
output  logic             r_inner_rdy[0:1];
input         [DW-1:0]    r_inner_data[0:1];

// if with input fifo
input                     cache_fifo_r_vld[0:1];
output  logic             cache_fifo_r_rdy[0:1];
input         [DW-1:0]    cache_fifo_r_data[0:1];
output  logic [AW-1:0]    cache_fifo_r_addr[0:1];
output  logic             cache_fifo_w_vld[0:1];
input                     cache_fifo_w_rdy[0:1];
output  logic [DW-1:0]    cache_fifo_w_data[0:1];
output  logic [AW-1:0]    cache_fifo_w_addr[0:1];
  
// kernel fifo
input                       k_rfifo_vld;
output  logic               k_rfifo_rdy;
input         [DW-1:0]      k_rfifo_data;
output  logic               k_wfifo_vld;
input                       k_wfifo_rdy;
output  logic [DW-1:0]      k_wfifo_data;
output  logic [AW-1:0]      k_wfifo_addr;

// output to stage_s1
output  logic             image_stream_out_vld[0:1];
output  logic [1:0]       image_stream_out_valid;
input                     image_stream_out_rdy[0:1];
output  logic [DW-1:0]    image_stream_out[0:1];


// relay fifo to stage_s2
output  logic               row_info_vld;
input                       row_info_rdy;
output  logic [2:0]         row_info_data;

logic   [2:0]     state, n_state;
`ifdef FPGA
output  logic [2:0]         test_status;
assign  test_status = state;
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

// Inner signals
logic           k_read_done;
logic   [15:0]  k_depth_cnt, k_width_cnt;

logic           round_done;
logic   [3:0]   k_read_cnt;
logic   [15:0]  fout_cnt, fin_cnt, batch_cnt, rowInKer_cnt;
logic   [M_BITS-1:0]  row_cnt;

// if with dcnn_chain_pe
logic               col_row_go;
logic               col_row_done;
logic [1:0]         col_row_type;
logic [K_BITS-1:0]  col_row_last_num;
logic               col_row_last_row;
logic [1:0]         col_row_fout_set;   // [0]: fout_set is last; [1]: fout_set is first

parameter   IDLE          = 3'd0,
            MEMADDR_INIT  = 3'd1,
            KERNEL_READ   = 3'd2,
            CHAIN_CLR     = 3'd3,
            START         = 3'd4,
            LAYER_DONE    = 3'd5;


always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  state <= IDLE;
end else if(!rst_n) begin
  state <= IDLE;
end else begin
  state <= n_state;
end

always_comb
begin
  n_state = IDLE;
  case(state)
    IDLE:         if(layer_start)         n_state = MEMADDR_INIT; else  n_state = state;
    MEMADDR_INIT: if(pe_chain_cfg_done)   n_state = KERNEL_READ;  else  n_state = state;
    KERNEL_READ:  if(k_read_done)         n_state = CHAIN_CLR;    else  n_state = state;
    CHAIN_CLR:    if(!layer_start)        n_state = START;        else  n_state = state;
    START:        if(round_done)          n_state = (k_read_cnt>= gp_k_read_num) ? LAYER_DONE : KERNEL_READ; else n_state = state;
    default:      n_state = state;
  endcase
end

// For stage MEMADDR_INIT
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  pe_chain_cfg  <= 'b0;
end else if(!rst_n) begin
  pe_chain_cfg  <= 'b0;
end else begin
  if(n_state==MEMADDR_INIT & state!=MEMADDR_INIT) 
    pe_chain_cfg  <= 'b1;
  else
    pe_chain_cfg  <= 'b0;
end

// For stage KERNEL_READ
assign  k_rfifo_rdy = n_state == KERNEL_READ;
//assign  k_wfifo_addr = {k_width_cnt,k_depth_cnt};
//assign  k_wfifo_addr = {'b0,k_width_cnt};
logic   k_wfifo_vld_;
//assign  k_wfifo_vld = k_wfifo_vld_& k_rfifo_vld;
assign  k_wfifo_vld = k_wfifo_vld_;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  k_depth_cnt   <= 'b0;
  k_width_cnt   <= 'b0;
  k_read_done   <= 'b0;
  k_wfifo_vld_  <= 'b0;
  k_wfifo_data  <= 'b0;
  k_wfifo_addr  <= 'b0;
end else if(!rst_n) begin
  k_depth_cnt   <= 'b0;
  k_width_cnt   <= 'b0;
  k_read_done   <= 'b0;
  k_wfifo_vld_  <= 'b0;
  k_wfifo_data  <= 'b0;
  k_wfifo_addr  <= 'b0;
end else begin
  if(n_state==KERNEL_READ) begin
    if(k_rfifo_vld) begin
      k_depth_cnt   <= (k_depth_cnt+1==gp_k_depth_num) ? 'b0 : (k_depth_cnt+1); 
      k_width_cnt   <= (k_depth_cnt+1==gp_k_depth_num) ? ((k_width_cnt+1==PARA) ? 'b0 : (k_width_cnt+1)) : k_width_cnt;
      k_read_done   <= (k_depth_cnt+1==gp_k_depth_num) & (k_width_cnt+1==PARA);
      k_wfifo_vld_  <= 'b1;
      k_wfifo_data  <= k_rfifo_data;
      k_wfifo_addr  <= {'b0,k_width_cnt};
    end
  end else begin
    k_depth_cnt   <= 'b0;
    k_width_cnt   <= 'b0;
    k_read_done   <= 'b0;
    k_wfifo_vld_  <= 'b0;
    k_wfifo_data  <= 'b0;
    k_wfifo_addr  <= 'b0;
  end
end

// For stage START
logic   fout_flag, rowInKer_flag, fin_flag, row_flag, batch_flag, krd_flag;
assign  fout_flag   = (fout_cnt+gp_fout_stride>=gp_fout_num);
assign  rowInKer_flag = 1'b1;
assign  fin_flag    = (fin_cnt+gp_fin_stride>=gp_fin_num);
assign  row_flag    = (row_cnt>=(gp_m_size-1));
assign  batch_flag  = (batch_cnt+1>=gp_b_size);
assign  krd_flag    = (k_read_cnt+1>=gp_k_read_num);

assign  col_row_fout_set = {(fout_cnt==0),fout_flag};
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  col_row_go  <= 'b0;
  round_done  <= 'b0;
  fin_cnt     <= 'b0;
  rowInKer_cnt<= 'b0;
  fout_cnt    <= 'b0;
  row_cnt     <= 'b0;
  batch_cnt   <= 'b0;
  k_read_cnt  <= 'b0;
  col_row_type      <= 'b0;
  col_row_last_num  <= 'b0;
  col_row_last_row  <= 'b0;
  row_info_vld    <= 'b0;
  row_info_data   <= 'b0;
end else if(!rst_n) begin
  col_row_go  <= 'b0;
  round_done  <= 'b0;
  fin_cnt     <= 'b0;
  rowInKer_cnt<= 'b0;
  fout_cnt    <= 'b0;
  row_cnt     <= 'b0;
  batch_cnt   <= 'b0;
  k_read_cnt  <= 'b0;
  col_row_type      <= 'b0;
  col_row_last_num  <= 'b0;
  col_row_last_row  <= 'b0;
  row_info_vld    <= 'b0;
  row_info_data   <= 'b0;
end else begin
  if(n_state==START) begin
    if( state!=START | col_row_done )   col_row_go  <= !(fout_flag&fin_flag&row_flag&batch_flag);
    else                                col_row_go  <= 'b0;
    
    row_info_vld  <= col_row_go;
    row_info_data <= {fout_flag,(fin_cnt=='b0),fin_flag&fout_flag};
    
    if(fout_flag&fin_flag&col_row_done)
      if(row_flag) begin                          
        col_row_type      <= 2'b00; 
        col_row_last_num  <= 'b0; 
        col_row_last_row  <= 'b0;
      end else begin
        //if(row_cnt=='b0)                                    begin col_row_type <= 2'b00; col_row_last_num <= 'b0; end
        if(row_cnt+gp_k_size+gp_k_size-1<=gp_m_size-1)           begin col_row_type <= 2'b01; col_row_last_num <= 'b0; end
        else if(row_cnt+gp_k_size+gp_k_size-1<gp_m_size+gp_k_size-1)  begin col_row_type <= 2'b10; col_row_last_num <= (gp_m_size-row_cnt-gp_k_size); end
        else                                                begin col_row_type <= 2'b11; col_row_last_num <= 'b0; end
        col_row_last_row  <= (row_cnt+gp_k_size>=(gp_m_size-1));
      end
    
    if(col_row_done) begin
      round_done  <= fout_flag&fin_flag&row_flag&batch_flag;
      fout_cnt    <= fout_flag                                ? 'b0                                             : (fout_cnt+gp_fout_stride); 
      fin_cnt     <= fout_flag                                ? ( fin_flag    ? 'b0 : (fin_cnt+gp_fin_stride))  : fin_cnt;
      row_cnt     <= (fout_flag&fin_flag)                     ? ( row_flag    ? 'b0 : (row_cnt+gp_k_size))      : row_cnt;
      batch_cnt   <= (fout_flag&fin_flag&row_flag)            ? ( batch_flag  ? 'b0 : (batch_cnt+1))            : batch_cnt;
      k_read_cnt  <= (fout_flag&fin_flag&row_flag&batch_flag) ? (k_read_cnt+1)                                  : k_read_cnt;
    end
  end else begin
    col_row_go  <= 'b0;
    round_done  <= 'b0;
    fin_cnt     <= 'b0;
    rowInKer_cnt<= 'b0;
    fout_cnt    <= 'b0;
    row_cnt     <= 'b0;
    batch_cnt   <= 'b0;
    col_row_type      <= 'b0;
    col_row_last_num  <= 'b0;
    col_row_last_row  <= 'b0;
    row_info_vld    <= 'b0;
    row_info_data   <= 'b0;
    if(n_state==LAYER_DONE) k_read_cnt  <= 'b0;
  end
end


dcnn_s0_memif_input #(DW,AW,K_BITS,M_BITS) 
s0_memif_input(
  .clk,
  .rst_n,
  .arst_n,
  .col_row_go,
  .col_row_done,
  .col_row_type, // 0: first col-row; 1: middle col-row; 2: last-row with parts of image; 3: all-data is padding data
  .col_row_last_num,
  .col_row_last_row,
  .col_row_fout_set,
  .gp_k_size,
  .gp_m_size,
  .stream_r_vld,
  .stream_r_rdy,
  .stream_r_data,
  .w_inner_vld,
  .w_inner_rdy,
  .w_inner_data,
  .r_inner_vld,
  .r_inner_rdy,
  .r_inner_data,
  .cache_fifo_r_vld,
  .cache_fifo_r_rdy,
  .cache_fifo_r_data,
  .cache_fifo_w_vld,
  .cache_fifo_w_rdy,
  .cache_fifo_w_data,
  .image_stream_out_vld,
  .image_stream_out_valid,
  .image_stream_out_rdy,
  .image_stream_out
  );


// For stage LAYER_DONE
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  layer_finish  <= 'b0;
end else if(!rst_n) begin
  layer_finish  <= 'b0;
end else begin
  if(n_state==LAYER_DONE) 
    layer_finish  <= 'b1;
  else
    layer_finish  <= 'b0;
end

endmodule