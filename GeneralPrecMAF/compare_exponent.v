`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:21:07 10/21/2013 
// Design Name: 
// Module Name:    compare_exponent 
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
module compare_exponent	#(parameter size_exponent	= 8)
									(	input [size_exponent : 0] exp_ab,
										input [size_exponent-1:0] exp_c,
										output compare);
	
	assign compare = (exp_c < exp_ab)? 1'b1 : 1'b0;

endmodule
