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
										//input start,
										input [size - 1:0] a_number_i,
										input [size - 1:0] b_number_i,
										input [size - 1:0] c_number_i,
										input sub,
										//output busy
										output[size - 1:0] resulting_number_o);
										

	//reg [size_mantissa - 1 : 0] m_a_number_reg, m_a_number_next;	// (1.original_mantissa) => (size_mantissa+1) because of the hidden bit
	//reg [size_mantissa - 1 : 0] m_b_number_reg, m_b_number_next;	// (1.original_mantissa) => (size_mantissa+1) because of the hidden bit
	//reg [size_mantissa - 1 : 0] m_c_number_reg, m_c_number_next;	// (1.original_mantissa) => (size_mantissa+1) because of the hidden bit
	//reg [size_exponent - 1 : 0] e_a_number_reg, e_a_number_next;
	//reg [size_exponent - 1 : 0] e_b_number_reg, e_b_number_next;
	//reg [size_exponent - 1 : 0] e_c_number_reg, e_c_number_next;
	//reg s_a_number_reg, s_a_number_next;
	//reg s_b_number_reg, s_b_number_next;
	//reg s_c_number_reg, s_c_number_next;
	//reg [size_exception_field - 1 : 0] sp_case_a_number_reg, sp_case_a_number_next;
	//reg [size_exception_field - 1 : 0] sp_case_b_number_reg, sp_case_b_number_next;
	//reg [size_exception_field - 1 : 0] sp_case_c_number_reg, sp_case_c_number_next;
	
	wire [size_mantissa - 1 : 0] m_a_number_reg, m_b_number_reg, m_c_number_reg;
	wire [size_exponent - 1 : 0] e_a_number_reg, e_b_number_reg, e_c_number_reg;
	wire s_a_number_reg, s_b_number_reg, s_c_number_reg;
	wire [size_exception_field - 1 : 0] sp_case_a_number_reg, sp_case_b_number_reg, sp_case_c_number_reg;
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
	wire [size_exponent  :0] unnormalized_exp;
	wire [size_mantissa-2:0] final_mantissa;
	wire [size_exponent-1:0] final_exponent;
	wire [size_exception_field - 1 : 0] sp_case_result_o;

