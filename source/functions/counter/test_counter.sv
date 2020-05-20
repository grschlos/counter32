//------------------------------------------------------------------------------
//  Copyright 2016 Konstantin Shchablo
//  Copyright 2018 Ilya Butorov
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//      Information
// Company: JINR PMTLab
// Author: 	Ilya Butorov
// Email: 	butorov.ilya@gmail.com
//------------------------------------------------------------------------------

module test_counter
#(
	parameter DATA_WIDTH=8, parameter ADDR_WIDTH=22, parameter CLK_FREQ=200000000
 )
 (
	input wire clk,
	input wire [DATA_WIDTH-1:0]addr,
	input wire [DATA_WIDTH-1:0]data_in, output wire [DATA_WIDTH-1:0]data_out,
	input wire we, input wire initialization, input wire res,

	output wire [31:0]counter_time_ex,
	output wire [31:0]data_ex[3:0],

	input wire start,
	output wire stop,

	input wire [3:0]signal
);

(* syn_encoding = "safe" *) reg [2:0] state;

parameter init = 0, idle = 1, write = 2, counter = 3, delay = 4, end_counter = 5;

reg [DATA_WIDTH-1:0]ram[ADDR_WIDTH-1:0];

reg [31:0]count_time;
reg [31:0]sec;
reg [31:0]data[3:0];
reg [7:0]secTime; // Count time, s

assign counter_time_ex[7:0] 	= ram[6];
assign counter_time_ex[15:8] 	= ram[7];
assign counter_time_ex[23:16] = ram[8];
assign counter_time_ex[31:24] = ram[9];

assign data_ex[0][7:0] 	 = ram[2];
assign data_ex[0][15:8]  = ram[3];
assign data_ex[0][23:16] = ram[4];
assign data_ex[0][31:24] = ram[5];

assign data_ex[1][7:0] 	 = ram[10];
assign data_ex[1][15:8]  = ram[11];
assign data_ex[1][23:16] = ram[12];
assign data_ex[1][31:24] = ram[13];

assign data_ex[2][7:0] 	 = ram[14];
assign data_ex[2][15:8]  = ram[15];
assign data_ex[2][23:16] = ram[16];
assign data_ex[2][31:24] = ram[17];

assign data_ex[3][7:0] 	 = ram[18];
assign data_ex[3][15:8]  = ram[19];
assign data_ex[3][23:16] = ram[20];
assign data_ex[3][31:24] = ram[21];

reg [3:0]enable;
assign enable = ram[0][7:4];
reg reset;

always @ (posedge signal[0] or posedge reset) begin
	if (reset)
		data[0] <= 0;
	else
		data[0] <= data[0] + enable[3];
end
always @ (posedge signal[1] or posedge reset) begin
	if (reset)
		data[1] <= 0;
	else
		data[1] <= data[1] + enable[2];
end
always @ (posedge signal[2] or posedge reset) begin
	if (reset)
		data[2] <= 0;
	else
		data[2] <= data[2] + enable[1];
end
always @ (posedge signal[3] or posedge reset) begin
	if (reset)
		data[3] <= 0;
	else
		data[3] <= data[3] + enable[0];
end

always @ (posedge signal[0] or posedge reset) begin
	if(reset)
		count_time <= 0;
	else 
		count_time <= count_time + 1;
end

