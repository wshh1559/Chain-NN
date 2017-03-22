`timescale 1ns/1ps
module dcnn_s2_memif_output
#(parameter DW = 32,
            AW = 32,
            K_BITS = 4,
            M_BITS = 10,
            MAX_PARA_OUT = 64,
            MAX_PARA_OUT_BIT = 7,
            PARA = 9)
(
  clk,
  rst_n,
  arst_n,
  
  para_out_num,
  
  // row task FIFO interface
  row_task_vld,
  row_task_rdy,
  row_task_data,
  
  psum_out,
  psum_out_vld,
  
  // OUTPUT cache interface
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
  
  // Output fifo to dram 
  dram_w_vld,
  dram_w_rdy,
  dram_w_data,
  dram_w_last,
  
  // gp
  gp_fout_num,
  gp_fout_stride,
  gp_k_size,
  gp_m_size,
  gp_n_size
  
);

input                     clk;
input                     rst_n;
input                     arst_n;

input         [MAX_PARA_OUT_BIT-1:0]  para_out_num;

input                     row_task_vld;
output  logic             row_task_rdy;
input         [2:0]       row_task_data;

// input from PE_chain
input         [DW-1:0]    psum_out[0:MAX_PARA_OUT-1];
input                     psum_out_vld[0:MAX_PARA_OUT-1];

// ping-pong fifo
input         [MAX_PARA_OUT-1:0]        output_ping_r_vld;
output  logic [MAX_PARA_OUT-1:0]        output_ping_r_rdy;
input         [DW-1:0]                  output_ping_r_data[0:MAX_PARA_OUT-1];
output  logic [MAX_PARA_OUT-1:0]        output_ping_w_vld;
input         [MAX_PARA_OUT-1:0]        output_ping_w_rdy;
output  logic [DW-1:0]                  output_ping_w_data[0:MAX_PARA_OUT-1];
input         [MAX_PARA_OUT-1:0]        output_pong_r_vld;
output  logic [MAX_PARA_OUT-1:0]        output_pong_r_rdy;
input         [DW-1:0]                  output_pong_r_data[0:MAX_PARA_OUT-1];
output  logic [MAX_PARA_OUT-1:0]        output_pong_w_vld;
input         [MAX_PARA_OUT-1:0]        output_pong_w_rdy;
output  logic [DW-1:0]                  output_pong_w_data[0:MAX_PARA_OUT-1];




output  logic             dram_w_vld;
input                     dram_w_rdy;
output  logic [DW-1:0]    dram_w_data;
output  logic             dram_w_last;

input         [9:0]         gp_fout_num;
input         [6:0]         gp_fout_stride;
input         [K_BITS-1:0]  gp_k_size;
input         [M_BITS-1:0]  gp_m_size;
input         [M_BITS-1:0]  gp_n_size;


logic   data_in_first, data_in_last, data_in_vld,not_used;
assign  data_in_vld = psum_out_vld[0];
assign  {not_used,data_in_first, data_in_last} = row_task_data;


logic   buffer_ptr, w_buf_done, r_buf_done;   // buffer_ptr indicates write buffer
logic   psum_out_vld_d;
logic   [M_BITS-1:0]    d_cnt;
logic                   d_cnt_flag;
assign  d_cnt_flag = d_cnt+1 >= gp_m_size+gp_k_size;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin 
  buffer_ptr  <= 'b0;
  w_buf_done  <= 'b0;
  row_task_rdy    <= 'b0;
  psum_out_vld_d  <= 'b0;
  d_cnt <= 'b0;
end else if(!rst_n) begin 
  buffer_ptr  <= 'b0;
  w_buf_done  <= 'b0;
  row_task_rdy    <= 'b0;
  psum_out_vld_d  <= 'b0;
  d_cnt <= 'b0;
end else begin 
  if(w_buf_done & r_buf_done) buffer_ptr <= !buffer_ptr;

  psum_out_vld_d  <= psum_out_vld[0];

  row_task_rdy  <= (psum_out_vld_d & !psum_out_vld[0]);
  w_buf_done  <= w_buf_done ? (!(w_buf_done & r_buf_done)) : (data_in_last & (psum_out_vld_d & !psum_out_vld[0]));

end

// DRAM read side cnt
logic   [MAX_PARA_OUT-1:0]    fout_cnt;
logic   [MAX_PARA_OUT-1:0]    fround_cnt;
logic   [15:0]                pixel_cnt;
assign    dram_w_last = !row_task_vld & dram_w_vld & r_buf_done;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  fout_cnt    <= 'b0;
  fround_cnt  <= 'b0;
  pixel_cnt   <= 'b0;
  r_buf_done  <= 'b1;
  dram_w_vld  <= 'b0;
  dram_w_data <= 'b0;
end else if(!rst_n) begin
  fout_cnt    <= 'b0;
  fround_cnt  <= 'b0;
  pixel_cnt   <= 'b0;
  r_buf_done  <= 'b1;
  dram_w_vld  <= 'b0;
  dram_w_data <= 'b0;
end else begin
  if(dram_w_rdy) begin
    if(!r_buf_done) begin
      fout_cnt        <= ((fround_cnt+1>=gp_fout_stride)&(pixel_cnt+1==gp_k_size*gp_n_size)) ? ((fout_cnt+gp_fout_stride>=gp_fout_num) ? 'b0 : (fout_cnt+gp_fout_stride)) : fout_cnt;
      fround_cnt      <= (pixel_cnt+1==gp_k_size*gp_n_size) ? ((fround_cnt+1>=gp_fout_stride) ? 'b0 : (fround_cnt+1)) : fround_cnt;
      pixel_cnt       <= (pixel_cnt+1==gp_k_size*gp_n_size) ? 'b0 : (pixel_cnt+1);
    end else begin
      fout_cnt  <= 'b0;
      fround_cnt<= 'b0;
      pixel_cnt <= 'b0;
    end
    r_buf_done  <= r_buf_done ? (!(w_buf_done & r_buf_done)) : ((pixel_cnt+1==gp_k_size*gp_n_size)&(fround_cnt+1==gp_fout_stride)&(fout_cnt+gp_fout_stride>=gp_fout_num));

    
    dram_w_vld  <= buffer_ptr ? output_ping_r_vld[fround_cnt] : output_pong_r_vld[fround_cnt];
    dram_w_data <= buffer_ptr ? output_ping_r_data[fround_cnt] : output_pong_r_data[fround_cnt];
  end
end

logic signed  [DW-1:0]    psum_add[0:MAX_PARA_OUT-1];
logic signed  [DW:0]      psum_add_tmp[0:MAX_PARA_OUT-1];
generate
  for(genvar i = 0; i < MAX_PARA_OUT; i++ ) begin: write_fifo    
    assign  output_ping_r_rdy[i] = (buffer_ptr=='b0) ? ((data_in_vld & i<para_out_num)? !data_in_first :'b0) : ((!r_buf_done)?(i==fround_cnt & dram_w_rdy):'b0);
    assign  output_pong_r_rdy[i] = (buffer_ptr=='b0) ? ((!r_buf_done)?(i==fround_cnt & dram_w_rdy):'b0) : ((data_in_vld & i<para_out_num)?(!data_in_first):'b0);
    assign  psum_add_tmp[i] = (buffer_ptr=='b0) ? ($signed(psum_out[i]) + $signed(output_ping_r_data[i])) : ($signed(psum_out[i]) + $signed(output_pong_r_data[i]));
    assign  psum_add[i] = (psum_add_tmp[i] >= 32768) ? 32767 : ((psum_add_tmp[i] < -32768) ? -32768 : psum_add_tmp[i][DW-1:0]);;
  
    always_ff@(posedge clk or negedge arst_n)
    if(!arst_n) begin 
      output_ping_w_vld[i]                  <= 'b0;
      output_pong_w_vld[i]                  <= 'b0;
      output_ping_w_data[i]                 <= 'b0;
      output_pong_w_data[i]                 <= 'b0;
    end else if(!rst_n) begin 
      output_ping_w_vld[i]                  <= 'b0;
      output_pong_w_vld[i]                  <= 'b0;
      output_ping_w_data[i]                 <= 'b0;
      output_pong_w_data[i]                 <= 'b0;
    end else begin 
      if(buffer_ptr=='b0) begin
        // write buffer
        if(data_in_vld & i<para_out_num) begin
          output_ping_w_vld[i]    <= 'b1;
          //output_ping_w_data[i]   <= data_in_first ? psum_out[i] : (psum_out[i] + output_ping_r_data[i]);  //FIXME, 32-b adder
          output_ping_w_data[i]   <= data_in_first ? psum_out[i] : psum_add[i];  //FIXME, 32-b adder
        end else begin
          output_ping_w_vld[i]    <= 'b0;
          output_ping_w_data[i]   <= 'b0;
        end
      end else begin
        // write_buffer
        if(data_in_vld & i<para_out_num) begin
          output_pong_w_vld[i]    <= 'b1;
          //output_pong_w_data[i]   <= data_in_first ? psum_out[i] : (psum_out[i] + output_pong_r_data[i]);
          output_pong_w_data[i]   <= data_in_first ? psum_out[i] : psum_add[i];
        end else begin
          output_pong_w_vld[i]    <= 'b0;
          output_pong_w_data[i]   <= 'b0;
        end
      end
    end
  end
endgenerate


endmodule