/*
	always
		@(posedge clk, posedge rst)
	begin
		if (rst)
			begin
				m_a_number_reg 	<= 0;
				m_b_number_reg		<= 0;
				m_c_number_reg		<= 0;
				e_a_number_reg		<= 0;
				e_b_number_reg		<= 0;
				e_c_number_reg		<= 0;
				s_a_number_reg		<= 0;
				s_b_number_reg		<= 0;
				s_c_number_reg		<= 0;
				sp_case_a_number_reg	<= 0;
				sp_case_b_number_reg	<= 0;
				sp_case_c_number_reg	<= 0;
			end
		else
			begin
				m_a_number_reg 	<= m_a_number_next;
				m_b_number_reg		<= m_b_number_next;
				m_c_number_reg		<= m_c_number_next;
				e_a_number_reg		<= e_a_number_next;
				e_b_number_reg		<= e_b_number_next;
				e_c_number_reg		<= e_c_number_next;
				s_a_number_reg		<= s_a_number_next;
				s_b_number_reg		<= s_b_number_next;
				s_c_number_reg		<= s_c_number_next;
				sp_case_a_number_reg	<= sp_case_a_number_next;
				sp_case_b_number_reg	<= sp_case_b_number_next;
				sp_case_c_number_reg	<= sp_case_c_number_next;
			end
	end
	
	always
		@(*)
	begin
		m_a_number_next 	= m_a_number_reg;
		m_b_number_next	= m_b_number_reg;
		m_c_number_next	= m_c_number_reg;
		e_a_number_next	= e_a_number_reg;
		e_b_number_next	= e_b_number_reg;
		e_c_number_next	= e_c_number_reg;
		s_a_number_next	= s_a_number_reg;
		s_b_number_next	= s_b_number_reg;
		s_c_number_next	= s_c_number_reg;
		sp_case_a_number_next	= sp_case_a_number_reg;
		sp_case_b_number_next	= sp_case_b_number_reg;
		sp_case_c_number_next	= sp_case_c_number_reg;
		if (start)
			begin
				m_a_number_next 	= {1'b1, a_number_i[size_mantissa - 2 : 0]};
				m_b_number_next	= {1'b1, b_number_i[size_mantissa - 2 :0]};
				m_c_number_next	= {1'b1, c_number_i[size_mantissa - 2 :0]};
				e_a_number_next	= a_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
				e_b_number_next	= b_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
				e_c_number_next	= c_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
				s_a_number_next	= a_number_i[size-1];
				s_b_number_next	= b_number_i[size-1];
				s_c_number_next	= c_number_i[size-1];
				sp_case_a_number_next	= a_number_i[size - 1 : size - size_exception_field];
				sp_case_b_number_next	= b_number_i[size - 1 : size - size_exception_field];
				sp_case_c_number_next	= c_number_i[size - 1 : size - size_exception_field];
			end
	end
	*/
	
	assign m_a_number_reg 	= {1'b1, a_number_i[size_mantissa - 2 :0]};
	assign m_b_number_reg	= {1'b1, b_number_i[size_mantissa - 2 :0]};
	assign m_c_number_reg	= {1'b1, c_number_i[size_mantissa - 2 :0]};
	assign e_a_number_reg	= a_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign e_b_number_reg	= b_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign e_c_number_reg	= c_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];
	assign s_a_number_reg	= a_number_i[size - size_exception_field - 1];
	assign s_b_number_reg	= b_number_i[size - size_exception_field - 1];
	assign s_c_number_reg	= c_number_i[size - size_exception_field - 1];
	assign sp_case_a_number_reg	= a_number_i[size - 1 : size - size_exception_field];
	assign sp_case_b_number_reg	= b_number_i[size - 1 : size - size_exception_field];
	assign sp_case_c_number_reg	= c_number_i[size - 1 : size - size_exception_field];
	//-------------------------------------------------------------------------------------
	
	
	//instantiate multiply component
	multiply #(	.size_mantissa(size_mantissa),
					.size_counter(size_counter),
					.size_mul_mantissa(size_mul_mantissa))
		multiply_instance (	.a_mantissa_i(m_a_number_reg),
									.b_mantissa_i(m_b_number_reg),
									.mul_mantissa(mul_mantissa));
	
	assign c_mantissa = {1'b0,m_c_number_reg, {(size_mantissa-1'b1){1'b0}}};
	assign exp_ab = e_a_number_reg + e_b_number_reg - ({1'b1,{(size_exponent-1'b1){1'b0}}} - 1'b1);
	assign {modify_exp_ab, modify_exp_c, unnormalized_exp} = (exp_ab >= e_c_number_reg)? {8'd0,(exp_ab - e_c_number_reg), exp_ab} : {(e_c_number_reg - exp_ab), 8'd0, e_c_number_reg};
	
	//instantiate shifter component for mul_mantissa shift, mul_mantissa <=> ab_mantissa
	shifter #(	.INPUT_SIZE(size_mul_mantissa),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(size_mul_mantissa + 1'b1),
					.DIRECTION(1'b0), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_ab_instance(	.a(mul_mantissa),//mantissa
								.arith(1'b0),//logical shift
								.shft(modify_exp_ab),
								.shifted_a(ab_shifted_mul_mantissa));//
	
	//instantiate shifter component for c_mantissa shift
	shifter #(	.INPUT_SIZE(size_mul_mantissa),
					.SHIFT_SIZE(size_exponent),
					.OUTPUT_SIZE(size_mul_mantissa + 1'b1),
					.DIRECTION(1'b0), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_c_instance(	.a(c_mantissa),//mantissa
								.arith(1'b0),//logical shift
								.shft(modify_exp_c),
								.shifted_a(c_shifted_mantissa));//

	
	//instantiate effective_op component
	effective_op effective_op_instance(	.sign_a(s_a_number_reg),
													.sign_b(s_b_number_reg),
													.sign_c(s_c_number_reg),
													.sub(sub),
													.eff_sub(eff_sub));
	
	
	//instantiate compare_exponent component
	compare_exponent #(	.size_exponent(size_exponent))
		compare_exponent_instance	(	.exp_ab(exp_ab),
												.exp_c(e_c_number_reg),
												.compare(comp_exp));
	
	
	//instantiate sign_comp component
	sign_comp sign_comp_instance(	.sign_a(s_a_number_reg),
											.sign_b(s_b_number_reg),
											.sign_c(s_c_number_reg),
											.comp_exp(comp_exp),
											.eff_sub(eff_sub),
											.sign_add(ovf),
											.sign_res(sign_res));

											
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
		leading_zeros_instance(	.a(acc_resulting_number),//mantissa 
										.ovf(ovf), //??????acc_resulting_number[size_mul_mantissa]
										.lz(lz_mul));
	
	
	//instantiate shifter component
	shifter #(	.INPUT_SIZE(size_mul_mantissa + 1'b1),
					.SHIFT_SIZE(size_mul_counter),
					.OUTPUT_SIZE(size_mul_mantissa + 2'd2),
					.DIRECTION(1'b1), //0=right, 1=left
					.PIPELINE(pipeline),
					.POSITION(pipeline_pos))
		shifter_instance(	.a(acc_resulting_number),//mantissa
								.arith(1'b0),//logical shift
								.shft(lz_mul),
								.shifted_a(normalized_mantissa));//resulted mantissa after accumulation --- size_output bits!!! 

	//instantiate special_cases_mul_acc component
	special_cases_mul_acc	#(	.size_exception_field	(size_exception_field),
								.zero                   (zero                ),
								.normal_number          (normal_number       ),
								.infinity		       	(infinity		     ),
								.NaN			        (NaN			     ))
		special_cases_mul_acc_instance	(	.sp_case_a_number(sp_case_a_number_reg),
											.sp_case_b_number(sp_case_b_number_reg),
											.sp_case_c_number(sp_case_c_number_reg),
											.sp_case_result_o(sp_case_result_o));
	
	assign final_exponent = unnormalized_exp - lz_mul + 2'd2;
	assign final_mantissa = normalized_mantissa[size_mul_mantissa : size_mul_mantissa+2-size_mantissa];
	assign resulting_number_o = {sp_case_result_o, sign_res, final_exponent, final_mantissa};
endmodule
