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

module generic_cntr
 (
	input wire signal,
	input wire reset,
	input wire enable,
	output reg [31:0]out
);

always @ (posedge signal or posedge reset) begin
	if (reset)
		out <= 0;
	else
		out <= out + enable;
end
endmodule

module generic_cntr32
#(
	parameter N_CHN=32
 )
 (
	input wire [N_CHN-1:0]signal,
	input wire reset,
	input wire [N_CHN-1:0]enable,
	output reg [31:0]out[N_CHN-1:0]
);

genvar i;
generate
for (i=0; i<N_CHN; i++) begin : i_channel
	generic_cntr cntr_i(signal[i], reset, enable[N_CHN-1-i], out[i]);
end
endgenerate

endmodule

module counter
#(
	parameter DATA_WIDTH=8, parameter ADDR_WIDTH=134, parameter CLK_FREQ=200000000, N_CHN=32
 )
 (
	input wire clk,
	input wire [DATA_WIDTH-1:0]addr,
	input wire [DATA_WIDTH-1:0]data_in, output wire [DATA_WIDTH-1:0]data_out,
	input wire we, input wire initialization, input wire res,

	output wire [31:0]data_ex[N_CHN-1:0],

	input wire start,
	output wire stop,

	input wire [N_CHN-1:0]signal
);

(* syn_encoding = "safe" *) reg [2:0] state;

parameter init = 0, idle = 1, write = 2, counter = 3, delay = 4, end_counter = 5;
parameter start_addr = 8'h26;
parameter offset = 6;

reg [DATA_WIDTH-1:0]ram[ADDR_WIDTH-1:0];

reg [31:0]sec;
reg [31:0]data[N_CHN-1:0];
reg [7:0]secTime; // Count time, s

genvar i, j;
generate
for (i=0; i<N_CHN; i++) begin	: i_channel_count
	for (j=0; j<4; j++) begin : j_byte
		assign data_ex[i][DATA_WIDTH*(j+1)-1:DATA_WIDTH*j] = ram[offset+i*4+j];
	end
end
endgenerate

integer enable;
assign enable = {ram[5], ram[4], ram[3], ram[2]};
reg reset;

generic_cntr32 cntr(signal, reset, enable, data);
integer k, l;
always @ (posedge clk) begin 
	case(state)
		init: begin
			if(res || initialization || (ram[0][0] == 1'b1)) begin
				state <= init;
			end
			for (k=0; k<ADDR_WIDTH; k++) begin 
				ram[k]	<= 0;
			end

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

			if ((addr>start_addr-1)&&(addr<start_addr+ADDR_WIDTH)) begin
				data_out <= ram[addr-start_addr];
			end
		end

		write: begin
			if(res || initialization || (ram[0][0] == 1'b1)) begin
				state <= init;
			end
			if ((addr>start_addr-1)&&(addr<start_addr+ADDR_WIDTH)) begin
				ram[addr-start_addr] <= data_in;
			end
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
				for (k=0; k<N_CHN; k++) begin
					ram[offset+k*4] 	<= data[k][DATA_WIDTH*1-1:0];
					ram[offset+k*4+1] <= data[k][DATA_WIDTH*2-1:DATA_WIDTH*1];
					ram[offset+k*4+2] <= data[k][DATA_WIDTH*3-1:DATA_WIDTH*2];
					ram[offset+k*4+3] <= data[k][DATA_WIDTH*4-1:DATA_WIDTH*3];
				end

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
