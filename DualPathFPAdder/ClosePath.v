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
module ClosePath	#(	parameter size_in_mantissa			= 48, //1.M
							parameter size_out_mantissa		= 24,
							parameter size_exponent 			= 8,
							parameter pipeline					= 0,
							parameter pipeline_pos				= 0,	// 8 bits
							parameter size_counter				= 5,	//log2(size_mantissa) + 1 = 5)
							parameter double_size_counter		= size_counter + 1,
							parameter double_size_mantissa	= size_in_mantissa + size_in_mantissa)
											
						(	input eff_op, 
							input [size_in_mantissa-1 :0] m_a_number, 
							input [size_in_mantissa-1 :0] m_b_number,
							input [size_exponent - 1 : 0] e_a_number,
							input [size_exponent - 1 : 0] e_b_number,
							output[size_out_mantissa-1:0] resulted_m_o,
							output[size_exponent - 1 : 0] resulted_e_o);

	wire [size_in_mantissa:0] unnormalized_mantissa;
	wire [double_size_counter-1: 0] lzs;
	wire [size_out_mantissa + 1 : 0] dummy_bits;
											
	//compute unnormalized_mantissa
	assign unnormalized_mantissa = (eff_op)? ((m_a_number > m_b_number)? (m_a_number - m_b_number) : (m_b_number - m_a_number)) :
															m_a_number + m_b_number;
															
	//compute leading_zeros over unnormalized mantissa
	leading_zeros #(	.SIZE_INT(double_size_mantissa + 1'b1), .SIZE_COUNTER(double_size_counter), .PIPELINE(pipeline))
		leading_zeros_instance (.a(unnormalized_mantissa), 
										.ovf(1'b0), 
										.lz(lzs));
										
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(size_in_mantissa + 1'b1),
					.SHIFT_SIZE(double_size_counter),
					.OUTPUT_SIZE(size_in_mantissa + 2'd2),
					.DIRECTION(1'b1), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_instance(	.a(unnormalized_mantissa),//mantissa
								.arith(1'b0),//logical shift
								.shft(lzs),
								.shifted_a({resulted_m_o, dummy_bits}));
								
	assign resulted_e_o = (e_a_number > e_b_number)? (e_a_number - lzs + 1) : (e_b_number - lzs + 1);
		
endmodule
