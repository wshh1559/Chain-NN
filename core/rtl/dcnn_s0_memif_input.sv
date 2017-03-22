`timescale 1ns/1ps
module dcnn_s0_memif_input
#(parameter DW = 32,
            AW = 32,
            K_BITS = 4,
            M_BITS = 10)
(
  clk,
  rst_n,
  arst_n,
  
  // kernel_size
  col_row_go,
  col_row_done,
  col_row_type, // 0: first col-row; 1: middle col-row; 2: last-row with parts of image; 3: all-data is padding data
  col_row_last_num,
  col_row_last_row,
  col_row_fout_set,
  gp_k_size,
  gp_m_size,
  
  // DRAM FIFO interface
  stream_r_vld,
  stream_r_rdy,
  stream_r_data,
  
  // if with input reuse cache
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
  cache_fifo_w_vld,
  cache_fifo_w_rdy,
  cache_fifo_w_data,
  
  // Image
  image_stream_out_vld,
  image_stream_out_valid,
  image_stream_out_rdy,
  image_stream_out
);

input                     clk;
input                     rst_n;
input                     arst_n;

input         [K_BITS-1:0]    gp_k_size;
input         [M_BITS-1:0]    gp_m_size;
input                         col_row_go;
output  logic                 col_row_done;
input         [1:0]           col_row_type;
input         [K_BITS-1:0]    col_row_last_num;
input                         col_row_last_row;
input         [1:0]           col_row_fout_set;

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

input                     cache_fifo_r_vld[0:1];
output  logic             cache_fifo_r_rdy[0:1];
input         [DW-1:0]    cache_fifo_r_data[0:1];
output  logic             cache_fifo_w_vld[0:1];
input                     cache_fifo_w_rdy[0:1];
output  logic [DW-1:0]    cache_fifo_w_data[0:1];

output  logic             image_stream_out_vld[0:1];
output  logic [1:0]       image_stream_out_valid;
input                     image_stream_out_rdy[0:1];
output  logic [DW-1:0]    image_stream_out[0:1];

logic   enable;
//assign  enable = stream_r_vld[0] & stream_r_vld[1] & cache_fifo_r_vld[0] & cache_fifo_r_vld[1] & cache_fifo_w_rdy[0] & cache_fifo_w_rdy[1] & image_stream_out_rdy[0] & image_stream_out_rdy[1];
//assign  enable = stream_r_vld[0] & stream_r_vld[1] & image_stream_out_rdy[0] & image_stream_out_rdy[1]; //FIXME
assign  enable = image_stream_out_rdy[0]; //FIXME

// FSM
logic         [1:0]       state, n_state;
parameter   IDLE    = 2'd0,
            GOGO    = 2'd1,
            DONE    = 2'd2;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n)     state <= IDLE;
else if(!rst_n) state <= IDLE;
else            if(enable)  state <= n_state;

logic   [15:0]          cnt;
logic   [M_BITS-1:0]    cur_x_odd, cur_x_even;
logic   [M_BITS-1:0]    cur_y_odd, cur_y_even;
always_comb
begin
  n_state = IDLE;
  case(state)
    IDLE:   if(col_row_go)  n_state = GOGO;
    GOGO:   if(((cur_x_odd+1==gp_m_size+gp_k_size-1)&&(cur_y_odd+1>=(gp_k_size<<1)))||((cur_x_even+1==gp_m_size+gp_k_size-1)&&(cur_y_even+1>=(gp_k_size<<1))))   n_state = DONE; else  n_state = state;
    default:if(col_row_go)  n_state = GOGO; else  n_state = state;
  endcase
end

// Internal logic for location
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin 
  cnt <= 'd0;
  cur_x_odd <= 'd0; 
  cur_y_odd <= 'd0; 
  cur_x_even <= 'd1; 
  cur_y_even <= 'd0; 
end else if(!rst_n) begin 
  cnt <= 'd0;
  cur_x_odd <= 'd0; 
  cur_y_odd <= 'd0; 
  cur_x_even <= 'd1; 
  cur_y_even <= 'd0; 
end else begin 
  if(enable) begin
    if(n_state!=GOGO) begin
      cnt <= 'd0;
      cur_x_odd <= 'd0; 
      cur_y_odd <= 'd0; 
      cur_x_even <= 'd1; 
      cur_y_even <= 'd0; 
    end else if(n_state==GOGO) begin
      cnt <= cnt + 1;
      cur_x_odd <= ((cur_y_odd+1)==(gp_k_size<<1)) ? (cur_x_odd+2) : cur_x_odd;
      cur_y_odd <= ((cur_y_odd+1)==(gp_k_size<<1)) ? 'd0 : (cur_y_odd+1);
      if(cnt>=gp_k_size) begin
        cur_x_even <= ((cur_y_even+1)==(gp_k_size<<1)) ? (cur_x_even+2) : cur_x_even;
        cur_y_even <= ((cur_y_even+1)==(gp_k_size<<1)) ? 'd0 : (cur_y_even+1);
      end

    end
  end
end

// Output of col_row_done
always_ff@(posedge clk or negedge arst_n)
if(!arst_n)     col_row_done <= 'd0;
else if(!rst_n) col_row_done <= 'd0;
else            if(enable)  col_row_done <= (n_state==DONE) & (state==GOGO);

// Output of stream_r_rdy
assign  cache_fifo_w_data[0] = image_stream_out[0];
assign  cache_fifo_w_data[1] = image_stream_out[1];
// Output with inner fifo
logic             pre_r_rdy[0:1];
assign  stream_r_rdy[0]        = col_row_fout_set[1] & pre_r_rdy[0];
assign  stream_r_rdy[1]        = col_row_fout_set[1] & pre_r_rdy[1];
assign  w_inner_vld[0]  = !col_row_fout_set[0] & pre_r_rdy[0];
assign  w_inner_vld[1]  = !col_row_fout_set[0] & pre_r_rdy[1];
assign  r_inner_rdy[0]  = !col_row_fout_set[1] & pre_r_rdy[0];
assign  r_inner_rdy[1]  = !col_row_fout_set[1] & pre_r_rdy[1];

assign  w_inner_data[0:1] = col_row_fout_set[1] ? stream_r_data[0:1] : r_inner_data[0:1];
logic   pre_cache_fifo_w_vld[0:1];
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin 
  pre_r_rdy[0:1]                <= {'b0,'b0};
  cache_fifo_r_rdy[0:1]     <= {'b0,'b0};
  cache_fifo_w_vld[0:1]     <= {'b0,'b0};
  pre_cache_fifo_w_vld[0:1] <= {'b0,'b0};
end else if(!rst_n) begin 
  pre_r_rdy[0:1]                <= {'b0,'b0};
  cache_fifo_r_rdy[0:1]     <= {'b0,'b0};
  cache_fifo_w_vld[0:1]     <= {'b0,'b0};
  pre_cache_fifo_w_vld[0:1] <= {'b0,'b0};
end else begin 
  if(enable) begin
    if(n_state==GOGO) begin
      case(col_row_type) 
        2'b10:  begin     // 2: last-row with parts of image;
          if(cur_x_odd<gp_m_size)  begin
            cache_fifo_r_rdy[0]     <= ( cur_y_odd < (gp_k_size-1) );
            pre_r_rdy[0]            <= ((cur_y_odd+1)<(col_row_last_num+gp_k_size)) && (cur_y_odd>=(gp_k_size-1));      // diff parts 
            pre_cache_fifo_w_vld[0] <= !col_row_last_row & ((cur_y_odd+1)!=(gp_k_size<<1)) && (cur_y_odd>=gp_k_size);
          end else if(cur_x_odd<gp_m_size+gp_k_size-1) begin
            cache_fifo_r_rdy[0]     <= 'b0;
            pre_r_rdy[0]            <= 'b0;      // diff parts 
            pre_cache_fifo_w_vld[0] <= 'b0;
          end
          if(cur_x_even<gp_m_size)  begin
            if(cnt>=gp_k_size) begin
              cache_fifo_r_rdy[1]     <= ( cur_y_even < (gp_k_size-1) );
              pre_r_rdy[1]            <= ((cur_y_even+1)<(col_row_last_num+gp_k_size)) && (cur_y_even>=(gp_k_size-1));  // diff parts 
              pre_cache_fifo_w_vld[1] <= !col_row_last_row & ((cur_y_even+1)!=(gp_k_size<<1)) && (cur_y_even>=gp_k_size);
            end 
          end else if(cur_x_even<gp_m_size+gp_k_size-1) begin
            cache_fifo_r_rdy[1]     <= 'b0;
            pre_r_rdy[1]            <= 'b0;      // diff parts 
            pre_cache_fifo_w_vld[1] <= 'b0;
          end
        end
        2'b11:  begin     // 3: all-data is padding data
          if(cur_x_odd<gp_m_size)  begin
            cache_fifo_r_rdy[0]     <= ( cur_y_odd < (gp_k_size-1) );
            pre_r_rdy[0]            <= 'b0;      // diff parts 
            pre_cache_fifo_w_vld[0] <= !col_row_last_row & ((cur_y_odd+1)!=(gp_k_size<<1)) && (cur_y_odd>=gp_k_size);
          end else if(cur_x_odd<gp_m_size+gp_k_size-1) begin
            cache_fifo_r_rdy[0]     <= 'b0;
            pre_r_rdy[0]            <= 'b0;      // diff parts 
            pre_cache_fifo_w_vld[0] <= 'b0;
          end
          if(cur_x_even<gp_m_size)  begin
            if(cnt>=gp_k_size) begin
              cache_fifo_r_rdy[1]     <= ( cur_y_even < (gp_k_size-1) );
              pre_r_rdy[1]            <= 'b0;  // diff parts 
              pre_cache_fifo_w_vld[1] <= !col_row_last_row & ((cur_y_even+1)!=(gp_k_size<<1)) && (cur_y_even>=gp_k_size);
            end
          end else if(cur_x_even<gp_m_size+gp_k_size-1) begin
            cache_fifo_r_rdy[1]     <= 'b0;
            pre_r_rdy[1]            <= 'b0;      // diff parts 
            pre_cache_fifo_w_vld[1] <= 'b0;
          end
        end
        default:  begin
          if(cur_x_odd<gp_m_size)  begin
            cache_fifo_r_rdy[0]     <= ( cur_y_odd < (gp_k_size-1) ) & (col_row_type!=2'b00);
            pre_r_rdy[0]            <= ((cur_y_odd+1)!=(gp_k_size<<1)) && (cur_y_odd>=(gp_k_size-1));
            pre_cache_fifo_w_vld[0] <= !col_row_last_row & ((cur_y_odd+1)!=(gp_k_size<<1)) && (cur_y_odd>=gp_k_size);
          end else if(cur_x_odd<gp_m_size+gp_k_size-1) begin
            cache_fifo_r_rdy[0]     <= 'b0;
            pre_r_rdy[0]            <= 'b0;      // diff parts 
            pre_cache_fifo_w_vld[0] <= 'b0;
          end
          if(cur_x_even<gp_m_size)  begin
            if(cnt>=gp_k_size) begin
              cache_fifo_r_rdy[1]     <= ( cur_y_even < (gp_k_size-1) ) & (col_row_type!=2'b00);
              pre_r_rdy[1]            <= ((cur_y_even+1)!=(gp_k_size<<1)) && (cur_y_even>=(gp_k_size-1));
              pre_cache_fifo_w_vld[1] <= !col_row_last_row & ((cur_y_even+1)!=(gp_k_size<<1)) && (cur_y_even>=gp_k_size);
            end
          end else if(cur_x_even<gp_m_size+gp_k_size-1) begin
            cache_fifo_r_rdy[1]     <= 'b0;
            pre_r_rdy[1]            <= 'b0;      // diff parts 
            pre_cache_fifo_w_vld[1] <= 'b0;
          end
        end
      endcase

    end else begin
      pre_r_rdy[0:1]                <= {'b0,'b0};
      cache_fifo_r_rdy[0:1]     <= {'d0,'b0};
      pre_cache_fifo_w_vld[0:1] <= {'d0,'b0};
    end 
    {cache_fifo_w_vld[0],cache_fifo_w_vld[1]} <= {pre_cache_fifo_w_vld[0],pre_cache_fifo_w_vld[1]};
  end
end

// Delay of cnt, cur_y
logic   [1:0]           state_d;
logic   [15:0]          cnt_d, cnt_2d;
logic   [M_BITS-1:0]    cur_y_odd_d, cur_y_odd_2d;
logic   [M_BITS-1:0]    cur_y_even_d, cur_y_even_2d;
logic   [M_BITS-1:0]    cur_x_odd_d, cur_x_even_d;
logic   [1:0]           col_row_type_d, col_row_type_2d;
logic   [K_BITS-1:0]    col_row_last_num_d, col_row_last_num_2d;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin 
  {state_d, cnt_d,cnt_2d,cur_y_odd_d,cur_y_odd_2d,cur_y_even_d,cur_y_even_2d,cur_x_odd_d, cur_x_even_d} <= 'd0;
  {col_row_type_d, col_row_type_2d,col_row_last_num_d, col_row_last_num_2d} <= 'd0;
end else if(!rst_n) begin 
  {state_d, cnt_d,cnt_2d,cur_y_odd_d,cur_y_odd_2d,cur_y_even_d,cur_y_even_2d,cur_x_odd_d, cur_x_even_d} <= 'd0;
  {col_row_type_d, col_row_type_2d,col_row_last_num_d, col_row_last_num_2d} <= 'd0;
end else begin 
  if(enable) begin
    {state_d, cnt_d,cnt_2d,cur_y_odd_d,cur_y_odd_2d,cur_y_even_d,cur_y_even_2d,cur_x_odd_d, cur_x_even_d} <= {state,cnt,cnt_d,cur_y_odd,cur_y_odd_d,cur_y_even,cur_y_even_d,cur_x_odd,cur_x_even};
    {col_row_type_d, col_row_type_2d,col_row_last_num_d, col_row_last_num_2d} <= {col_row_type,col_row_type_d,col_row_last_num,col_row_last_num_d};
  end
end



// Output of stream side
logic   [DW-1:0]    pre_r_data[0:1];
assign  pre_r_data[0] = col_row_fout_set[1] ? stream_r_data[0] : r_inner_data[0];
assign  pre_r_data[1] = col_row_fout_set[1] ? stream_r_data[1] : r_inner_data[1];
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin 
  image_stream_out_vld[0:1] <= {'b0,'b0};
  image_stream_out[0:1]     <= {'b0,'b0};
  image_stream_out_valid    <= 'b0;
end else if(!rst_n) begin 
  image_stream_out_vld[0:1] <= {'b0,'b0};
  image_stream_out[0:1]     <= {'b0,'b0};
  image_stream_out_valid    <= 'b0;
end else begin 
  if(enable) begin
    if(state==GOGO) begin
      if((cur_x_odd_d==0)&(cur_y_odd_d==gp_k_size-1))   image_stream_out_valid    <= 2'b11;
      else                                              image_stream_out_valid[1] <= 1'b0;
    
      case(col_row_type_d)
        2'b00:  begin
          if(cur_x_odd_d<gp_m_size)  begin
            if(cur_y_odd_d<(gp_k_size-1))            begin image_stream_out[0] <= 'b0;                   image_stream_out_vld[0] <= 'b1; end
            else if(cur_y_odd_d<((gp_k_size<<1)-1))  begin image_stream_out[0] <= pre_r_data[0];         image_stream_out_vld[0] <= 'b1; end
            else                                  begin image_stream_out[0] <= 'b0;                   image_stream_out_vld[0] <= 'b0; end
          end else if(cur_x_odd_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_odd_d<((gp_k_size<<1)-1))     begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b1; end
            else                                begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b0; end
          end
          
          if(cur_x_even_d<gp_m_size)  begin
            if(cnt_d>=gp_k_size) begin
              if(cur_y_even_d<(gp_k_size-1))             begin image_stream_out[1] <= 'b0;                   image_stream_out_vld[1] <= 'b1; end
              else if(cur_y_even_d<((gp_k_size<<1)-1))   begin image_stream_out[1] <= pre_r_data[1];         image_stream_out_vld[1] <= 'b1; end
              else                                    begin image_stream_out[1] <= 'b0;                   image_stream_out_vld[1] <= 'b0; end
            end
          end else if(cur_x_even_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_even_d<((gp_k_size<<1)-1))    begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b1; end
            else                                begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b0; end
          end
        end
        2'b01:  begin
          if(cur_x_odd_d<gp_m_size)  begin
            if(cur_y_odd_d<(gp_k_size-1))            begin image_stream_out[0] <= cache_fifo_r_data[0];  image_stream_out_vld[0] <= 'b1; end
            else if(cur_y_odd_d<((gp_k_size<<1)-1))  begin image_stream_out[0] <= pre_r_data[0];         image_stream_out_vld[0] <= 'b1; end
            else                                  begin image_stream_out[0] <= 'b0;                   image_stream_out_vld[0] <= 'b0; end
          end else if(cur_x_odd_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_odd_d<((gp_k_size<<1)-1))     begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b1; end
            else                                begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b0; end
          end
          
          if(cur_x_even_d<gp_m_size)  begin
            if(cnt_d>=gp_k_size) begin
              if(cur_y_even_d<(gp_k_size-1))             begin image_stream_out[1] <= cache_fifo_r_data[1];   image_stream_out_vld[1] <= 'b1; end
              else if(cur_y_even_d<((gp_k_size<<1)-1))   begin image_stream_out[1] <= pre_r_data[1];          image_stream_out_vld[1] <= 'b1; end
              else                                    begin image_stream_out[1] <= 'b0;                    image_stream_out_vld[1] <= 'b0; end
            end
          end else if(cur_x_even_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_even_d<((gp_k_size<<1)-1))    begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b1; end
            else                                begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b0; end
          end
        end
        2'b10:  begin
          if(col_row_last_num==0) $display("Error: Last row should have row numbers not equal to 0!");
          if(cur_x_odd_d<gp_m_size)  begin
            if(cur_y_odd_d<(gp_k_size-1))                          begin image_stream_out[0] <= cache_fifo_r_data[0];  image_stream_out_vld[0] <= 'b1; end
            else if(cur_y_odd_d<(col_row_last_num_d+gp_k_size-1))  begin image_stream_out[0] <= pre_r_data[0];         image_stream_out_vld[0] <= 'b1; end
            else if(cur_y_odd_d<((gp_k_size<<1)-1))                begin image_stream_out[0] <= 'b0;                   image_stream_out_vld[0] <= 'b1; end
            else                                                begin image_stream_out[0] <= 'b0;                   image_stream_out_vld[0] <= 'b0; end
          end else if(cur_x_odd_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_odd_d<((gp_k_size<<1)-1))     begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b1; end
            else                                begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b0; end
          end
          
          if(cur_x_even_d<gp_m_size)  begin
            if(cnt_d>=gp_k_size) begin
              if(cur_y_even_d<(gp_k_size-1))                         begin image_stream_out[1] <= cache_fifo_r_data[1];  image_stream_out_vld[1] <= 'b1; end
              else if(cur_y_even_d<(col_row_last_num_d+gp_k_size-1)) begin image_stream_out[1] <= pre_r_data[1];         image_stream_out_vld[1] <= 'b1; end
              else if(cur_y_even_d<((gp_k_size<<1)-1))               begin image_stream_out[1] <= 'b0;                   image_stream_out_vld[1] <= 'b1; end
              else                                                begin image_stream_out[1] <= 'b0;                   image_stream_out_vld[1] <= 'b0; end
            end
          end else if(cur_x_even_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_even_d<((gp_k_size<<1)-1))    begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b1; end
            else                                begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b0; end
          end
        end
        default:  begin
          if(cur_x_odd_d<gp_m_size)  begin
            if(cur_y_odd_d<(gp_k_size-1))                          begin image_stream_out[0] <= cache_fifo_r_data[0];  image_stream_out_vld[0] <= 'b1; end
            else if(cur_y_odd_d<((gp_k_size<<1)-1))                begin image_stream_out[0] <= 'b0;                   image_stream_out_vld[0] <= 'b1; end
            else                                                begin image_stream_out[0] <= 'b0;                   image_stream_out_vld[0] <= 'b0; end
          end else if(cur_x_odd_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_odd_d<((gp_k_size<<1)-1))     begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b1; end
            else                                begin image_stream_out[0] <= 'b0;       image_stream_out_vld[0] <= 'b0; end
          end
          
          if(cur_x_even_d<gp_m_size)  begin
            if(cnt_d>=gp_k_size) begin
              if(cur_y_even_d<(gp_k_size-1))                         begin image_stream_out[1] <= cache_fifo_r_data[1];  image_stream_out_vld[1] <= 'b1; end
              else if(cur_y_even_d<((gp_k_size<<1)-1))               begin image_stream_out[1] <= 'b0;                   image_stream_out_vld[1] <= 'b1; end
              else                                                begin image_stream_out[1] <= 'b0;                   image_stream_out_vld[1] <= 'b0; end
            end
          end else if(cur_x_even_d<gp_m_size+gp_k_size-1) begin
            if(cur_y_even_d<((gp_k_size<<1)-1))    begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b1; end
            else                                begin image_stream_out[1] <= 'b0;       image_stream_out_vld[1] <= 'b0; end
          end
        end
      endcase
    end else begin
      image_stream_out_valid    <= 2'b00;
      image_stream_out_vld[0:1] <= {'b0,'b0};
      image_stream_out[0:1]     <= {'b0,'b0};
      //image_stream_out_vld[0] <= 'b0;
      //image_stream_out_vld[1] <= 'b0; 
      //image_stream_out[0] <= 'b0; 
      //image_stream_out[1] <= 'b0; 
    end
  end
end

endmodule