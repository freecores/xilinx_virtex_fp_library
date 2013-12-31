`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:31:28 12/19/2013 
// Design Name: 
// Module Name:    DualPathAdderConversion
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
module DualPathAdderConversion #(	parameter size_mantissa 			= 24, //1.M
									parameter size_exponent 			= 8,
									parameter size_exception_field		= 2,
									parameter size_counter				= 5,//log2(size_mantissa) + 1 = 5)
									parameter [size_exception_field - 1 : 0] zero			= 0, //00
									parameter [size_exception_field - 1 : 0] normal_number	= 1, //01
									parameter [size_exception_field - 1 : 0] infinity		= 2, //10
									parameter [size_exception_field - 1 : 0] NaN			= 3, //11
									parameter size_integer			= 32,
									parameter counter_integer		= 6,//log2(size_integer) + 1 = 6)
									parameter [1 : 0] FP_operation 	= 0, //00 
									parameter [1 : 0] FP_to_int		= 1, //01 - mapped on FarPath
									parameter [1 : 0] int_to_FP		= 2, //10 - mapped on ClosePath
									
									parameter pipeline					= 0,
									parameter pipeline_pos				= 0,	// 8 bits
									parameter size						= size_mantissa + size_exponent + size_exception_field
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
	parameter exp_biasedCP 			= bias + size_mantissa;
	parameter exponentCP 			= exp_biasedCP - 1'b1;
	
	wire [size_exception_field - 1 : 0] sp_case_a_number, sp_case_b_number; 
	wire [size_mantissa - 1 : 0] m_a_number, m_b_number;
	wire [size_exponent - 1 : 0] e_a_number, e_b_number;
	wire s_a_number, s_b_number; 
	
	wire [size_exponent     : 0] a_greater_exponent, b_greater_exponent;
	
	wire [size_exponent - 1 : 0] exp_difference;
	wire [size_exponent     : 0] exp_inter;
	wire eff_op;
	
	wire [size_exception_field - 1 : 0] sp_case_o, resulted_exception_field;
	wire resulted_sign;
	wire swap;
	
	wire zero_flag;
	
	wire [max_size - 1 : 0] max_entityFP;
	wire [size_exponent - 1	: 0] resulted_e_oFP;
	wire [size_exponent - 1 : 0] adjust_mantissaFP;
	wire [size_exponent - 1 : 0] unadjusted_exponentFP;
	wire [size_mantissa - 1 : 0] mantissa_to_shiftFP, shifted_m_bFP, convert_neg_mantissaFP;
	wire [size_mantissa + 1 : 0] adder_mantissaFP;
	wire [size_mantissa - 1 : 0] resulted_inter_m_oFP, resulted_m_oFP;
	wire [size_mantissa - 1 : 0] initial_rounding_bitsFP, inter_rounding_bitsFP;
	wire [double_size_mantissa:0] normalized_mantissaFP;
	wire [size_mantissa  : 0] unnormalized_mantissaFP, conversion_dummiesFP;
	wire [size_exponent     : 0] shift_value_when_positive_exponentFP, shift_value_when_negative_exponentFP;
	wire [size_exponent - 1 : 0] shift_valueFP, shft_valFP;
	wire [size_exponent     : 0] exponentFP;
	wire dummy_bitFP;
	
	wire [max_size - 1 : 0] max_entityCP;
	wire [size_mantissa - 1 : 0] shifted_m_bCP;
	wire [size_mantissa + 1 : 0] adder_mantissaCP;
	wire [size_mantissa 	: 0] unnormalized_mantissaCP;
	wire [size_mantissa 	: 0] rounded_mantissaCP;
	wire [size_mantissa - 1 : 0] r_mantissaCP;
	wire [size_exponent - 1	: 0] resulted_e_oCP;
	wire [size_mantissa - 1 : 0] resulted_m_oCP;
	wire [size_exponent - 1 : 0] unadjusted_exponentCP, adjust_exponentCP;
	wire [size_exponent - 1 : 0] exp_selectionCP;
	wire [max_size - size_mantissa : 0] dummy_bitsCP;
	wire [max_counter - 1 : 0] lzsCP;
	wire init_shft_bitCP, shft_bitCP;
	wire lsb_shft_bitCP;
	
	wire do_conversion;
	
	assign do_conversion = |conversion; //let me know if there is a conversion

	assign e_a_number	= a_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1]; 	//exponent for a_number_i
	assign e_b_number = b_number_i[size_mantissa + size_exponent - 1 : size_mantissa - 1];		//exponent for b_number_i
	assign s_a_number = a_number_i[size - size_exception_field - 1];							//sign for a_number_i
	assign s_b_number = b_number_i[size - size_exception_field - 1];							//sign for b_number_i
	assign sp_case_a_number = a_number_i[size - 1 : size - size_exception_field];				//special_case for a_number_i
	assign sp_case_b_number = b_number_i[size - 1 : size - size_exception_field];				//special_case for b_number_i
	
	//find the greater exponent
	assign a_greater_exponent = e_a_number - e_b_number;
	assign b_greater_exponent = e_b_number - e_a_number;
	
	//find the difference between exponents
	assign exp_difference 	= (a_greater_exponent[size_exponent])? b_greater_exponent[size_exponent - 1 : 0] : a_greater_exponent[size_exponent - 1 : 0];
	assign exp_inter 		= (b_greater_exponent[size_exponent])? {1'b0, e_a_number} : {1'b0, e_b_number};
	
	//set shifter always on m_b_number
	assign {swap, m_a_number, m_b_number} = do_conversion? {1'b0,{e_a_number[0], a_number_i[size_mantissa - 2 :0]}, {1'b1, b_number_i[size_mantissa - 2 :0]}} :
										(b_greater_exponent[size_exponent])?
													{1'b0, {1'b1, a_number_i[size_mantissa - 2 :0]}, {1'b1, b_number_i[size_mantissa - 2 :0]}} : 
													{1'b1, {1'b1, b_number_i[size_mantissa - 2 :0]}, {1'b1, a_number_i[size_mantissa - 2 :0]}};

	effective_op effective_op_instance( .a_sign(s_a_number), .b_sign(s_b_number), .sub(sub), .eff_op(eff_op));								
	
	
	//------------------------------------------------------- start ClosePath addition and conversion
	assign {shifted_m_bCP, init_shft_bit} = (exp_difference)? {1'b0, m_b_number[size_mantissa-1:0]} : {m_b_number, 1'b0};
				
	//compute unnormalized_mantissa
	assign adder_mantissaCP = {1'b0, m_a_number} - shifted_m_bCP;
	assign {unnormalized_mantissaCP, shft_bitCP} =
								(adder_mantissaCP[size_mantissa + 1])?	({~adder_mantissaCP[size_mantissa	: 0], ~init_shft_bitCP}) :
																		({adder_mantissaCP[size_mantissa	: 0], init_shft_bitCP});
	
	assign max_entityCP = do_conversion? (s_a_number? (~a_number_i[max_size-1 : 0]) : a_number_i[max_size-1 : 0]) : 
													{{(max_size-size_mantissa-1){1'b0}}, unnormalized_mantissaCP[size_mantissa : 0]};
	assign lsb_shft_bitCP = (do_conversion)? s_a_number : max_entityCP[0];
	
	assign max_ovfCP = do_conversion? 1'b0 : unnormalized_mantissaCP[size_mantissa];
	
	//compute leading_zeros over unnormalized mantissa
	leading_zeros #(.SIZE_INT(max_size), .SIZE_COUNTER(max_counter), .PIPELINE(pipeline))
		leading_zeros_CP_instance (	.a(max_entityCP), 
									.ovf(max_ovfCP), 
									.lz(lzsCP));
								
	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(max_size),
				.SHIFT_SIZE(max_counter),
				.OUTPUT_SIZE(max_size + 1),
				.DIRECTION(1'b1), //0=right, 1=left
				.PIPELINE(pipeline),
				.POSITION(pipeline_pos))
		shifter_CP_instance(	.a(max_entityCP),//mantissa
								.arith(lsb_shft_bitCP),
								.shft(lzsCP),
								.shifted_a({r_mantissaCP, dummy_bitsCP}));
		
	assign rounded_mantissaCP = (r_mantissaCP[0] && dummy_bitsCP[max_size - size_mantissa] && (|dummy_bitsCP[max_size - size_mantissa - 1 : 0 ]))? 
										r_mantissaCP + 1'b1 : r_mantissaCP;
	assign resulted_m_oCP = (rounded_mantissaCP[size_mantissa])? rounded_mantissaCP[size_mantissa : 1] :
																rounded_mantissaCP[size_mantissa-1:0];
	
	assign ovfCP = do_conversion? s_a_number : adder_mantissaCP[size_mantissa+1];
	
	assign exp_selectionCP = do_conversion? exponentCP : exp_inter;
	assign adjust_exponentCP = exp_selectionCP - lzsCP;
	assign unadjusted_exponentCP = adjust_exponentCP + size_diff_i_m;
		
	assign resulted_e_oCP = (do_conversion & ~(|max_entityCP))? bias : unadjusted_exponentCP + rounded_mantissaCP[size_mantissa];
	//------------------------------------------------------- end ClosePath addition and conversion
	
	
	//--------------------------------------------- start FarPath addition and conversion
	assign exponentFP = e_a_number - bias;
	assign shift_value_when_positive_exponentFP = max_size - 2'd2  - exponentFP[size_exponent-1 : 0];
	assign shift_value_when_negative_exponentFP = max_size + (~exponentFP[size_exponent-1 : 0]);
	assign shift_valueFP = (exponentFP[size_exponent])? shift_value_when_negative_exponentFP[size_exponent - 1 : 0] :
	                     (shift_value_when_positive_exponentFP[size_exponent])? (~shift_value_when_positive_exponentFP[size_exponent - 1 : 0]): 
	                                                                           shift_value_when_positive_exponentFP[size_exponent - 1 : 0];
	assign shft_valFP = do_conversion? shift_valueFP : exp_difference;
	
	assign convert_neg_mantissaFP = {1'b0, ~a_number_i[size_mantissa-2 : 0]};
	assign conversion_dummiesFP = {(size_mantissa+1){1'b1}};
	
	assign mantissa_to_shiftFP = do_conversion? (s_a_number? convert_neg_mantissaFP + 1'b1 : {1'b1, a_number_i[size_mantissa-2 : 0]}) : m_b_number;
	assign arith_shiftFP = do_conversion? s_a_number : 1'b0;
	
	//shift m_b_number				
	shifter #(	.INPUT_SIZE(size_mantissa),
				.SHIFT_SIZE(size_exponent),
				.OUTPUT_SIZE(double_size_mantissa),
				.DIRECTION(1'b0), //0=right, 1=left
				.PIPELINE(pipeline),
				.POSITION(pipeline_pos))
		m_b_shifter_FP_instance(	.a(mantissa_to_shiftFP),
									.arith(arith_shiftFP),
									.shft(shft_valFP),
									.shifted_a({shifted_m_bFP, initial_rounding_bitsFP}));
	
	assign max_entityFP = {s_a_number, shifted_m_bFP[size_mantissa-1 : 0], initial_rounding_bitsFP[size_mantissa-1 : size_mantissa - size_diff_i_m + 1]};
	
	//compute unnormalized_mantissa
	assign adder_mantissaFP = (eff_op)? ({1'b0, m_a_number} - {1'b0, shifted_m_bFP}) : ({1'b0, m_a_number} + {1'b0, shifted_m_bFP});
	
	assign {unnormalized_mantissaFP, inter_rounding_bitsFP} = 
								(adder_mantissaFP[size_mantissa + 1])?	({~adder_mantissaFP[size_mantissa : 0], ~initial_rounding_bitsFP}) :
																		({adder_mantissaFP[size_mantissa 	: 0], initial_rounding_bitsFP});
		
	assign adjust_mantissaFP = unnormalized_mantissaFP[size_mantissa]? 2'd0 :
										unnormalized_mantissaFP[size_mantissa-1]? 2'd1 : 2'd2;

	//compute shifting over unnormalized_mantissa
	shifter #(	.INPUT_SIZE(double_size_mantissa+1),
				.SHIFT_SIZE(size_exponent),
				.OUTPUT_SIZE(double_size_mantissa+2),
				.DIRECTION(1'b1),
				.PIPELINE(pipeline),
				.POSITION(pipeline_pos))
		unnormalized_no_shifter_FP_instance(.a({unnormalized_mantissaFP, inter_rounding_bitsFP}),
											.arith(1'b0),
											.shft(adjust_mantissaFP),
											.shifted_a({normalized_mantissaFP, dummy_bitFP}));
	
	//instantiate rounding_component
	rounding #(	.SIZE_MOST_S_MANTISSA(size_mantissa),
				.SIZE_LEAST_S_MANTISSA(size_mantissa + 2'd1))
		rounding_FP_instance(	.unrounded_mantissa(normalized_mantissaFP[double_size_mantissa : double_size_mantissa - size_mantissa + 1]),
								.dummy_bits(normalized_mantissaFP[double_size_mantissa - size_mantissa: 0]),
								.rounded_mantissa(resulted_inter_m_oFP));
	
	assign resulted_m_oFP = do_conversion? max_entityFP[size_mantissa-1 : 0] : resulted_inter_m_oFP;
	assign unadjusted_exponentFP = exp_inter - adjust_mantissaFP;	
	assign resulted_e_oFP = do_conversion? max_entityFP[size_mantissa+size_exponent-2 : size_mantissa-1] : unadjusted_exponentFP + 1'b1;
	//-------------------------------------------------------- end FarPath addition and conversion
	

	//compute exception_field
	special_cases	#(	.size_exception_field(size_exception_field),
						.zero(zero), 
						.normal_number(normal_number),
						.infinity(infinity),
						.NaN(NaN))
		special_cases_instance( .sp_case_a_number(sp_case_a_number),
								.sp_case_b_number(sp_case_b_number),
								.sp_case_result_o(sp_case_o)); 
	
	assign resulted_exception_field = do_conversion? sp_case_a_number : sp_case_o;
	
	//set zero_flag in case of equal numbers
	assign zero_flag = ((exp_difference > 1 | !eff_op) & conversion != int_to_FP)? 
							~((|{resulted_m_oFP, sp_case_o[1]}) & (|sp_case_o)) : 
							~((|{resulted_m_oCP, sp_case_o[1]}) & (|sp_case_o));
	
	assign resulted_sign = do_conversion? 	s_a_number : 
											((exp_difference > 1 | !eff_op)?	(!a_greater_exponent[size_exponent]? s_a_number : (eff_op? ~s_b_number : s_b_number)) : 
																				(ovfCP ^ swap));
	
	assign resulted_number_o = (zero_flag)? {size{1'b0}} : ((exp_difference > 1 | !eff_op) & conversion != int_to_FP)? 	
													{resulted_exception_field, resulted_sign, resulted_e_oFP, resulted_m_oFP[size_mantissa-2 : 0]}:
													{resulted_exception_field, resulted_sign, resulted_e_oCP, resulted_m_oCP[size_mantissa-2 : 0]};
endmodule
