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
									parameter [size_exception_field - 1 : 0] normal_number	= 1, //01
									parameter [size_exception_field - 1 : 0] infinity		= 2, //10
									parameter [size_exception_field - 1 : 0] NaN				= 3, //11
									parameter [1 : 0] FP_operation 	= 0,
									parameter [1 : 0] FP_to_int		= 1,
									parameter [1 : 0] int_operation = 3,
									
									parameter pipeline					= 0,
									parameter pipeline_pos				= 0,	// 8 bits
									parameter double_size_mantissa	= size_mantissa + size_mantissa,
									parameter double_size_counter		= size_counter + 1,
									parameter size	= size_mantissa + size_exponent + size_exception_field)
										
									(	input [1:0] conversion,
										input sub,
										input [size - 1 : 0] a_number_i,
										input [size - 1 : 0] b_number_i,
										output[size - 1 : 0] resulted_number_o);

	wire [size_exception_field - 1 : 0] sp_case_a_number, sp_case_b_number; 
	wire [size_mantissa - 1 : 0] m_a_number, m_b_number;
	wire [size_exponent - 1 : 0] e_a_number, e_b_number;
	wire s_a_number, s_b_number; 
	
	wire [size_exponent     : 0] a_greater_exponent, b_greater_exponent;
	
	wire [size_exponent - 1 : 0] exp_difference;
	wire [size_exponent     : 0] exp_inter;
	wire [size_mantissa - 1 : 0] shifted_m_b;
	wire [size_mantissa - 1 : 0] initial_rounding_bits, inter_rounding_bits;
	wire eff_op;
	
	wire [size_mantissa + 1	: 0] adder_mantissa;
	wire [size_mantissa 	: 0] unnormalized_mantissa;
	
	wire [size_mantissa-1 : 0] fp_resulted_m_o, cp_resulted_m_o;
	wire [size_exponent-1 : 0] fp_resulted_e_o, cp_resulted_e_o;
	
	wire [size_exception_field - 1 : 0] resulted_exception_field;
	wire resulted_sign;
	wire swap;
	
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
	assign {swap, m_a_number, m_b_number} = (b_greater_exponent[size_exponent])?
													{1'b0, {1'b1, a_number_i[size_mantissa - 2 :0]}, {1'b1, b_number_i[size_mantissa - 2 :0]}} : 
													{1'b1, {1'b1, b_number_i[size_mantissa - 2 :0]}, {1'b1, a_number_i[size_mantissa - 2 :0]}};

	effective_op effective_op_instance( .a_sign(s_a_number), .b_sign(s_b_number), .sub(sub), .eff_op(eff_op));
										
										
	//instantiate FarPath component
	FarPath	#(	.size_in_mantissa(size_mantissa),	
					.size_out_mantissa(size_mantissa),	
					.size_exponent(size_exponent), 	
					.pipeline(pipeline),			
					.pipeline_pos(pipeline_pos),		
					.size_counter(size_counter),
					.double_size_in_mantissa(double_size_mantissa))
		FarPath_instance (	.m_a_number(m_a_number),
							.m_b_number(m_b_number),
							.eff_op(eff_op),
							.exp_difference(exp_difference),
		                    .exp_inter(exp_inter),
		                    .resulted_m_o(fp_resulted_m_o),
		                    .resulted_e_o(fp_resulted_e_o));
		
	//instantiate ClosePath component
	ClosePath #(.size_in_mantissa(size_mantissa),	
					.size_out_mantissa(size_mantissa),	
					.size_exponent(size_exponent), 	
					.pipeline(pipeline),			
					.pipeline_pos(pipeline_pos),	
					.size_counter(size_counter),
					.double_size_in_mantissa(double_size_mantissa))
		ClosePath_instance(	.m_a_number(m_a_number),
							.m_b_number(m_b_number),
							.exp_difference(exp_difference[0]),
								.exp_inter(exp_inter),
								.resulted_m_o(cp_resulted_m_o),
								.resulted_e_o(cp_resulted_e_o),
								.ovf(ovf));			
	
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
	assign zero_flag = (exp_difference > 1 | !eff_op)? ~(|fp_resulted_m_o) : ~(|cp_resulted_m_o);
	
	assign resulted_sign = (exp_difference > 1 | !eff_op)? (!a_greater_exponent[size_exponent]? s_a_number : (eff_op? ~s_b_number : s_b_number)) : (ovf ^ swap);
		
	assign resulted_number_o = (zero_flag)? {size{1'b0}} :
									(exp_difference > 1 | !eff_op)? 	{resulted_exception_field, resulted_sign, fp_resulted_e_o, fp_resulted_m_o[size_mantissa-2 : 0]}:
																		{resulted_exception_field, resulted_sign, cp_resulted_e_o, cp_resulted_m_o[size_mantissa-2 : 0]};
endmodule
