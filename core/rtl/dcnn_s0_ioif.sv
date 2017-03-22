`timescale 1ns/1ps
module dcnn_s0_ioif
#(parameter DW = 32,
            IODW = 64)
(
  clk,
  rst_n,
  arst_n,
  
  // IO side
  io_clk,
  io_rst_n,
  io_data_in,
  io_data_vld,
  io_data_rdy,
  
  // core side
  core_vld,
  core_rdy,
  core_data
);

input                       clk;
input                       rst_n;
input                       arst_n;

// IO side
input                     io_clk;
input                     io_rst_n;
input                     io_data_vld[0:1];
output  logic             io_data_rdy[0:1];
input         [IODW-1:0]  io_data_in[0:1];

// core side
output  logic             core_vld[0:1];
input                     core_rdy[0:1];
output  logic [DW-1:0]    core_data[0:1];


generate
for(genvar i = 0; i < 2; i++ ) begin: cross_clk_buffer
  logic         [IODW-1:0]  d_in;
  logic                     d_val;    
  logic                     d_rdy;
  logic         [DW-1:0]    single_in;
  logic                     single_val;    
  logic                     single_rdy;
  stdcore_rfifo #(IODW,4,0,3) io_fifo(
    .clk        (io_clk),
    .arst_n     (arst_n),
    .rst_n      (io_rst_n),

    .p          (io_data_in[i]),
    .p_val      (io_data_vld[i]),
    .p_rdy      (io_data_rdy[i]),

    .c          (d_in),
    .c_val      (d_val),
    .c_rdy      (d_rdy)
  );
  
  logic     [1:0]     cnt;
  always_ff@(posedge io_clk or negedge arst_n)
  if(!arst_n) begin
    cnt <= 'b0;
  end else if(!io_rst_n) begin
    cnt <= 'b0;
  end else begin
    if(single_val & single_rdy)
      cnt <= ((cnt+1)<(IODW/DW)) ? (cnt+1) : 'b0;
  end

  //always_comb begin
  //  single_in = 'b0;
  //  case(cnt)
  //    2'b00:    single_in = d_in[DW-1:0];
  //    2'b01:    single_in = d_in[DW*2-1:DW];
  //    2'b10:    single_in = d_in[DW*3-1:DW*2];
  //    default:  single_in = d_in[DW*4-1:DW*3];
  //  endcase
  //end
  assign  single_in = cnt[1] ? (cnt[0] ? (d_in[DW*4-1:DW*3]) : (d_in[DW*3-1:DW*2])) : (cnt[0] ? (d_in[DW*2-1:DW]) : (d_in[DW-1:0]));
  assign  single_val = d_val & single_rdy;
  assign  d_rdy = ((cnt+1)==(IODW/DW)) & single_val;

  stdcore_rfifo_sram #(DW,2048,11) asyn_sram(
    .pclk       (io_clk),
    .cclk       (clk),
    .arst_n     (arst_n),
    .rst_n     (rst_n),

    .p          (single_in),
    .p_val      (single_val),
    .p_rdy      (single_rdy),

    .c          (core_data[i]),
    .c_val      (core_vld[i]),
    .c_rdy      (core_rdy[i])
  );
end
endgenerate

endmodule