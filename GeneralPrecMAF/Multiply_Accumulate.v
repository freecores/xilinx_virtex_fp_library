`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:53:05 10/15/2013 
// Design Name: 
// Module Name:    Multiply_Accumulate 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: C ± A*B
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Multiply_Accumulate #(	parameter size_exponent = 8,	//exponent bits
										parameter size_mantissa = 24,	//mantissa bits
										parameter size_counter	= 5,	//log2(size_mantissa) + 1 = 5
										parameter size_exception_field = 2,	// zero/normal numbers/infinity/NaN
										parameter zero				= 00, //00
										parameter normal_number = 01, //01
										parameter infinity		= 10, //10
										parameter NaN				= 11, //11
										parameter pipeline		= 0,
										parameter pipeline_pos	= 0,  //8 bits
								
										parameter size = size_exponent + size_mantissa + size_exception_field,
										parameter size_mul_mantissa = size_mantissa + size_mantissa,
										parameter size_mul_counter = size_counter + 1)
									(	input clk,
										input rst,
										input [size - 1:0] a_number_i,
										input [size - 1:0] b_number_i,
										input [size - 1:0] c_number_i,
										input sub,
										output[size - 1:0] resulting_number_o);
		
	
	wire [size_mantissa - 1 : 0] m_a_number, m_b_number, m_c_number;
	wire [size_exponent - 1 : 0] e_a_number, e_b_number, e_c_number;
	wire s_a_number, s_b_number, s_c_number;
	wire [size_exception_field - 1 : 0] sp_case_a_number, sp_case_b_number, sp_case_c_number;
	//---------------------------------------------------------------------------------------
	
	
	wire [size_mul_mantissa-1:0] mul_mantissa, c_mantissa;
	wire [size_mul_mantissa  :0] acc_resulting_number;
	wire [size_mul_mantissa  :0] ab_shifted_mul_mantissa, c_shifted_mantissa;
	wire [size_exponent : 0] exp_ab;
	wire [size_exponent-1:0] modify_exp_ab, modify_exp_c;
	wire [size_mul_counter-1: 0] lz_mul;
	wire sign_res;
	wire eff_sub;
	wire ovf;
	wire comp_exp;
	wire [size_mul_mantissa+1:0] normalized_mantissa;
	wire [size_mantissa - 1 : 0] rounded_mantissa;
	wire [size_exponent  :0] unnormalized_exp;
	wire [size_mantissa-2:0] final_mantissa;
	wire [size_exponent-1:0] final_exponent;
	wire [size_exception_field - 1 : 0] sp_case_result_o;

	assign m_a_number 		= {1'b1, a_number_i[size_mantissa - 2 :0]};
	assign m_b_number			= {1'b1, b_number_i[size_mantissa - 2 :0]};
	assign m_c_number			= {1'b1, c_number_i[size_mantissa - 2 :0]};
	assign e_a_number			= a_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign e_b_number			= b_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign e_c_number			= c_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign s_a_number			= a_number_i[size - size_exception_field - 1];
	assign s_b_number			= b_number_i[size - size_exception_field - 1];
	assign s_c_number			= c_number_i[size - size_exception_field - 1];
	assign sp_case_a_number	= a_number_i[size - 1 : size - size_exception_field];
	assign sp_case_b_number	= b_number_i[size - 1 : size - size_exception_field];
	assign sp_case_c_number	= c_number_i[size - 1 : size - size_exception_field];
	
	
	//instantiate multiply component
	multiply #(	.size_mantissa(size_mantissa),
					.size_counter(size_counter),
					.size_mul_mantissa(size_mul_mantissa))
		multiply_instance (	.a_mantissa_i(m_a_number),
									.b_mantissa_i(m_b_number),
									.mul_mantissa(mul_mantissa));
	
	
	assign c_mantissa = {1'b0,m_c_number, {(size_mantissa-1'b1){1'b0}}};
	assign exp_ab = e_a_number + e_b_number - ({1'b1,{(size_exponent-1'b1){1'b0}}} - 1'b1);
	assign {modify_exp_ab, modify_exp_c, unnormalized_exp} = (exp_ab >= e_c_number)? {8'd0,(exp_ab - e_c_number), exp_ab} : {(e_c_number - exp_ab), 8'd0, {1'b0,e_c_number}};
	
	
	//instantiate shifter component for mul_mantissa shift, mul_mantissa <=> ab_mantissa
	shifter #(	.INPUT_SIZE(size_mul_mantissa),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(size_mul_mantissa + 1'b1),
					.DIRECTION(1'b0), 
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_ab_instance(	.a(mul_mantissa),
									.arith(1'b0),
									.shft(modify_exp_ab),
									.shifted_a(ab_shifted_mul_mantissa));
	
	
	//instantiate shifter component for c_mantissa shift
	shifter #(	.INPUT_SIZE(size_mul_mantissa),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(size_mul_mantissa + 1'b1),
					.DIRECTION(1'b0), 
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_c_instance(	.a(c_mantissa),
									.arith(1'b0),
									.shft(modify_exp_c),
									.shifted_a(c_shifted_mantissa));
	
	
	//instantiate effective_op component
	effective_op effective_op_instance(	.sign_a(s_a_number),
													.sign_b(s_b_number),
													.sign_c(s_c_number),
													.sub(sub),
													.eff_sub(eff_sub));
										
										
	//instantiate accumulate component
	accumulate #(	.size_mantissa(size_mantissa),
						.size_counter(size_counter),
						.size_mul_mantissa(size_mul_mantissa))
		accumulate_instance (	.ab_number_i(ab_shifted_mul_mantissa[size_mul_mantissa:1]),
										.c_number_i(c_shifted_mantissa[size_mul_mantissa:1]),
										.sub(eff_sub),
										.ovf(ovf),
										.acc_resulting_number_o(acc_resulting_number));
											
											
	//instantiate leading_zeros component
	leading_zeros #(	.SIZE_INT(size_mul_mantissa + 1'b1),
							.SIZE_COUNTER(size_mul_counter),
							.PIPELINE(pipeline))
		leading_zeros_instance(	.a(acc_resulting_number),
										.ovf(ovf), 
										.lz(lz_mul));
	
	
	//instantiate shifter component
	shifter #(	.INPUT_SIZE(size_mul_mantissa + 1'b1),
					.SHIFT_SIZE(size_mul_counter),
					.OUTPUT_SIZE(size_mul_mantissa + 2'd2),
					.DIRECTION(1'b1), 
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_instance(	.a(acc_resulting_number),
								.arith(1'b0),
								.shft(lz_mul),
								.shifted_a(normalized_mantissa));
								
								
	//instantiate rounding component
	rounding #(	.SIZE_MOST_S_MANTISSA(size_mantissa), 
               .SIZE_LEAST_S_MANTISSA(size_mul_mantissa-size_mantissa+2))
		rounding_instance	(	.unrounded_mantissa(normalized_mantissa[size_mul_mantissa+1 : size_mul_mantissa+2-size_mantissa]),
									.dummy_bits(normalized_mantissa[size_mul_mantissa+1-size_mantissa : 0]),
									.rounded_mantissa(rounded_mantissa));
					
					
	//instantiate special_cases_mul_acc component
	special_cases_mul_acc	#(	.size_exception_field(size_exception_field),
										.zero(zero),
										.normal_number(normal_number),
										.infinity(infinity),
										.NaN(NaN))
		special_cases_mul_acc_instance	(	.sp_case_a_number(sp_case_a_number),
														.sp_case_b_number(sp_case_b_number),
														.sp_case_c_number(sp_case_c_number),
														.sp_case_result_o(sp_case_result_o));
	
	
	//compute resulted_sign
	assign sign_res = (eff_sub)? ((c_shifted_mantissa > ab_shifted_mul_mantissa)? s_c_number : ~s_c_number) : s_c_number;
													
													
	assign final_exponent = unnormalized_exp - lz_mul + 2'd2;
	assign final_mantissa = rounded_mantissa[size_mantissa-2 : 0];
	assign resulting_number_o = {sp_case_result_o, sign_res, final_exponent, final_mantissa};
endmodule