always @ (posedge clk) begin 
	case(state)
		init: begin
			if(res || initialization || (ram[0][0] == 1'b1)) begin
				state <= init;
			end
			ram[0]  	<= 128;
			ram[1]  	<= 0;

			ram[2]  	<= 0;
			ram[3]  	<= 0;
			ram[4]  	<= 0;
			ram[5]  	<= 0;

			ram[6]  	<= 0;
			ram[7]  	<= 0;
			ram[8]  	<= 0;
			ram[9]  	<= 0;

			ram[10]  <= 0;
			ram[11]  <= 0;
			ram[12]  <= 0;
			ram[13]  <= 0;

			ram[14]  <= 0;
			ram[15]  <= 0;
			ram[16]  <= 0;
			ram[17]  <= 0;

			ram[18]  <= 0;
			ram[19]  <= 0;
			ram[20]  <= 0;
			ram[21]	<= 0;

			sec 	  	<= 0;
			secTime 	<= 0;
			stop 	  	<= 0;

			state   	<= idle;
		end

		idle: begin
			if(res || initialization || (ram[0][0] == 1'b1)) begin
				state <= init;
			end
			if(start) begin
				state <= delay;
			end
			if(we) begin
				state <= write;
			end

			case(addr)
				8'h26:  data_out <= ram[0];
				8'h27:  data_out <= ram[1];

				8'h28:  data_out <= ram[2];
				8'h29:  data_out <= ram[3];
				8'h2a:  data_out <= ram[4];
				8'h2b:  data_out <= ram[5];

				8'h2c:  data_out <= ram[6];
				8'h2d:  data_out <= ram[7];
				8'h2e:  data_out <= ram[8];
				8'h2f:  data_out <= ram[9];

				8'h30:  data_out <= ram[10];
				8'h31:  data_out <= ram[11];
				8'h32:  data_out <= ram[12];
				8'h33:  data_out <= ram[13];
				
				8'h34:  data_out <= ram[14];
				8'h35:  data_out <= ram[15];
				8'h36:  data_out <= ram[16];
				8'h37:  data_out <= ram[17];
				
				8'h38:  data_out <= ram[18];
				8'h39:  data_out <= ram[19];
				8'h3a:  data_out <= ram[20];
				8'h3b:  data_out <= ram[21];
			endcase
		end

		write: begin
			if(res || initialization || (ram[0][0] == 1'b1)) begin
				state <= init;
			end
			case(addr)
				8'h26:  ram[0] <= data_in;
				8'h27:  ram[1] <= data_in;

				8'h28:  ram[2] <= data_in;
				8'h29:  ram[3] <= data_in;
				8'h2a:  ram[4] <= data_in;
				8'h2b:  ram[5] <= data_in;

				8'h2c:  ram[6] <= data_in;
				8'h2d:  ram[7] <= data_in;
				8'h2e:  ram[8] <= data_in;
				8'h2f:  ram[9] <= data_in;

				8'h30:  ram[10] <= data_in;
				8'h31:  ram[11] <= data_in;
				8'h32:  ram[12] <= data_in;
				8'h33:  ram[13] <= data_in;

				8'h34:  ram[14] <= data_in;
				8'h35:  ram[15] <= data_in;
				8'h36:  ram[16] <= data_in;
				8'h37:  ram[17] <= data_in;

				8'h38:  ram[18] <= data_in;
				8'h39:  ram[19] <= data_in;
				8'h3a:  ram[20] <= data_in;
				8'h3b:  ram[21] <= data_in;
			endcase
			state <= idle;
		end

		delay: begin
			if(res || initialization || (ram[0][0] == 1'b1))
				state 	<= init;
			if(sec == CLK_FREQ/1000-2) begin
				reset 	<= 1;
			end
			if(sec == CLK_FREQ/1000-1) begin
				reset 	<= 0;
				sec 		<= 0;
				secTime 	<= ram[1];
				stop 		<= 0;	
				state 	<= counter;
			end
			else begin
				sec 		<= sec + 1;
			end
		end

		counter: begin
			if(res || initialization || (ram[0][0] == 1'b1)) begin
				state 		<= init;
			end
	   	if(secTime > 0) begin
				if(sec == CLK_FREQ-1) begin
					secTime 	<= secTime - 1'b1;
					sec 		<= 0;
				end
				else begin
					sec 		<= sec + 1;
				end
			end
			else begin
				sec 	 <= 0;
				stop 	 <= 1;

				ram[2] 	<= data[0][7:0];
				ram[3] 	<= data[0][15:8];
				ram[4] 	<= data[0][23:16];
				ram[5] 	<= data[0][31:24];

				ram[6] 	<= count_time[7:0];
				ram[7] 	<= count_time[15:8];
				ram[8] 	<= count_time[23:16];
				ram[9] 	<= count_time[31:24];

				ram[10] 	<= data[1][7:0];
				ram[11] 	<= data[1][15:8];
				ram[12] 	<= data[1][23:16];
				ram[13] 	<= data[1][31:24];

				ram[14] 	<= data[2][7:0];
				ram[15] 	<= data[2][15:8];
				ram[16] 	<= data[2][23:16];
				ram[17] 	<= data[2][31:24];

				ram[18] 	<= data[3][7:0];
				ram[19] 	<= data[3][15:8];
				ram[20] 	<= data[3][23:16];
				ram[21] 	<= data[3][31:24];

				state   	<= end_counter;
			end
		end

		end_counter: begin
			if(res || initialization || (ram[0][0] == 1'b1)) begin
				state <= init;
			end
			if(sec == CLK_FREQ/100) begin
				stop 	<= 0;
				state <= idle;
			end
			else begin
				sec 	<= sec + 1;
			end
		end
	endcase
end

endmodule
