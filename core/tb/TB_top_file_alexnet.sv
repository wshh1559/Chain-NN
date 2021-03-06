//-----------------------------------------------------
// Design Name : TB_mcwp_top_top
// File Name : TB_mcwp_top_top.v
// Function : testbench of mcwp_top.v
// Version Info.
//      2014.8.25        Start coding, Shihao
//-----------------------------------------------------
`timescale 1ns/1ps
module TB_top_file_alexnet
#(
parameter           CK = 10.0,
                    DW = 16,
                    IODW = 32,
                    PARA = 144,
                    AW = 32,
                    K_BITS = 4,
                    M_BITS = 10,
                    MAX_PARA_OUT = 16,
                    MAX_PARA_OUT_BIT = 5,
                    FIX_POINT = DW/2
)
(
); // End of port list
// Input & Output Ports
logic                         clk;
logic                         rst_n;
logic                         arst_n;

// high-level control
logic                         layer_start;
logic                         layer_finish;
  
// kernel fifo
logic                         k_rfifo_vld;
logic                         k_rfifo_rdy;
logic   [DW-1:0]              k_rfifo_data;
logic                         k_wfifo_vld;
logic                         k_wfifo_rdy;
logic   [DW-1:0]              k_wfifo_data;

logic         [9:0]           gp_fin_num;
logic         [9:0]           gp_fout_num;
logic         [2:0]           gp_fin_stride;
logic         [6:0]           gp_fout_stride;
logic         [AW-1:0]        gp_k_depth_num;
logic         [3:0]           gp_k_read_num;
logic         [8:0]           gp_b_size;
logic         [K_BITS-1:0]    gp_k_size;
logic         [M_BITS-1:0]    gp_m_size;
logic         [M_BITS-1:0]    gp_n_size;
logic         [M_BITS-1:0]    gp_s_size;
logic         [MAX_PARA_OUT_BIT-1:0]  gp_para_out_num;


logic                         r_vld[0:1];
logic                         r_rdy[0:1];
logic         [DW-1:0]        r_data[0:1];

logic                         din_vld[0:1];
logic                         din_rdy[0:1];
logic         [DW-1:0]        din_data[0:1];

logic                       dram_w_vld;
logic                       dram_w_rdy;
logic         [DW-1:0]      dram_w_data;
logic                       dram_w_last;

logic   [DW-1:0]      w_data[0:1];
logic               w_rdy[0:1];
logic               w_vld[0:1];

initial begin
  clk = 0; #(CK/2.0) forever #(CK/2.0) clk = ~clk;
end

// initialize dcnn_chain_interface
integer i;
initial begin
  arst_n = 0; rst_n = 0; 
  dram_w_rdy =1;
  // if with ctrl
  layer_start = 0;
  gp_fin_num        =192;
  gp_fout_num       =32;
  gp_fin_stride     =1;
  gp_fout_stride    =16; 
  gp_k_depth_num    =384; // ceil(gp_fout_num/gp_fout_stride) * gp_fin_num
  gp_k_read_num     =1;
  gp_b_size         =1;
  gp_k_size         =3;
  gp_m_size         =13;
  gp_n_size         =15;//gp_m_size+gp_k_size-1;
  gp_s_size         =1;
  gp_para_out_num = 16;  

  // end of if with ctrl
  
  #({$random}%20) arst_n = 1;
    
  #({$random}%10)
  @(posedge clk) rst_n = 1;
  
  #({$random}%10)

  #({$random}%10)
  @(posedge clk)  layer_start = 1;
  @(posedge clk)  layer_start = 0;
  

end

//
initial begin
  wait(layer_finish);
  #50000 $finish;
end

///////////////////////////
// Read fin_odd
`define FIN_FILE_DEF(FC)\
  integer fc, r, t; fc = $fopen(FC, "r");
`define FILE_RD\
  r = $fscanf(fc,"%d", t);
initial begin: fin_odd_read
  `FIN_FILE_DEF("../sw/file_fin_odd.txt")
  w_vld[0] = 0;
  w_data[0] = 0;
  wait(rst_n);
  forever @(posedge clk) #0.2 if(!$feof(fc) & w_rdy[0]) begin
    `FILE_RD
    if(!$feof(fc)) begin 
      w_data[0] = t;
      w_vld[0]  = 1;  //w_data[0] = t;
    end else begin
      w_vld[0]  = 0;  w_data[0] = 0;
    end
  end else begin
    w_vld[0]  = 0;  w_data[0] = 0;
  end
end
`undef FILE_RD
`undef KER_FILE_DEF

///////////////////////////
// Read fin_even
`define FIN_FILE_DEF(FC)\
  integer fc, r, t; fc = $fopen(FC, "r");
`define FILE_RD\
  r = $fscanf(fc,"%d", t);
initial begin: fin_even_read
  `FIN_FILE_DEF("../sw/file_fin_even.txt")
  w_vld[1] = 0;
  w_data[1] = 0;
  wait(rst_n);
  forever @(posedge clk) #0.2 if(!$feof(fc) & w_rdy[1]) begin
    `FILE_RD
    if(!$feof(fc)) begin 
      w_data[1] = t;
      w_vld[1]  = 1;  //w_data[1] = t;
    end else begin
      w_vld[1]  = 0;  w_data[1] = 0;
    end
  end else begin
    w_vld[1]  = 0;  w_data[1] = 0;
  end
end
`undef FILE_RD
`undef KER_FILE_DEF


///////////////////////////
// Read kernel
`define KER_FILE_DEF(FC)\
  integer fc, r, t; fc = $fopen(FC, "r");
