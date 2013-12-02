`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:31:28 11/19/2013 
// Design Name: 
// Module Name:    DualPathFPAdder 
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
module DualPathFPAdder #(	parameter size_mantissa 			= 24, //1.M
									parameter size_exponent 			= 8,
									parameter size_exception_field	= 2,
									parameter size_counter				= 5,	//log2(size_mantissa) + 1 = 5)
									parameter [size_exception_field - 1 : 0] zero			= 0, //00
									parameter [size_exception_field - 1 : 0] normal_number= 1, //01
									parameter [size_exception_field - 1 : 0] infinity		= 2, //10
									parameter [size_exception_field - 1 : 0] NaN				= 3, //11
									parameter pipeline					= 0,
									parameter pipeline_pos				= 0,	// 8 bits
									parameter double_size_mantissa	= size_mantissa + size_mantissa,
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
	
	wire [size_mantissa-1 : 0] fp_resulted_m_o, cp_resulted_m_o;
	wire [size_exponent-1 : 0] fp_resulted_e_o, cp_resulted_e_o;
	
	wire resulted_sign;
	wire [size_exception_field - 1 : 0] resulted_exception_field;

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
					.DIRECTION(1'b0), 
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		m_a_shifter_instance(	.a(m_a_number),
										.arith(1'b0),
										.shft(modify_exp_a),
										.shifted_a(shifted_m_a));
										
	shifter #(	.INPUT_SIZE(size_mantissa),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(double_size_mantissa),
					.DIRECTION(1'b0), 
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		m_b_shifter_instance(	.a(m_b_number),
										.arith(1'b0),
										.shft(modify_exp_b),
										.shifted_a(shifted_m_b));
										
	//istantiate effective_operation_component
		effective_op effective_op_instance( .a_sign(s_a_number), .b_sign(s_b_number), .sub(sub), .eff_op(eff_op));
		


	//instantiate special_cases component
	special_cases #(	.size_exception_field(size_exception_field), 
							.zero(zero), 			
							.normal_number(normal_number),
							.infinity(infinity),
							.NaN(NaN))
		special_cases_instance	( 	.sp_case_a_number(sp_case_a_number),
											.sp_case_b_number(sp_case_b_number),
											.sp_case_result_o(resulted_exception_field)); 					  
								  
	//instantiate FarPath component
	FarPath	#(	.size_in_mantissa(double_size_mantissa),	
					.size_out_mantissa(size_mantissa),	
					.size_exponent(size_exponent), 	
					.pipeline(pipeline),			
					.pipeline_pos(pipeline_pos),		
					.size_counter(size_counter),
					.double_size_counter(double_size_counter),
					.double_size_mantissa(double_size_mantissa))
		FarPath_instance (	.eff_op(eff_op),
									.m_a_number(shifted_m_a),
		                     .m_b_number(shifted_m_b),
		                     .e_a_number(e_a_number),
		                     .e_b_number(e_b_number),
		                     .resulted_m_o(fp_resulted_m_o),
									.resulted_e_o(fp_resulted_e_o));
					

//instantiate ClosePath component
	ClosePath #(.size_in_mantissa(double_size_mantissa),	
					.size_out_mantissa(size_mantissa),	
					.size_exponent(size_exponent), 	
					.pipeline(pipeline),			
					.pipeline_pos(pipeline_pos),	
					.size_counter(size_counter),
					.double_size_counter(double_size_counter),
					.double_size_mantissa(double_size_mantissa))
		ClosePath_instance(	.eff_op(eff_op),
									.m_a_number(shifted_m_a),
		                     .m_b_number(shifted_m_b),
		                     .e_a_number(e_a_number),
		                     .e_b_number(e_b_number),
		                     .resulted_m_o(cp_resulted_m_o),
									.resulted_e_o(cp_resulted_e_o));
									
	assign resulted_sign = (eff_op)? ((shifted_m_a > shifted_m_b)? s_a_number : ~s_a_number) : s_a_number;
	
	assign resulted_number_o = (exp_difference > 1)? 	{resulted_exception_field, resulted_sign, fp_resulted_e_o, fp_resulted_m_o[size_mantissa-2 : 0]}:
																		{resulted_exception_field, resulted_sign, cp_resulted_e_o, cp_resulted_m_o[size_mantissa-2 : 0]};
endmodule
