`timescale 1ns/1ps
module dcnn_s1_chain
#(parameter DW = 32,
            PARA = 576,
            K_BITS = 4,
            M_BITS = 10,
            MAX_PARA_OUT = 64,
            MAX_PARA_OUT_BIT = 7)
(
  clk,
  rst_n,
  arst_n,
  
  // control signal
  para_out_num,
  pe_chain_cfg,
  pe_chain_cfg_done,
  kernel_load,
  
  // kernel_size
  k_size,
  
  // Image
  image_para_in_odd,
  image_para_in_even,
  image_para_in_vld,
  
  // Output
  psum_para_out,
  psum_para_out_vld
);

input                     clk;
input                     rst_n;
input                     arst_n;

input         [MAX_PARA_OUT_BIT-1:0]  para_out_num;
input                     pe_chain_cfg;
output  logic             pe_chain_cfg_done;
input                     kernel_load;

input         [K_BITS-1:0]  k_size;

input         [DW-1:0]    image_para_in_odd;
input         [DW-1:0]    image_para_in_even;
input         [1:0]       image_para_in_vld;
output  logic [DW-1:0]    psum_para_out[0:MAX_PARA_OUT-1];
output  logic             psum_para_out_vld[0:MAX_PARA_OUT-1];

logic                     mode_kernel_load;
logic                     en_flag[0:PARA-1];
logic                     en_attribute[0:PARA-1];
logic         [DW-1:0]    image_in_odd[0:PARA-1];
logic         [DW-1:0]    image_in_even[0:PARA-1];
logic         [1:0]       image_in_vld[0:PARA-1];
//logic         [DW-1:0]    weight_in[0:PARA-1];
logic         [DW-1:0]    psum_out[0:PARA-1];
logic         [1:0]       psum_out_vld[0:PARA-1];
dcnn_s1_chain_core #(DW,K_BITS,M_BITS,PARA) pe_chain(
  .clk,
  .rst_n,
  .arst_n,
  .en_flag,
  .en_attribute,
  .mode_kernel_load,
  .k_size,
  .image_in_odd,
  .image_in_even,
  .image_in_vld,
  .psum_out,
  .psum_out_vld
);

// FSM
logic         [1:0]         state, n_state;
logic         [9:0]         cnt;
logic         [K_BITS-1:0]  cnt_col, cnt_row;
parameter   IDLE = 2'd0,
            INIT = 2'd1,
            CFG  = 2'd2,
            CEND = 2'd3;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n)     state <= IDLE;
else if(!rst_n) state <= IDLE;
else            state <= n_state;

always_comb
begin
  n_state = IDLE;
  case(state)
    IDLE: if(pe_chain_cfg) n_state = INIT;
    INIT: n_state = CFG;
    CFG:  if(cnt==PARA) n_state = CEND; else n_state = state;
    default: if(pe_chain_cfg) n_state = INIT; else n_state = state;
  endcase
end

always_ff@(posedge clk or negedge arst_n)
if(!arst_n)     begin 
  cnt <= 'd0; 
  pe_chain_cfg_done <= 'd0; 
  cnt_row <= 'b0;
  cnt_col <= 'b0;
  mode_kernel_load <= 'b0;
end else if(!rst_n) begin 
  cnt <= 'd0; 
  pe_chain_cfg_done <= 'd0; 
  cnt_row <= 'b0;
  cnt_col <= 'b0;
  mode_kernel_load <= 'b0;
end else begin 
  mode_kernel_load <= kernel_load;
  cnt <= (n_state==CFG) ? (cnt+1) : 0;
  if(!pe_chain_cfg_done)  pe_chain_cfg_done <= n_state==CEND;
  else        pe_chain_cfg_done <= n_state==CEND;
  
  cnt_row <= (n_state==CFG) ? (cnt_row==(k_size-1) ? 0 : (cnt_row+1)) : 0;
  cnt_col <= (n_state==CFG) ? (cnt_row==(k_size-1) ? (cnt_col==(k_size-1) ? 0 : (cnt_col+1)) : cnt_col) : 0;
end


// Input Tag assignment
logic     [7:0]         tag_in[0:PARA-1];
always_ff@(posedge clk or negedge arst_n)
if(!arst_n)     begin tag_in[0]  <= 'd0; en_attribute[0] <= 'b0;  end
else if(!rst_n) begin tag_in[0]  <= 'd0; en_attribute[0] <= 'b0;  end
else            begin tag_in[0]  <= 'd0; en_attribute[0] <= !k_size[0];  end
generate
  for(genvar i = 1; i < PARA; i++ ) begin: tag_input_side
    always_ff@(posedge clk or negedge arst_n)
    if(!arst_n) begin
      tag_in[i]  <= 'd0;
      en_attribute[i] <= 'b0;
    end else if(!rst_n) begin
      tag_in[i]  <= 'd0;
      en_attribute[i] <= 'b0;
    end else begin
      if(n_state==CFG && i==cnt) begin
        tag_in[i] <= (cnt_col==0 && cnt_row==0) ? (tag_in[i-1] + 1) : tag_in[i-1];
        en_attribute[i] <= cnt_col[0] ? k_size[0] : (!k_size[0]);
      end else begin
        tag_in[i] <= tag_in[i];
        en_attribute[i] <= en_attribute[i];
      end
    end
  end
endgenerate

// Input Connection
always_ff@(posedge clk or negedge arst_n)
if(!arst_n)     begin en_flag[0]  <= 'd1; image_in_odd[0] <= 'd0;                   image_in_even[0] <= 'd0;                    image_in_vld[0] <= 'b0;                 end
else if(!rst_n) begin en_flag[0]  <= 'd1; image_in_odd[0] <= 'd0;                   image_in_even[0] <= 'd0;                    image_in_vld[0] <= 'b0;                 end
else            begin en_flag[0]  <= 'd1; image_in_odd[0] <= image_para_in_odd;     image_in_even[0] <= image_para_in_even;     image_in_vld[0] <= image_para_in_vld;   end
generate
  for(genvar j = 1; j < PARA; j++) begin: input_connection
    always_ff@(posedge clk or negedge arst_n)
    if(!arst_n) begin
      en_flag[j]      <= 'b0;
      image_in_odd[j] <= 'b0;
      image_in_even[j]<= 'b0;
      image_in_vld[j] <= 'b0;
    end else if(!rst_n) begin
      en_flag[j]      <= 'b0;
      image_in_odd[j] <= 'b0;
      image_in_even[j]<= 'b0;
      image_in_vld[j] <= 'b0;
    end else begin
      if(tag_in[j]!=tag_in[j-1])  en_flag[j] <= 1'd1; 
      else                        en_flag[j] <= 1'd0;
        if(tag_in[j]!=tag_in[j-1]) begin  
          image_in_odd[j]   <= image_para_in_odd;
          image_in_even[j]  <= image_para_in_even;
          image_in_vld[j]   <= image_para_in_vld;
        end
    end
  end
endgenerate

//`ifndef FPGA
// Output Tag assignment
logic     [9:0]     tag_out[MAX_PARA_OUT-1:0];
generate
  for(genvar i = 0; i < MAX_PARA_OUT; i++ ) begin: tag_output_side
    always_ff@(posedge clk or negedge arst_n)
    if(!arst_n) begin
      tag_out[i]  <= 'd0;
    end else if(!rst_n) begin
      tag_out[i]  <= 'd0;
    end else begin
      if(i<para_out_num)  tag_out[i]  <= (i+1)*k_size*k_size - 1;  else tag_out[i]  <= (i+1)*k_size - 1;
    end
  end