`define FILE_RD\
  r = $fscanf(fc,"%d", t);
initial begin: kernel_read
  `KER_FILE_DEF("../sw/file_fin_ker.txt")
  k_wfifo_vld   = 0;
  k_wfifo_data  = 0;
  wait(rst_n);
  forever @(posedge clk) #0.2 if( !$feof(fc) & k_wfifo_rdy &({$random}%10 < 10)) begin
    `FILE_RD
    if(!$feof(fc)) begin 
      k_wfifo_vld   = 1;
      k_wfifo_data  = t;
    end else begin
      k_wfifo_vld   = 0;
      k_wfifo_data  = 'b0;
    end
  end else begin
    k_wfifo_vld   = 0;
    k_wfifo_data  = 'b0;
  end
end
`undef FILE_RD
`undef KER_FILE_DEF


// Output check
`define OUT_FILE_DEF(FC)\
  integer fc, r, t; fc = $fopen(FC, "r");
`define FILE_RD(FP)\
  r = $fscanf(fc,"%d", t); $write("%d   %d   at %d\n", t, FP, $time); if(t!=FP) begin $write("Error found at %d: right:%d, produce:%d\n", $time, t, FP); $finish; end
  //else begin $write("%d   %d\n", t, FP); end
initial begin: check_output
  `OUT_FILE_DEF("../sw/file_fin_out.txt")
  wait(rst_n);
  forever @(posedge clk) #0.2 if(dram_w_vld) begin
    `FILE_RD($signed(dram_w_data))
  end
end
`undef FILE_RD
`undef OUT_FILE_DEF



dcnn_top #(DW,PARA,AW,K_BITS,M_BITS,MAX_PARA_OUT,MAX_PARA_OUT_BIT)
top(
  .clk              (clk),
  .rst_n            (rst_n),
  .arst_n           (arst_n),
  
  // high-level control
  .layer_start      (layer_start),
  .layer_finish     (layer_finish),
  
  // kernel fifo
  .k_rfifo_vld      (k_rfifo_vld),
  .k_rfifo_rdy      (k_rfifo_rdy),
  .k_rfifo_data     (k_rfifo_data),
  
  // fin fifo
  .r_vld_odd        (r_vld[0]),
  .r_rdy_odd        (r_rdy[0]),
  .r_data_odd       (r_data[0]),
  .r_vld_even       (r_vld[1]),
  .r_rdy_even       (r_rdy[1]),
  .r_data_even      (r_data[1]),
  
  // Output fifo to dram 
  .dram_w_vld       (dram_w_vld),
  .dram_w_rdy       (dram_w_rdy),
  .dram_w_data      (dram_w_data),
  .dram_w_last      (dram_w_last),
  
  // global signal
  .gp_fin_num       (gp_fin_num),
  .gp_fout_num      (gp_fout_num),
  .gp_fin_stride    (gp_fin_stride),
  .gp_fout_stride   (gp_fout_stride),
  .gp_k_depth_num   (gp_k_depth_num),
  .gp_k_read_num    (gp_k_read_num),
  .gp_b_size        (gp_b_size),
  .gp_k_size        (gp_k_size),
  .gp_m_size        (gp_m_size),
  .gp_n_size        (gp_n_size),
  .gp_s_size        (gp_s_size),
  .gp_para_out_num  (gp_para_out_num)
);

defparam dram_fifo_odd.DW = DW;
defparam dram_fifo_odd.DEPTH = 256;
stdcore_rfifo dram_fifo_odd(
  .clk      (clk),
  .arst_n   (arst_n),
  .rst_n    (rst_n),
  .p        (w_data[0]),
  .p_val    (w_vld[0]),
  .p_rdy    (w_rdy[0]),
  .c        (r_data[0]),
  .c_val    (r_vld[0]),
  .c_rdy    (r_rdy[0])
);

defparam dram_fifo_even.DW =DW;
defparam dram_fifo_even.DEPTH =256;
stdcore_rfifo dram_fifo_even(
  .clk      (clk),
  .arst_n   (arst_n),
  .rst_n    (rst_n),
  .p        (w_data[1]),
  .p_val    (w_vld[1]),
  .p_rdy    (w_rdy[1]),
  .c        (r_data[1]),
  .c_val    (r_vld[1]),
  .c_rdy    (r_rdy[1])
);

defparam kernel_fifo.DW =DW;
defparam kernel_fifo.DEPTH =256;
stdcore_rfifo kernel_fifo(
  .clk      (clk),
  .arst_n   (arst_n),
  .rst_n    (rst_n),
  .p        (k_wfifo_data),
  .p_val    (k_wfifo_vld),
  .p_rdy    (k_wfifo_rdy),
  .c        (k_rfifo_data),
  .c_val    (k_rfifo_vld),
  .c_rdy    (k_rfifo_rdy)
);
/*
dcnn_s0_ioif #(DW,IODW) s0_ioif(
  .clk          (clk),
  .rst_n        (rst_n),
  .arst_n       (arst_n),

  // IO side
  .io_clk       (clk),
  .io_rst_n     (rst_n),
  .io_data_in   (w_data),
  .io_data_vld  (w_vld),
  .io_data_rdy  (w_rdy),

  // core side
  .core_vld     (din_vld),
  .core_rdy     (din_rdy),
  .core_data    (din_data)
  
  //.gp_stride_size(1)
);
*/


endmodule // End of Module counter



