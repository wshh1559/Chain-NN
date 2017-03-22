`timescale 1ns / 1ps

module top_multiplier(
    input [31:0] a, 
    input [31:0] b,
    output [31:0] product
    );
	 
	parameter exponent = 8;
	 

	wire [exponent+1:0] exp;
	wire [2*(32-exponent)-1:0] man;
	wire zeroflag;
	
	reg sign;
	reg [30-exponent:0] norm_man;
	reg [exponent+1:0] norm_exp;

	reg overflow;
	reg downflow;
	reg [31:0] prod;
	
	//assign sign = a[31] ^ b[31];
	assign exp = a[30:30-exponent+1] + b[30:30-exponent+1] - 8'd127; // set exp shift = 128
	assign man = {1'b1,a[30-exponent:0]} * {1'b1,b[30-exponent:0]};
	assign product[31:0] = prod;
	assign zeroflag = (a == 0 || b == 0)? 1'b1 : 1'b0;

	always@(man or exp or zeroflag or a or b) begin

		if(zeroflag == 1'b1) begin	//check multiply 0
			norm_man = 0;
			norm_exp = 0;
			sign = 0; 
		end
		else begin
			sign = a[31] ^ b[31];
			if (man[2*(32-exponent)-1]==1) begin
				norm_man = man[2*(32-exponent)-2:32-exponent];
				norm_exp = exp + 10'd1;
			end
			else begin
				norm_man = man[2*(32-exponent)-3:31-exponent];
				norm_exp = exp;
			end
		end
		
		overflow = norm_exp[exponent];
		downflow = norm_exp[exponent+1];
		if (downflow || zeroflag) begin
			prod[31:0] = 31'h00000000;
		end

		else if (overflow) begin
			prod[30:0] = 31'h7fffffff;
			prod[31] = sign;
		end

		else begin
			prod[30:0] = {norm_exp[exponent-1:0],norm_man};
			prod[31] = sign;
		end
	end

endmodule
