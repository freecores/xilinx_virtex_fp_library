`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:09:49 11/04/2013 
// Design Name: 
// Module Name:    SinglePathAdderConversion 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: A ± B with mapped conversions
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module SinglePathAdderConversion #(	parameter size_mantissa 	= 24, //calculate the size containing the hiden bit 1.M
							parameter size_exponent 			= 8,
							parameter size_exception_field		= 2,
							parameter size_counter				= 5,	//log2(size_mantissa) + 1 = 5)
							parameter [size_exception_field - 1 : 0] zero			= 0, //00
							parameter [size_exception_field - 1 : 0] normal_number	= 1, //01
							parameter [size_exception_field - 1 : 0] infinity		= 2, //10
							parameter [size_exception_field - 1 : 0] NaN			= 3, //11
							parameter size_integer			= 32,
							parameter counter_integer		= 6,//log2(size_integer) + 1 = 6)
							parameter [1 : 0] FP_operation 	= 0, //00 
							parameter [1 : 0] FP_to_int		= 1, //01 
							parameter [1 : 0] int_to_FP		= 2, //10 
							parameter pipeline				= 0,
							parameter pipeline_pos			= 0,	// 8 bits
							parameter size	= size_mantissa + size_exponent + size_exception_field
							)			
							(	input [1:0] conversion,
								input sub,
								input [size - 1 : 0] a_number_i,
								input [size - 1 : 0] b_number_i,
								output[size - 1 : 0] resulted_number_o);
	
	parameter double_size_mantissa	= size_mantissa + size_mantissa;
	parameter double_size_counter	= size_counter + 1;
	parameter max_size 				= (size_integer > size_mantissa)? size_integer : size_mantissa;
	parameter max_counter			= (counter_integer > size_counter)? counter_integer : size_counter;
	parameter size_diff_i_m 		= (size_integer > size_mantissa)? (size_integer - size_mantissa) : (size_mantissa - size_integer);
	parameter bias 					= {1'b0,{(size_exponent-1){1'b1}}};
	parameter exp_biased 			= bias + size_mantissa;
	parameter exponent				= exp_biased - 1'b1;
	parameter subtr					= max_size -2'd2;
	
	
	wire [size_exception_field - 1 : 0] sp_case_a_number, sp_case_b_number; 
	wire [size_mantissa - 1 : 0] m_a_number, m_b_number;
	wire [size_exponent - 1 : 0] e_a_number, e_b_number;
	wire s_a_number, s_b_number;
	
	wire [size_exponent     : 0] a_greater_exponent, b_greater_exponent;
	
	wire [size_exponent - 1 : 0] exp_difference;
	wire [size_exponent     : 0] exp_inter;
	wire [size_mantissa - 1 : 0] shifted_m_b, convert_neg_mantissa, mantissa_to_shift;
	
	wire [size_mantissa - 1 : 0] initial_rounding_bits, inter_rounding_bits;
	wire eff_op;
	
	wire [size_mantissa + 1	: 0] adder_mantissa;
	wire [size_mantissa 	: 0] unnormalized_mantissa;
	
	wire [size_exception_field - 1 : 0] sp_case_o, resulted_exception_field;
	wire [size_mantissa - 1	: 0] resulted_mantissa;
	wire [size_exponent - 1 : 0] resulted_exponent;
	wire resulted_sign;
	
	wire zero_flag;
	
	wire [size_exponent  : 0] subtracter;
	
	wire [max_size - size_mantissa : 0] dummy_bits;
	wire [size_exponent     : 0] shift_value_when_positive_exponent, shift_value_when_negative_exponent;
	wire [size_exponent - 1 : 0] shift_value, shft_val;
	wire lsb_shft_bit;
	
	wire [size_exponent - 1	: 0] max_resulted_e_o;
	wire [size_exponent - 1 : 0] max_unadjusted_exponent, max_adjust_exponent;
	wire [size_exponent - 1 : 0] max_exp_selection;
	wire [size_mantissa - 1 : 0] r_mantissa;
	wire [size_mantissa 	: 0] max_rounded_mantissa;
	wire [max_counter - 1 : 0] max_lzs;
	wire [max_size - 1 : 0] max_entityINT_FP, max_entityFP_INT;
	wire arith_shift;
	wire max_ovf;
	
	wire do_conversion;
	
	assign do_conversion = |conversion; //let me know if there is a conversion
	
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
	
	assign subtracter =  e_a_number - bias;
	assign shift_value_when_positive_exponent = subtr - subtracter[size_exponent-1 : 0];
	assign shift_value_when_negative_exponent = max_size + (~subtracter[size_exponent-1 : 0]);
	assign shift_value = (subtracter[size_exponent])? shift_value_when_negative_exponent[size_exponent - 1 : 0] :
	                     (shift_value_when_positive_exponent[size_exponent])? (~shift_value_when_positive_exponent[size_exponent - 1 : 0]): 
	                                                                           shift_value_when_positive_exponent[size_exponent - 1 : 0];
	assign shft_val = do_conversion? shift_value : exp_difference;
	
	assign convert_neg_mantissa = {1'b0, ~a_number_i[size_mantissa-2 : 0]};
	
	assign mantissa_to_shift = conversion[0]? (s_a_number? convert_neg_mantissa + 1'b1 : {1'b1, a_number_i[size_mantissa-2 : 0]}) : m_b_number;
	assign arith_shift = conversion[0]? s_a_number : 1'b0;
	
	//shift m_b_number				
	shifter #(	.INPUT_SIZE(size_mantissa),
				.SHIFT_SIZE(size_exponent),
				.OUTPUT_SIZE(double_size_mantissa),
				.DIRECTION(1'b0), //0=right, 1=left
				.PIPELINE(pipeline),
				.POSITION(pipeline_pos))
		m_b_shifter_instance(	.a(mantissa_to_shift),//mantissa
								.arith(arith_shift),//logical shift
								.shft(shft_val),
								.shifted_a({shifted_m_b, initial_rounding_bits}));
	
	assign max_entityFP_INT = {s_a_number, shifted_m_b[size_mantissa-1 : 0], initial_rounding_bits[size_mantissa-1 : size_mantissa - size_diff_i_m + 1]};
	
	//istantiate effective_operation_component
	effective_op effective_op_instance( .a_sign(s_a_number), .b_sign(s_b_number), .sub(sub), .eff_op(eff_op));
			
	//compute unnormalized_mantissa
	assign adder_mantissa = (eff_op)? ({1'b0, m_a_number} - {1'b0, shifted_m_b}) : ({1'b0, m_a_number} + {1'b0, shifted_m_b});
	
	assign {unnormalized_mantissa, inter_rounding_bits} = 
								(adder_mantissa[size_mantissa + 1])?	({~adder_mantissa[size_mantissa : 0], ~initial_rounding_bits}) : 
																		({adder_mantissa[size_mantissa 	: 0], initial_rounding_bits});
	
	assign max_entityINT_FP = do_conversion? (s_a_number? (~a_number_i[max_size-1 : 0]) : a_number_i[max_size-1 : 0]) : 
													{{(max_size-size_mantissa-1){1'b0}}, unnormalized_mantissa[size_mantissa : 0]};
	assign lsb_shft_bit = (do_conversion)? s_a_number : max_entityINT_FP[0];
	
	assign max_ovf = do_conversion? 1'b0 : unnormalized_mantissa[size_mantissa];
	
	//compute leading_zeros over unnormalized mantissa
	leading_zeros #(	.SIZE_INT(max_size), .SIZE_COUNTER(max_counter), .PIPELINE(pipeline))
		leading_zeros_instance (.a(max_entityINT_FP), 
								.ovf(max_ovf), 
								.lz(max_lzs));
	
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(max_size),
				.SHIFT_SIZE(max_counter),
				.OUTPUT_SIZE(max_size + 1),
				.DIRECTION(1'b1), //0=right, 1=left
				.PIPELINE(pipeline),
				.POSITION(pipeline_pos))
		shifter_instance(	.a(max_entityINT_FP),//mantissa
							.arith(lsb_shft_bit),//logical shift
							.shft(max_lzs),
							.shifted_a({r_mantissa, dummy_bits}));
									
	//instantiate rounding_component
	rounding #(	.SIZE_MOST_S_MANTISSA(size_mantissa + 1),
				.SIZE_LEAST_S_MANTISSA(max_size - size_mantissa + 1))
		rounding_instance(	.unrounded_mantissa({1'b0,r_mantissa}),
		                    .dummy_bits(dummy_bits),
		                    .rounded_mantissa(max_rounded_mantissa));
	
	
	assign max_exp_selection = do_conversion? exponent : exp_inter;
	assign max_adjust_exponent = max_exp_selection - max_lzs;
	assign max_unadjusted_exponent = max_adjust_exponent + size_diff_i_m;
	assign max_resulted_e_o = (do_conversion & ~(|max_entityINT_FP))? bias : max_unadjusted_exponent + max_rounded_mantissa[size_mantissa];
	
	assign resulted_exponent = conversion[0]? 	max_entityFP_INT[size_mantissa+size_exponent-2 : size_mantissa-1] : max_resulted_e_o;
	assign resulted_mantissa = conversion[0]?	max_entityFP_INT[size_mantissa-1 : 0] :
												(max_rounded_mantissa[size_mantissa])? 	(max_rounded_mantissa[size_mantissa : 1]) : 
																						(max_rounded_mantissa[size_mantissa-1 : 0]);
	
	//compute exception_field
	special_cases	#(	.size_exception_field(size_exception_field),
						.zero(zero), 
						.normal_number(normal_number),
						.infinity(infinity),
						.NaN(NaN))
		special_cases_instance( .sp_case_a_number(sp_case_a_number),
								.sp_case_b_number(sp_case_b_number),
								.sp_case_result_o(sp_case_o)); 
								
	//compute special case
	assign resulted_exception_field = do_conversion? sp_case_a_number : sp_case_o;
	
	//set zero_flag in case of equal numbers
	assign zero_flag = ~((|{resulted_mantissa,sp_case_o[1]}) & (|sp_case_o));
	
	//compute resulted_sign
	assign resulted_sign = do_conversion? s_a_number : ((eff_op)? 
					(!a_greater_exponent[size_exponent]? (!b_greater_exponent[size_exponent]? ~adder_mantissa[size_mantissa+1] : s_a_number) : ~s_b_number) : 
					s_a_number);
											
	assign resulted_number_o = (zero_flag)? {size{1'b0}} :
									{resulted_exception_field, resulted_sign, resulted_exponent, resulted_mantissa[size_mantissa - 2 : 0]};
	
endmodule
