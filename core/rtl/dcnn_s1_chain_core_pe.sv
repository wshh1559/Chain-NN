`timescale 1ns/1ps
module dcnn_s1_chain_core_pe
#(parameter DW = 16,
            K_BITS = 4,
            M_BITS = 10,
            PARA  = 144)
(
  clk,
  rst_n,
  arst_n,
  
  // control signal
  entrance_flag,
  entrance_attribute,
  mode_kernel_load,
  idx_pe,
  
  // kernel_size
  k_size,
  
  // Image
  x_in,
  x_entrance,
  x_out,
  
  // Psum
  y_in,
  y_in_vld,
  y_entrance_vld,
  y_out,
  y_out_vld
);

input                       clk;
input                       rst_n;
input                       arst_n;
  
input                       entrance_flag;
input                       entrance_attribute;
input                       mode_kernel_load;
input         [9:0]         idx_pe;

input         [K_BITS-1:0]  k_size;

input         [DW-1:0]      x_in[0:1];
input         [DW-1:0]      x_entrance[0:1];
input         [1:0]         y_entrance_vld;     //[1]: x_start; [0]:x_entrance_vld
output  reg   [DW-1:0]      x_out[0:1];
input         [DW-1:0]      y_in;
input         [1:0]         y_in_vld;
output  reg   [DW-1:0]      y_out;
output  reg   [1:0]         y_out_vld;

logic         [DW-1:0]      weight_in;
logic                       w_update;


logic signed  [DW-1:0]    x_sel, y_sel;
logic   [1:0]             y_vld_sel;
logic signed  [DW-1:0]    psum_add;
logic signed  [DW:0]      psum_add_tmp;
logic signed  [DW*2+1:0]  psum_multi, psum_multi_tmp;
logic         [K_BITS-1:0]  cnt;
logic                       r_odd_even;
logic                       odd_even;

`ifndef PIPE
  assign  odd_even  = (y_vld_sel[1] ? entrance_attribute : r_odd_even);
  assign  x_sel     = entrance_flag ? (odd_even ? x_entrance[1] : x_entrance[0]) : (odd_even ? x_in[1] : x_in[0]);
  assign  y_sel     = entrance_flag ? 0 : y_in;
  assign  y_vld_sel = entrance_flag ? y_entrance_vld : y_in_vld;
`else
  logic [2:0]         entrance_flag_d;
  always_ff@(posedge clk or negedge arst_n)
  if(!arst_n)         entrance_flag_d   <= 'b0;
  else if(!rst_n)     entrance_flag_d   <= 'b0;
  else                entrance_flag_d   <= {entrance_flag_d[1:0],entrance_flag};
  
  assign  odd_even  = (y_vld_sel[1] ? entrance_attribute : r_odd_even);
  assign  x_sel     = entrance_flag ? (odd_even ? x_entrance[1] : x_entrance[0]) : (odd_even ? x_in[1] : x_in[0]);
  `ifndef PIPE_MUL
    assign  y_sel     = entrance_flag_d[0] ? 0 : y_in;
  `else
    `ifndef PIPE_MUL_PRE
      assign  y_sel     = entrance_flag_d[1] ? 0 : y_in;
    `else
      assign  y_sel     = entrance_flag_d[2] ? 0 : y_in;
    `endif
  `endif
  assign  y_vld_sel = entrance_flag ? y_entrance_vld : y_in_vld;

`endif

logic [DW-1:0]  x_sel_lat;
logic           zero_gate_n;
logic [2:0]         zero_gate_n_delay;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n)         zero_gate_n_delay   <= 'b0;
else if(!rst_n)     zero_gate_n_delay   <= 'b0;
else                zero_gate_n_delay   <= {zero_gate_n_delay[1:0],((x_sel!=0) & (weight_in!=0))};
`ifndef PIPE
  assign  zero_gate_n = (x_sel!=0) & (weight_in!=0);
`else
  `ifndef PIPE_MUL
    assign  zero_gate_n = zero_gate_n_delay[0];
  `else 
    `ifndef PIPE_MUL_PRE
      assign  zero_gate_n = zero_gate_n_delay[1];
    `else 
      assign  zero_gate_n = zero_gate_n_delay[2];
    `endif
  `endif
