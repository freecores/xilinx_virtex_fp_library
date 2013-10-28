`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:53:42 10/21/2013 
// Design Name: 
// Module Name:    sign_comp 
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
module sign_comp( input sign_a,
						input sign_b,
						input sign_c,
						input comp_exp,
						input eff_sub,
						input sign_add,
						output sign_res);

assign sign_res = (eff_sub)?	((comp_exp)? sign_a^sign_b : (!comp_exp & !sign_add)? sign_c : sign_a^sign_b) : sign_c;
										
endmodule
