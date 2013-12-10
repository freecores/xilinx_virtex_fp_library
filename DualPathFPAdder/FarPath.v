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
							parameter size_counter				= 5,	//log2(size_in_mantissa) + 1 = 5)
							parameter double_size_in_mantissa   = size_in_mantissa + size_in_mantissa)
						(	input [size_in_mantissa	- 1	: 0] m_a_number,
							input [size_in_mantissa - 1 : 0] m_b_number,
							input eff_op,
							input [size_exponent		: 0] exp_inter,
							input [size_exponent - 1 : 0] exp_difference,
							output[size_out_mantissa- 1 : 0] resulted_m_o,
							output[size_exponent - 1	: 0] resulted_e_o);

	wire [size_exponent- 1 : 0] adjust_mantissa;
	wire [size_exponent- 1 : 0] unadjusted_exponent;
	wire [double_size_in_mantissa:0] normalized_mantissa;
	
	wire [size_in_mantissa-1: 0] shifted_m_b;
	wire [size_in_mantissa+1: 0] adder_mantissa;
	wire [size_in_mantissa 	: 0] unnormalized_mantissa;
	
	wire [size_in_mantissa - 1 : 0] initial_rounding_bits, inter_rounding_bits;
	
	wire dummy_bit;
	
	//shift m_b_number				
	shifter #(	.INPUT_SIZE(size_in_mantissa),
				.SHIFT_SIZE(size_exponent),
				.OUTPUT_SIZE(double_size_in_mantissa),
				.DIRECTION(1'b0), //0=right, 1=left
				.PIPELINE(pipeline),
				.POSITION(pipeline_pos))
		m_b_shifter_instance(	.a(m_b_number),//mantissa
								.arith(1'b0),//logical shift
								.shft(exp_difference),
								.shifted_a({shifted_m_b, initial_rounding_bits}));
													
	//compute unnormalized_mantissa
	assign adder_mantissa = (eff_op)? ({1'b0, m_a_number} - {1'b0, shifted_m_b}) : ({1'b0, m_a_number} + {1'b0, shifted_m_b});
	
	assign {unnormalized_mantissa, inter_rounding_bits} = 
								(adder_mantissa[size_in_mantissa + 1])?	({~adder_mantissa[size_in_mantissa : 0], ~initial_rounding_bits}) :
																		({adder_mantissa[size_in_mantissa 	: 0], initial_rounding_bits});
		
	assign adjust_mantissa = unnormalized_mantissa[size_in_mantissa]? 2'd0 :
										unnormalized_mantissa[size_in_mantissa-1]? 2'd1 : 2'd2;
										
										
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(double_size_in_mantissa+1),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(double_size_in_mantissa+2),
					.DIRECTION(1'b1),
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		unnormalized_no_shifter_instance(.a({unnormalized_mantissa, inter_rounding_bits}),
													.arith(1'b0),
													.shft(adjust_mantissa),
													.shifted_a({normalized_mantissa, dummy_bit}));
	
	//instantiate rounding_component
	rounding #(	.SIZE_MOST_S_MANTISSA(size_out_mantissa),
					.SIZE_LEAST_S_MANTISSA(size_out_mantissa + 2'd1))
		rounding_instance(	.unrounded_mantissa(normalized_mantissa[double_size_in_mantissa : double_size_in_mantissa - size_out_mantissa + 1]),
									.dummy_bits(normalized_mantissa[double_size_in_mantissa - size_out_mantissa: 0]),
									.rounded_mantissa(resulted_m_o));
	
	assign unadjusted_exponent = exp_inter - adjust_mantissa;	
	assign resulted_e_o = unadjusted_exponent + 1'b1;
	
endmodule
