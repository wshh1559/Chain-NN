module top_adder(a,b,c);

input [31:0] a,b;
output [31:0] c;

reg [7:0] diff;
reg [7:0] aexp,bexp,Bf_Regr_exp;
reg [9:0] cexp;
reg [24:0] aman,bman,amanshift,bmanshift;
reg [25:0] Bf_Regr_cman,cmanshift,cman;

reg csign;

reg Bf_Regr_csign;

reg [4:0] in,index;

reg [31:0] cout;
reg overflow;
reg downflow;

assign c = cout;

always @(a,b) begin
	aexp = a[30:23];
	bexp = b[30:23];

	aman = {2'b01,a[22:0]};
	bman = {2'b01,b[22:0]};

	if (a == 0) begin
		cout = b;
	end
	else if (b == 0) begin
		cout = a;
	end
	else begin
		if (aexp > bexp) begin
			diff = aexp - bexp;
			amanshift = aman;
			bmanshift = bman >> diff;
			Bf_Regr_exp = aexp;
		end
		else begin
			diff = bexp - aexp;
			bmanshift = bman;
			amanshift = aman >> diff;
			Bf_Regr_exp = bexp;
		end

		if (a[31] == b[31]) begin
			Bf_Regr_cman = amanshift + bmanshift;
			Bf_Regr_csign = a[31];
		end
		else begin
			Bf_Regr_cman = amanshift - bmanshift;
			Bf_Regr_csign = a[31];
		end

		if (Bf_Regr_cman[25]) begin
			csign = ~Bf_Regr_csign;
			cmanshift = ~Bf_Regr_cman+1;
		end
		else begin
			csign = Bf_Regr_csign;
			cmanshift = Bf_Regr_cman;
		end

		if (cmanshift == 0) begin
			cman = 0;
			cexp = 0;
			index = 0;
		end
		else begin
			// for (in = 5'd0; in < 26; in = in + 1) begin
			// 	if (cmanshift[in] == 1'b1) begin
			// 		index = in;
			// 	end
			// 	else begin
			// 		index = index;
			// 	end
			// end
			casex(cmanshift)
				26'b1xxxxxxxxxxxxxxxxxxxxxxxxx: index = 25;
				26'b01xxxxxxxxxxxxxxxxxxxxxxxx: index = 24;
				26'b001xxxxxxxxxxxxxxxxxxxxxxx: index = 23;
				26'b0001xxxxxxxxxxxxxxxxxxxxxx: index = 22;
				26'b00001xxxxxxxxxxxxxxxxxxxxx: index = 21;
				26'b000001xxxxxxxxxxxxxxxxxxxx: index = 20;
				26'b0000001xxxxxxxxxxxxxxxxxxx: index = 19;
				26'b00000001xxxxxxxxxxxxxxxxxx: index = 18;
				26'b000000001xxxxxxxxxxxxxxxxx: index = 17;
				26'b0000000001xxxxxxxxxxxxxxxx: index = 16;
				26'b00000000001xxxxxxxxxxxxxxx: index = 15;
				26'b000000000001xxxxxxxxxxxxxx: index = 14;
				26'b0000000000001xxxxxxxxxxxxx: index = 13;
				26'b00000000000001xxxxxxxxxxxx: index = 12;
				26'b000000000000001xxxxxxxxxxx: index = 11;
				26'b0000000000000001xxxxxxxxxx: index = 10;
				26'b00000000000000001xxxxxxxxx: index = 9;
				26'b000000000000000001xxxxxxxx: index = 8;
				26'b0000000000000000001xxxxxxx: index = 7;
				26'b00000000000000000001xxxxxx: index = 6;
				26'b000000000000000000001xxxxx: index = 5;
				26'b0000000000000000000001xxxx: index = 4;
				26'b00000000000000000000001xxx: index = 3;
				26'b000000000000000000000001xx: index = 2;
				26'b0000000000000000000000001x: index = 1;
				26'b00000000000000000000000001: index = 0;
				default							: index = 0;

			endcase

			if (index == 5'd24) begin
				cman = cmanshift >> 1;
				cexp = Bf_Regr_exp + 1;
			end
			else begin
				cman = cmanshift << (5'd23-index);
				cexp = Bf_Regr_exp - (5'd23-index);
			end
		end

		if (cman == 0) begin
			cout = 0;
		end
		else if (cexp[9] == 1'b1) begin
			cout = 0;
			downflow = 1;
			overflow = 0;
		end
		else if (cexp[8] == 1'b1) begin
			cout[30:0] = 31'h7fff_ffff;
			cout[31] = csign;
			downflow = 0;
			overflow = 1;
		end
		else begin
			cout[31] = csign;
			cout[30:23] = cexp[7:0];
			cout[22:0] = cman[22:0];
			downflow = 0;
			overflow = 0;
		end
	end
end
endmodule