`endif
always_comb begin : proc_
  if((x_sel!=0) & (weight_in!=0)) x_sel_lat <= x_sel;
  else  x_sel_lat <= 'b0;
end


always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  cnt       <= 'b0;
  r_odd_even  <= 'b0;
end else if(!rst_n) begin
  cnt       <= 'b0;
  r_odd_even  <= 'b0;
end else begin
  ///////////////////////////////////////////////////////////////////////////// valid, odd and even column
  if(y_vld_sel[1]) begin
    cnt       <= 'b1;
    r_odd_even  <= entrance_attribute;
  end else begin
    if(y_vld_sel[0]) begin 
      cnt <= (cnt+1==k_size) ? 0 : (cnt+1);
      r_odd_even <= (cnt+1==k_size) ? (!r_odd_even) : r_odd_even;
    end
  end
end

logic   signed [DW-1:0]  signed_w_in, signed_psum_multi;

`ifndef PIPE_MUL
  assign  signed_w_in = $signed(weight_in);
`else
  //logic   signed [DW/2:0]     signed_w_lower;
  //logic   signed [DW/2-1:0]   signed_w_upper;
  //assign  signed_w_upper = $signed(weight_in[DW-1:DW/2]);
  //assign  signed_w_lower = $signed({1'b0,weight_in[DW/2-1:0]});
  //logic   signed [23:0]   signed_psum_lower;
  //logic   signed [22:0]   signed_psum_upper;
  //
  //always_ff@(posedge clk or negedge arst_n)
  //if(!arst_n)         begin signed_psum_upper <= 'b0; signed_psum_lower <= 'b0; end
  //else if(!rst_n)     begin signed_psum_upper <= 'b0; signed_psum_lower <= 'b0; end
  //else                begin signed_psum_upper <=  $signed(x_sel) *signed_w_upper; 
  //                          signed_psum_lower <=  $signed(x_sel) *signed_w_lower; 
  //                    end
    `ifndef PIPE_MUL_PRE
      logic   signed [6:0]    signed_w_lower;
      logic   signed [6:0]    signed_w_upper;
      logic   signed [6:0]    signed_w_mid;
      
      assign  signed_w_upper  = $signed(weight_in[15:10]);
      assign  signed_w_lower  = $signed({1'b0,weight_in[4:0]});
      assign  signed_w_mid    = $signed({1'b0,weight_in[9:5]});
      logic   signed [20:0]   signed_psum_lower;
      logic   signed [20:0]   signed_psum_upper;
      logic   signed [20:0]   signed_psum_mid;
      
      always_ff@(posedge clk or negedge arst_n)
      if(!arst_n)         begin signed_psum_upper <= 'b0; signed_psum_lower <= 'b0; signed_psum_mid <= 'b0; end
      else if(!rst_n)     begin signed_psum_upper <= 'b0; signed_psum_lower <= 'b0; signed_psum_mid <= 'b0; end
      else                begin signed_psum_upper <=  $signed(x_sel_lat) *signed_w_upper; 
                                signed_psum_lower <=  $signed(x_sel_lat) *signed_w_lower; 
                                signed_psum_mid   <=  $signed(x_sel_lat) *signed_w_mid; 
                          end
    `else
      logic [DW-1:0]    x_sel_d, weight_in_d;
      
      always_ff@(posedge clk or negedge arst_n)
      if(!arst_n)         begin x_sel_d <= 'b0; weight_in_d <= 'b0; end
      else if(!rst_n)     begin x_sel_d <= 'b0; weight_in_d <= 'b0; end
      else                begin x_sel_d     <= x_sel_lat; 
                                weight_in_d <= weight_in;
                          end
      logic   signed [6:0]    signed_w_lower;
      logic   signed [6:0]    signed_w_upper;
      logic   signed [6:0]    signed_w_mid;
      
      assign  signed_w_upper  = $signed(weight_in_d[15:10]);
      assign  signed_w_lower  = $signed({1'b0,weight_in_d[4:0]});
      assign  signed_w_mid    = $signed({1'b0,weight_in_d[9:5]});
      logic   signed [20:0]   signed_psum_lower;
      logic   signed [20:0]   signed_psum_upper;
      logic   signed [20:0]   signed_psum_mid;
      
      always_ff@(posedge clk or negedge arst_n)
      if(!arst_n)         begin signed_psum_upper <= 'b0; signed_psum_lower <= 'b0; signed_psum_mid <= 'b0; end
      else if(!rst_n)     begin signed_psum_upper <= 'b0; signed_psum_lower <= 'b0; signed_psum_mid <= 'b0; end
      else                begin signed_psum_upper <=  $signed(x_sel_d) *signed_w_upper; 
                                signed_psum_lower <=  $signed(x_sel_d) *signed_w_lower; 
                                signed_psum_mid   <=  $signed(x_sel_d) *signed_w_mid; 
                          end
    `endif

`endif

`ifndef PIPE
  `ifndef PIPE_MUL
    assign psum_multi_tmp = $signed(x_sel_lat) * signed_w_in + $signed(33'd128);
  `else
    //assign psum_multi_tmp = signed_psum_lower + (signed_psum_upper<<8) + $signed(33'd128);
    assign psum_multi_tmp = signed_psum_lower + (signed_psum_mid<<5) + (signed_psum_upper<<10) + $signed(33'd128);
  `endif
`else
  always_ff@(posedge clk or negedge arst_n)
  if(!arst_n)         psum_multi_tmp <= 'b0;
  else if(!rst_n)     psum_multi_tmp <= 'b0;
  `ifndef PIPE_MUL
    else                psum_multi_tmp <= $signed(x_sel_lat) * signed_w_in + $signed(33'd128);
  `else
    //else                psum_multi_tmp <= signed_psum_lower + (signed_psum_upper<<8) + $signed(33'd128);
    else                psum_multi_tmp <= signed_psum_lower + (signed_psum_mid<<5) + (signed_psum_upper<<10) + $signed(33'd128);
  `endif
`endif

//assign psum_multi_tmp = $signed(x_sel) * signed_w_in + $signed(33'd128);
assign psum_multi         = (psum_multi_tmp >= 8388608) ? 8388607 : ((psum_multi_tmp < -8388608) ? -8388608 : psum_multi_tmp);
assign signed_psum_multi  = $signed({psum_multi[DW*2+1],psum_multi[(DW*3/2)-2:(DW/2)]});
assign psum_add_tmp       = signed_psum_multi + $signed(y_sel);
assign psum_add           = (psum_add_tmp >= 32768) ? 32767 : ((psum_add_tmp < -32768) ? -32768 : $signed(psum_add_tmp[DW-1:0]));


reg   [DW-1:0]    x_inner[0:1];
reg               x_vld_inner;
reg               mode_kernel_load_d;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) begin
  x_out[0:1]  <= {'b0,'b0};
  y_out       <= 'b0;
  y_out_vld   <= 'b0;
  x_inner[0:1]<= {'b0,'b0};
  w_update    <= 'b0;
  mode_kernel_load_d <= 'b0;
end else if(!rst_n) begin
  x_out[0:1]  <= {'b0,'b0};
  y_out       <= 'b0;
  y_out_vld   <= 'b0;
  x_inner[0:1]<= {'b0,'b0};
  w_update    <= 'b0;
  mode_kernel_load_d <= 'b0;
end else begin
  if(mode_kernel_load) begin
    x_out[0:1] <= (idx_pe==PARA) ? x_entrance[0:1] : x_in[0:1];
    x_inner[0:1]  <= {'b0,'b0};
    //w_update <= x_out[0] == idx_pe;
  end else if(mode_kernel_load_d) begin
    x_out[0:1]    <= {'b0,'b0};
    x_inner[0:1]  <= {'b0,'b0};
  end else 

  if((y_vld_sel[0]==1'b0) && (y_out_vld[0]==1'b1)) begin
    x_inner[0:1]  <= {'b0,'b0};
    x_out[0:1]    <= {'b0,'b0};
    w_update      <= 1'b1;
  end else begin
    x_inner[0:1]  <= (entrance_flag ? x_entrance[0:1] : x_in[0:1]);
    x_out[0:1]    <= x_inner[0:1];
    w_update      <= 1'b0;
  end

  y_out         <= mode_kernel_load ? y_in : (zero_gate_n ? $unsigned(psum_add) : $unsigned(y_sel));
  y_out_vld     <= y_vld_sel;
  mode_kernel_load_d <= mode_kernel_load;
end

// inner kernel fifo
logic   [DW-1:0]          p;
logic                     p_val;
logic                     p_rdy;
logic   [DW-1:0]          c;
logic                     c_val;
logic                     c_rdy;

assign  p     = mode_kernel_load ? ((idx_pe==PARA) ? x_entrance[0] : x_in[0]) : 'b0;
assign  p_val = mode_kernel_load ? ((idx_pe==PARA) ? (x_entrance[1][9:0])==idx_pe : (x_in[1][9:0]==idx_pe)) : 1'b0;
assign  weight_in = c;
assign  c_rdy = mode_kernel_load ? 1'b0 : w_update;

`ifndef SMIC40LL
  /*stdcore_rfifo #(DW,400,0) k_fifo  (
    .clk,
    .arst_n,
    .rst_n(!mode_kernel_load | mode_kernel_load_d),
    .p,
    .p_val,
    .p_rdy,
    .c,
    .c_val,
    .c_rdy
  );*/
  stdcore_ker_scratchpad #(DW,256,8) k_fifo(.*);
`else
  //stdcore_rfifo_sram #(DW,256,8) k_fifo  (.pclk(clk),.cclk(clk),.*);
  stdcore_ker_scratchpad #(DW,256,8) k_fifo(.*);
`endif


endmodule