endgenerate
//`endif

// Output Connection
`ifdef OPT_OUT
logic   [11:0]    opt_mask;
always_ff@(posedge clk or negedge arst_n)
if(!arst_n) opt_mask  <= 'd0;
else if(!rst_n) opt_mask  <= 'd0;
else begin
  case(k_size)
    1:  opt_mask  <= 12'b000000000001;
    2:  opt_mask  <= 12'b000000000010;
    3:  opt_mask  <= 12'b000000000100;
    4:  opt_mask  <= 12'b000000001000;
    5:  opt_mask  <= 12'b000000010000;
    6:  opt_mask  <= 12'b000000100000;
    7:  opt_mask  <= 12'b000001000000;
    8:  opt_mask  <= 12'b000010000000;
    9:  opt_mask  <= 12'b000100000000;
    10: opt_mask  <= 12'b001000000000;
    11: opt_mask  <= 12'b010000000000;
    default: opt_mask  <= 12'b100000000000;
  endcase
end

logic [DW-1:0]    psum_out_opt[0:MAX_PARA_OUT-1];
generate
  for(genvar idx = 0; idx < MAX_PARA_OUT; idx++) begin:opt_mask_proc
    logic [DW-1:0]  psum_k1_out, psum_k2_out, psum_k3_out, psum_k4_out,
                    psum_k5_out, psum_k6_out, psum_k7_out, psum_k8_out,
                    psum_k9_out, psum_k10_out, psum_k11_out, psum_k12_out;
    always_comb begin
      psum_k1_out   = opt_mask[0]  ? psum_out[1*1*(idx+1)-1]   : 12'd0;
      psum_k2_out   = opt_mask[1]  ? psum_out[2*2*(idx+1)-1]   : 12'd0;
      psum_k3_out   = opt_mask[2]  ? psum_out[3*3*(idx+1)-1]   : 12'd0;
      psum_k4_out   = opt_mask[3]  ? psum_out[4*4*(idx+1)-1]   : 12'd0;
      psum_k5_out   = opt_mask[4]  ? psum_out[5*5*(idx+1)-1]   : 12'd0;
      psum_k6_out   = opt_mask[5]  ? psum_out[6*6*(idx+1)-1]   : 12'd0;
      psum_k7_out   = opt_mask[6]  ? psum_out[7*7*(idx+1)-1]   : 12'd0;
      psum_k8_out   = opt_mask[7]  ? psum_out[8*8*(idx+1)-1]   : 12'd0;
      psum_k9_out   = opt_mask[8]  ? psum_out[9*9*(idx+1)-1]   : 12'd0;
      psum_k10_out  = opt_mask[9]  ? psum_out[10*10*(idx+1)-1] : 12'd0;
      psum_k11_out  = opt_mask[10] ? psum_out[11*11*(idx+1)-1] : 12'd0;
      psum_k12_out  = opt_mask[11] ? psum_out[12*12*(idx+1)-1] : 12'd0;
      psum_out_opt[idx] = psum_k1_out | psum_k2_out | psum_k3_out | psum_k4_out
                        | psum_k5_out | psum_k6_out | psum_k7_out | psum_k8_out
                        | psum_k9_out | psum_k10_out | psum_k11_out | psum_k12_out;
    end
  end
endgenerate
`endif



