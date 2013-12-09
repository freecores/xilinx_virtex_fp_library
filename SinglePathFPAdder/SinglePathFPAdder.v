`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:09:49 11/04/2013 
// Design Name: 
// Module Name:    SinglePathFPAdder 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: A � B
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module SinglePathFPAdder #(	parameter size_mantissa 			= 24, //calculate the size containing the hiden bit 1.M
										parameter size_exponent 			= 8,
										parameter size_exception_field	= 2,
										parameter size_counter				= 5,	//log2(size_mantissa) + 1 = 5)
										parameter [size_exception_field - 1 : 0] zero			= 0, //00
										parameter [size_exception_field - 1 : 0] normal_number= 1, //01
										parameter [size_exception_field - 1 : 0] infinity		= 2, //10
										parameter [size_exception_field - 1 : 0] NaN				= 3, //11
										parameter pipeline					= 0,
										parameter pipeline_pos				= 0,	// 8 bits
										parameter double_size_mantissa		= size_mantissa + size_mantissa,
										parameter double_size_counter		= size_counter + 1,
										parameter size	= size_mantissa + size_exponent + size_exception_field)
										
									(	input sub,
										input [size - 1 : 0] a_number_i,
										input [size - 1 : 0] b_number_i,
										output[size - 1 : 0] resulted_number_o);
	
	
	wire [size_exception_field - 1 : 0] sp_case_a_number, sp_case_b_number; 
	wire [size_mantissa - 1 : 0] m_a_number, m_b_number;
	wire [size_exponent - 1 : 0] e_a_number, e_b_number;
	wire s_a_number, s_b_number;
	
	wire [size_exponent     : 0] a_greater_exponent, b_greater_exponent;
	wire [size_exponent - 1 : 0] unadjusted_exponent;
	
	wire [size_exponent - 1 : 0] exp_difference;
	wire [size_exponent     : 0] exp_inter;
	wire [size_mantissa - 1 : 0] shifted_m_b;
	wire [size_mantissa - 1 : 0] initial_rounding_bits, inter_rounding_bits, final_rounding_bits;
	wire eff_op;
	
	wire [size_counter  - 1 : 0] lzs;
	wire [size_mantissa + 1	: 0] adder_mantissa;
	wire [size_mantissa + 1 : 0] rounded_mantissa;
	wire [size_mantissa 	: 0] unnormalized_mantissa, unrounded_mantissa;
	
	wire [size_exception_field - 1 : 0] resulted_exception_field;
	wire [size_mantissa - 1	: 0] resulted_mantissa;
	wire [size_exponent - 1 : 0] resulted_exponent;
	wire resulted_sign;
	
	wire dummy_bit;
	wire zero_flag;
	
	
	assign e_a_number	= a_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign e_b_number = b_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign s_a_number = a_number_i[size - size_exception_field - 1];
	assign s_b_number = b_number_i[size - size_exception_field - 1];
	assign sp_case_a_number = a_number_i[size - 1 : size - size_exception_field];
	assign sp_case_b_number = b_number_i[size - 1 : size - size_exception_field];
	
	
	//find the greater exponent
	assign a_greater_exponent = e_a_number - e_b_number;
	assign b_greater_exponent = e_b_number - e_a_number;
	
	//find the difference between exponents
	assign exp_difference 	= (a_greater_exponent[size_exponent])? b_greater_exponent[size_exponent - 1 : 0] : a_greater_exponent[size_exponent - 1 : 0];
	assign exp_inter 		= (b_greater_exponent[size_exponent])? {1'b0, e_a_number} : {1'b0, e_b_number};
	
	//set shifter always on m_b_number
	assign {m_a_number, m_b_number} = (b_greater_exponent[size_exponent])? 
													{{1'b1, a_number_i[size_mantissa - 2 :0]}, {1'b1, b_number_i[size_mantissa - 2 :0]}} : 
													{{1'b1, b_number_i[size_mantissa - 2 :0]}, {1'b1, a_number_i[size_mantissa - 2 :0]}};
												
	//shift m_b_number				
	shifter #(	.INPUT_SIZE(size_mantissa),
				.SHIFT_SIZE(size_exponent),
				.OUTPUT_SIZE(double_size_mantissa),
				.DIRECTION(1'b0), //0=right, 1=left
				.PIPELINE(pipeline),
				.POSITION(pipeline_pos))
		m_b_shifter_instance(	.a(m_b_number),//mantissa
								.arith(1'b0),//logical shift
								.shft(exp_difference),
								.shifted_a({shifted_m_b, initial_rounding_bits}));
	
	//istantiate effective_operation_component
	effective_op effective_op_instance( .a_sign(s_a_number), .b_sign(s_b_number), .sub(sub), .eff_op(eff_op));
			
	//compute unnormalized_mantissa
	assign adder_mantissa = (eff_op)? ({1'b0, m_a_number} - {1'b0, shifted_m_b}) : ({1'b0, m_a_number} + {1'b0, shifted_m_b});
	
	assign {unnormalized_mantissa, inter_rounding_bits} = 
								(adder_mantissa[size_mantissa + 1])?	({~adder_mantissa[size_mantissa : 0], ~initial_rounding_bits}) : 
																		({adder_mantissa[size_mantissa 	: 0], initial_rounding_bits});
																		
	//compute leading_zeros over unnormalized mantissa
	leading_zeros #(	.SIZE_INT(size_mantissa + 1), .SIZE_COUNTER(size_counter), .PIPELINE(pipeline))
		leading_zeros_instance (.a(unnormalized_mantissa[size_mantissa : 0]), 
										.ovf(unnormalized_mantissa[size_mantissa]), 
										.lz(lzs));
	
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(double_size_mantissa + 1),
					.SHIFT_SIZE(size_counter),
					.OUTPUT_SIZE(double_size_mantissa + 2),
					.DIRECTION(1'b1), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_instance(	.a({unnormalized_mantissa, inter_rounding_bits}),//mantissa
								.arith(1'b0),//logical shift
								.shft(lzs),
								.shifted_a({unrounded_mantissa, final_rounding_bits, dummy_bit}));
									
	//instantiate rounding_component
	rounding #(	.SIZE_MOST_S_MANTISSA(size_mantissa + 2),
				.SIZE_LEAST_S_MANTISSA(size_mantissa))
		rounding_instance(	.unrounded_mantissa({1'b0, unrounded_mantissa}),
		                    .dummy_bits(final_rounding_bits),
		                    .rounded_mantissa(rounded_mantissa));
	
	//adjust exponent in case of overflow
	assign adjust_exponent = (rounded_mantissa[size_mantissa + 1])? 2'd2 : 2'd1;
	
	//compute resulted_exponent
	assign unadjusted_exponent = exp_inter - lzs;
	assign resulted_exponent = unadjusted_exponent + adjust_exponent;
	
	assign resulted_mantissa = (rounded_mantissa[size_mantissa + 1])? (rounded_mantissa[size_mantissa + 1 : 2]) : (rounded_mantissa[size_mantissa : 1]);
	
	//compute exception_field
	special_cases	#(	.size_exception_field(size_exception_field),
							.zero(zero), 
							.normal_number(normal_number),
							.infinity(infinity),
							.NaN(NaN))
		special_cases_instance( .sp_case_a_number(sp_case_a_number),
										.sp_case_b_number(sp_case_b_number),
										.sp_case_result_o(resulted_exception_field)); 
	
	//set zero_flag in case of equal numbers
	assign zero_flag = ~(|(resulted_mantissa));
	
	//compute resulted_sign
	assign resulted_sign = (eff_op)? 
					(!a_greater_exponent[size_exponent]? (!b_greater_exponent[size_exponent]? ~adder_mantissa[size_mantissa+1] : s_a_number) : ~s_b_number) : 
					s_a_number;
											
	assign resulted_number_o = (zero_flag)? {size{1'b0}} :
									{resulted_exception_field, resulted_sign, resulted_exponent, resulted_mantissa[size_mantissa - 2 : 0]};
	
endmodule
