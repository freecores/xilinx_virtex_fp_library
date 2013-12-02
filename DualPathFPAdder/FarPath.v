`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:31:57 11/19/2013 
// Design Name: 
// Module Name:    FarPath 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: A ± B when |Ea-Eb| >= 2
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module FarPath	#(	parameter size_in_mantissa			= 24, //1.M
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

	wire [double_size_mantissa:0] unnormalized_mantissa;
	wire [7:0] adjust_mantissa;
	wire [double_size_mantissa:0] normalized_mantissa;
	
	wire dummy_bit;
										
	//compute unnormalized_mantissa
	assign unnormalized_mantissa = (eff_op)? ((m_a_number > m_b_number)? (m_a_number - m_b_number) : (m_b_number - m_a_number)) :
															m_a_number + m_b_number;
	
	assign adjust_mantissa = unnormalized_mantissa[double_size_mantissa]? 8'd0 :
										unnormalized_mantissa[double_size_mantissa-1]? 2'd1 : 8'd2;
										
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(double_size_mantissa+1),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(double_size_mantissa+2),
					.DIRECTION(1'b1),
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		unnormalized_no_shifter_instance(.a(unnormalized_mantissa),
													.arith(1'b0),
													.shft(adjust_mantissa),
													.shifted_a({normalized_mantissa, dummy_bit}));
	
	//instantiate rounding_component
	rounding #(	.SIZE_MOST_S_MANTISSA(size_out_mantissa),
					.SIZE_LEAST_S_MANTISSA(size_out_mantissa + 2'd1))
		rounding_instance(	.unrounded_mantissa(normalized_mantissa[double_size_mantissa : double_size_mantissa - size_out_mantissa + 1]),
									.dummy_bits(normalized_mantissa[double_size_mantissa - size_out_mantissa: 0]),
									.rounded_mantissa(resulted_m_o));
									
	assign resulted_e_o = (e_a_number > e_b_number)? (e_a_number + 1 - adjust_mantissa):(e_b_number + 1 - adjust_mantissa);
	 
endmodule
