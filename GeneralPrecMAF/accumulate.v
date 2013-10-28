`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:59:10 10/15/2013 
// Design Name: 
// Module Name:    accumulate 
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
module accumulate #(	parameter size_mantissa = 24,	//mantissa bits
							parameter size_counter	= 5,	//log2(size_quotient) + 1 = 5
							parameter size_mul_mantissa = size_mantissa + size_mantissa)
						(	input [size_mul_mantissa-1:0] ab_number_i,
							input [size_mul_mantissa-1:0] c_number_i,
							input sub,
							output ovf,
							output[size_mul_mantissa  :0] acc_resulting_number_o);

assign {ovf, acc_resulting_number_o} = sub? ((ab_number_i >=c_number_i)? (ab_number_i - c_number_i) : (c_number_i - ab_number_i)) : c_number_i + ab_number_i;

endmodule
