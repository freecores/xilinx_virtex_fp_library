`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:56:11 10/07/2013 
// Design Name: 
// Module Name:    special_cases 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module special_cases	#(	parameter size_exception_field = 2'd2,
								parameter zero				= 0, //00
								parameter normal_number = 1, //01
								parameter infinity		= 2, //10
								parameter NaN				= 3) //11
							( 	input	[size_exception_field - 1 : 0] sp_case_divident_i,
								input [size_exception_field - 1 : 0] sp_case_divisor_i,
								output reg [size_exception_field - 1 : 0] sp_case_quotient_o); 
 
	always
		@(*)
	begin
		case ({sp_case_divident_i, sp_case_divisor_i})
			{zero[size_exception_field - 1 : 0], zero[size_exception_field - 1 : 0]}: 							sp_case_quotient_o = NaN; 
			{zero[size_exception_field - 1 : 0], normal_number[size_exception_field - 1 : 0]}: 				sp_case_quotient_o = zero; 
			{zero[size_exception_field - 1 : 0], infinity[size_exception_field - 1 : 0]}: 					sp_case_quotient_o = zero; 
			{zero[size_exception_field - 1 : 0], NaN[size_exception_field - 1 : 0]}: 							sp_case_quotient_o = NaN; 
			{normal_number[size_exception_field - 1 : 0], zero[size_exception_field - 1 : 0]}: 				sp_case_quotient_o = infinity; 
			{normal_number[size_exception_field - 1 : 0], normal_number[size_exception_field - 1 : 0]}: 	sp_case_quotient_o = normal_number; 
			{normal_number[size_exception_field - 1 : 0], infinity[size_exception_field - 1 : 0]}: 		sp_case_quotient_o = zero; 
			{normal_number[size_exception_field - 1 : 0], NaN[size_exception_field - 1 : 0]}: 				sp_case_quotient_o = NaN; 
			{infinity[size_exception_field - 1 : 0], zero[size_exception_field - 1 : 0]}: 					sp_case_quotient_o = NaN; 
			{infinity[size_exception_field - 1 : 0], normal_number[size_exception_field - 1 : 0]}: 		sp_case_quotient_o = infinity; 
			{infinity[size_exception_field - 1 : 0], infinity[size_exception_field - 1 : 0]}: 				sp_case_quotient_o = NaN; 
			{infinity[size_exception_field - 1 : 0], NaN[size_exception_field - 1 : 0]}: 						sp_case_quotient_o = NaN; 
			{NaN[size_exception_field - 1 : 0], zero[size_exception_field - 1 : 0]}: 							sp_case_quotient_o = NaN; 
			{NaN[size_exception_field - 1 : 0], normal_number[size_exception_field - 1 : 0]}: 				sp_case_quotient_o = NaN; 
			{NaN[size_exception_field - 1 : 0], infinity[size_exception_field - 1 : 0]}: 						sp_case_quotient_o = NaN; 
			{NaN[size_exception_field - 1 : 0], NaN[size_exception_field - 1 : 0]}: 							sp_case_quotient_o = NaN; 
			default:																													sp_case_quotient_o = zero;
		endcase
	end
 
endmodule
