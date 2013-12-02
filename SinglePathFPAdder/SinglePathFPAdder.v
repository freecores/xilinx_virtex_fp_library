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
// Description: A ± B
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module SinglePathFPAdder #(	parameter size_mantissa 			= 24, //1.M
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
										
									(sub, a_number_i, b_number_i, resulted_number_o);

	input sub;
	input [size - 1 : 0] a_number_i;
	input [size - 1 : 0] b_number_i;
	output[size - 1 : 0] resulted_number_o;
	
	wire [size_mantissa - 1 : 0] m_a_number, m_b_number;
	wire [size_exponent - 1 : 0] e_a_number, e_b_number;
	wire s_a_number, s_b_number;
	wire [size_exception_field - 1 : 0] sp_case_a_number, sp_case_b_number; 
	
	wire [size_exponent - 1 : 0] exp_difference;
	wire [size_exponent - 1 : 0] modify_exp_a, modify_exp_b;
	wire [double_size_mantissa - 1 : 0] shifted_m_a, shifted_m_b;
	wire eff_op;
	
	wire [double_size_mantissa : 0] unnormalized_mantissa;
	wire [double_size_counter-1: 0] lzs;
	wire [size_mantissa-1: 0] unrounded_mantissa;
	
	wire [size_mantissa-1: 0] resulted_mantissa;
	wire [size_exponent-1: 0] resulted_exponent;
	wire resulted_sign;
	wire [size_exception_field - 1 : 0] resulted_exception_field;
	
	wire [size_mantissa + 1 : 0] dummy_bits;
	
	assign m_a_number = {1'b1, a_number_i[size_mantissa - 2 :0]};
	assign m_b_number	= {1'b1, b_number_i[size_mantissa - 2 :0]};
	assign e_a_number	= a_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign e_b_number = b_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign s_a_number = a_number_i[size - size_exception_field - 1];
	assign s_b_number = b_number_i[size - size_exception_field - 1];
	assign sp_case_a_number = a_number_i[size - 1 : size - size_exception_field];
	assign sp_case_b_number = b_number_i[size - 1 : size - size_exception_field];

	//find the difference between exponents
	assign exp_difference = (e_a_number > e_b_number)? (e_a_number - e_b_number) : (e_b_number - e_a_number);

	assign {modify_exp_a, modify_exp_b} = (e_a_number > e_b_number)? {8'd0, exp_difference} : {exp_difference, 8'd0};
 
	//shift the right mantissa
	shifter #(	.INPUT_SIZE(size_mantissa),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(double_size_mantissa),
					.DIRECTION(1'b0), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		m_a_shifter_instance(	.a(m_a_number),//mantissa
										.arith(1'b0),//logical shift
										.shft(modify_exp_a),
										.shifted_a(shifted_m_a));
										
	shifter #(	.INPUT_SIZE(size_mantissa),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(double_size_mantissa),
					.DIRECTION(1'b0), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		m_b_shifter_instance(	.a(m_b_number),//mantissa
										.arith(1'b0),//logical shift
										.shft(modify_exp_b),
										.shifted_a(shifted_m_b));
	
	//istantiate effective_operation_component
	effective_op effective_op_instance( .a_sign(s_a_number), .b_sign(s_b_number), .sub(sub), .eff_op(eff_op));
	
	//compute unnormalized_mantissa
	assign unnormalized_mantissa = (eff_op)? ((shifted_m_a > shifted_m_b)? (shifted_m_a - shifted_m_b) : (shifted_m_b - shifted_m_a)) :
															shifted_m_a + shifted_m_b;
		
	//compute leading_zeros over unnormalized mantissa
	leading_zeros #(	.SIZE_INT(double_size_mantissa + 1'b1), .SIZE_COUNTER(double_size_counter), .PIPELINE(pipeline))
		leading_zeros_instance (.a(unnormalized_mantissa), 
										.ovf(1'b0), 
										.lz(lzs));
										
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(double_size_mantissa + 1'b1),
					.SHIFT_SIZE(double_size_counter),
					.OUTPUT_SIZE(double_size_mantissa + 2'd2),
					.DIRECTION(1'b1), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_instance(	.a(unnormalized_mantissa),//mantissa
								.arith(1'b0),//logical shift
								.shft(lzs),
								.shifted_a({unrounded_mantissa, dummy_bits}));
	
	//
	//assign g = dummy_bits[size_mantissa + 1];
	//assign sticky = |(dummy_bits[size_mantissa : 0]);
	//assign round_dec = g & (unrounded_mantissa[0] | sticky);
	
	//instantiate rounding_component
	rounding #(	.SIZE_MOST_S_MANTISSA(size_mantissa),
				.SIZE_LEAST_S_MANTISSA(size_mantissa + 2'd2))
		rounding_instance(	.unrounded_mantissa(unrounded_mantissa),
		                    .dummy_bits(dummy_bits),
		                    .rounded_mantissa(resulted_mantissa));
		
	
	//compute resulted_exponent
	assign resulted_exponent = (e_a_number >= e_b_number)? (e_a_number - lzs + 1'b1) : (e_b_number - lzs + 1'b1);
	
	//compute resulted_sign
	assign resulted_sign = (eff_op)? ((shifted_m_a > shifted_m_b)? s_a_number : ~s_a_number) : s_a_number;
	
	//compute exception_field
	special_cases	#(	.size_exception_field(size_exception_field),
							.zero(zero), 
							.normal_number(normal_number),
							.infinity(infinity),
							.NaN(NaN))
		special_cases_instance( .sp_case_a_number(sp_case_a_number),
										.sp_case_b_number(sp_case_b_number),
										.sp_case_result_o(resulted_exception_field)); 
										
	//generate final result							
	assign resulted_number_o = {resulted_exception_field, resulted_sign, resulted_exponent, resulted_mantissa[size_mantissa-2 : 0]};
	
endmodule
