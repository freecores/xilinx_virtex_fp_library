`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:32:10 11/19/2013 
// Design Name: 
// Module Name:    ClosePath 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: A ± B when |Ea-Eb| < 2
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module ClosePath	#(	parameter size_in_mantissa			= 24, //1.M
							parameter size_out_mantissa		= 24,
							parameter size_exponent 			= 8,
							parameter pipeline					= 0,
							parameter pipeline_pos				= 0,	// 8 bits
							parameter size_counter				= 5,	//log2(size_in_mantissa) + 1 = 5)
							parameter double_size_in_mantissa   = size_in_mantissa + size_in_mantissa)
											
						(	input [size_in_mantissa     : 0] unnormalized_mantissa,
							input [size_in_mantissa - 1 : 0] inter_rounding_bits,
							input [size_exponent     : 0] exp_inter,
							output[size_out_mantissa-1:0] resulted_m_o,
							output[size_exponent - 1 : 0] resulted_e_o);

	wire [size_counter - 1 : 0] lzs;
	wire [size_exponent- 1 : 0] unadjusted_exponent;
	wire [size_in_mantissa + 1 : 0] dummy_bits;
											
														
	//compute leading_zeros over unnormalized mantissa
	leading_zeros #(	.SIZE_INT(size_in_mantissa + 1), .SIZE_COUNTER(size_counter), .PIPELINE(pipeline))
		leading_zeros_instance (.a(unnormalized_mantissa[size_in_mantissa : 0]), 
										.ovf(unnormalized_mantissa[size_in_mantissa]), 
										.lz(lzs));
										
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(double_size_in_mantissa + 1),
					.SHIFT_SIZE(size_counter),
					.OUTPUT_SIZE(double_size_in_mantissa + 2),
					.DIRECTION(1'b1), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_instance(	.a({unnormalized_mantissa, inter_rounding_bits}),//mantissa
								.arith(1'b0),//logical shift
								.shft(lzs),
								.shifted_a({resulted_m_o, dummy_bits}));
								
	assign unadjusted_exponent = exp_inter - lzs;
	assign resulted_e_o =  unadjusted_exponent + 1'b1;
		
endmodule