`ifdef PIPE
logic   [2:0]    psum_out_vld_d[0:PARA-1];
generate
  for(genvar p = 0; p < MAX_PARA_OUT; p++) begin: delay
    always_ff@(posedge clk or negedge arst_n)
    if(!arst_n)     psum_out_vld_d[p] <= 'b0;
    else if(!rst_n) psum_out_vld_d[p] <= 'b0;
    else            psum_out_vld_d[p] <= {psum_out_vld_d[p][1:0],psum_out_vld[tag_out[p]][0]};
  end
endgenerate
`endif
generate
  for(genvar k = 0; k < MAX_PARA_OUT; k++) begin: output_connection
    always_ff@(posedge clk or negedge arst_n)
    if(!arst_n) begin
      psum_para_out[k]      <= 'b0;
      psum_para_out_vld[k]  <= 'b0;
    end else if(!rst_n) begin
      psum_para_out[k]      <= 'b0;
      psum_para_out_vld[k]  <= 'b0;
    end else begin
      if(k<para_out_num)  begin
`ifndef FPGA        
  `ifndef OPT_OUT
        psum_para_out[k]      <= psum_out[tag_out[k]];
  `else
        psum_para_out[k]      <= psum_out_opt[k];
  `endif
        
  `ifndef OPT_OUT
    `ifndef PIPE
          psum_para_out_vld[k]  <= psum_out_vld[tag_out[k]][0];
    `else
      `ifndef PIPE_MUL
          psum_para_out_vld[k]  <= psum_out_vld_d[k][0];
      `else
        `ifndef PIPE_MUL_PRE
          psum_para_out_vld[k]  <= psum_out_vld_d[k][1];
        `else
          psum_para_out_vld[k]  <= psum_out_vld_d[k][2]; //
        `endif
      `endif
    `endif
  `else 
    `ifndef PIPE
          psum_para_out_vld[k]  <= psum_out_vld[tag_out[k]][0];
    `else
      `ifndef PIPE_MUL
          psum_para_out_vld[k]  <= psum_out_vld_d[k][0];
      `else
        `ifndef PIPE_MUL_PRE
          psum_para_out_vld[k]  <= psum_out_vld_d[k][1];
        `else
          psum_para_out_vld[k]  <= psum_out_vld_d[k][2];
        `endif
      `endif
    `endif
  `endif
`else
        case(k_size)
          3: begin
            psum_para_out[k]      <= psum_out[9*(k+1)-1];
            `ifndef PIPE
              psum_para_out_vld[k]  <= psum_out_vld[9*(k+1)-1][0];
            `else
              psum_para_out_vld[k]  <= psum_out_vld_d[k];
            `endif
          end
          5: begin
            psum_para_out[k]      <= psum_out[25*(k+1)-1];
            `ifndef PIPE
              psum_para_out_vld[k]  <= psum_out_vld[25*(k+1)-1][0];
            `else
              psum_para_out_vld[k]  <= psum_out_vld_d[k];
            `endif
          end
          default: begin
            psum_para_out[k]      <= psum_out[121*(k+1)-1];
            `ifndef PIPE
              psum_para_out_vld[k]  <= psum_out_vld[121*(k+1)-1][0];
            `else
              psum_para_out_vld[k]  <= psum_out_vld_d[k];
            `endif
          end
        endcase
`endif
      end else begin
        psum_para_out[k] <= 'b0;
        psum_para_out_vld[k]  <= 'b0;
      end
    end
  end
endgenerate










/*
// MUX
generate
  for(genvar i = 0; i < PARA; i++ ) begin: input_side
    always_ff(posedge clk or negedge arst_n)
    if(!arst_n) begin
      en_flag[i]  <= 'd0;
      image_in[i] <= 'd0;
    end else if(!rst_n) begin
      en_flag[i]  <= 'd0;
      image_in[i] <= 'd0;
    end else begin
      case(para_in_num)
        'd1:  if(i%k_size==0) begin en_flag[i] <= 'd1; image_in[i] <= image_para_in[0]; else begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
        'd2:  if(i<(PARA>>1))
                if(i%k_size==0) begin en_flag[i] <= 'd1; image_in[i] <= image_para_in[0]; else begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
              else
                if(i%k_size==0) begin en_flag[i] <= 'd1; image_in[i] <= image_para_in[MAX_PARA_IN>>1]; else begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
        'd4:  if(i<(PARA>>1))
                if(i<(PARA>>2))
                  if(i%k_size==0) begin en_flag[i] <= 'd1; image_in[i] <= image_para_in[0]; else begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
                else
                  if(i%k_size==0) begin en_flag[i] <= 'd1; image_in[i] <= image_para_in[MAX_PARA_IN>>2]; else begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
              else
                if(i<((PARA>>1)+(PARA>>2)))
                  if(i%k_size==0) begin en_flag[i] <= 'd1; image_in[i] <= image_para_in[MAX_PARA_IN>>1]; else begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
                else
                  if(i%k_size==0) begin en_flag[i] <= 'd1; image_in[i] <= image_para_in[(MAX_PARA_IN>>2)+(MAX_PARA_IN>>1)]; else begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
        default:  
              begin en_flag[i] <= 'd0; image_in[i] <= 'd0; end
      endcase
    end
  end
endgenerate
*/

endmodule