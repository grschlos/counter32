//------------------------------------------------------------------------------
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
// Author: Ilya Butorov
// Email: butorov.ilya@gmail.com
//------------------------------------------------------------------------------

module dac
#(
	parameter DATA_WIDTH=8, parameter ADDR_WIDTH=11
 )
(
 input wire clk,
 input wire init, input wire res,
 input wire we, input wire [DATA_WIDTH-1:0]addr,
 input wire [DATA_WIDTH-1:0]data_in,
 output wire [DATA_WIDTH-1:0]data_out,

 input wire we32,
 input wire [31:0]data_in32,

 output reg READ,
 output reg nCS,
 output reg nRESET,
 output reg nLDAC,
 output wire [1:0]ch,
 output wire [11:0]data,

 input wire startStep,
 output reg start_counter
);

reg [DATA_WIDTH-1:0]ram[ADDR_WIDTH-1:0];
wire [3:0]mask;
assign data[7:0]  = ram[1];
assign data[11:8] = ram[2][3:0];
assign mask = ram[2][7:4];
wire reset;
assign reset = res || ram[0][0];

always @(posedge clk) begin 
	if(reset) begin
		ram[0] <= 8'b00000000;
		ram[1] <= 8'b00000000;
		ram[2] <= 8'b10001000;
	end

	// initialization
	if(init) begin
		ram[0] <= 8'b00000000;
		ram[1] <= 8'b00000000;
		ram[2] <= 8'b10001000;
	end

	// write memory
	if(we) begin
		case(addr)
			8'h02:  ram[3] <= data_in;
			8'h03:  ram[4] <= data_in;
			8'h04:  ram[5] <= data_in;
			8'h05:  ram[6] <= data_in;
			8'h06:  ram[7] <= data_in;
			8'h07:  ram[8] <= data_in;
			8'h08:  ram[9] <= data_in;
			8'h09:  ram[10] <= data_in;
			8'h0a:  ram[0] <= data_in;
			8'h0b:  ram[1] <= data_in;
			8'h0c: begin
				ram[2] <= data_in;
				case(mask)
					4'b1000: ch <= 2'b00;
					4'b0100: ch <= 2'b01;
					4'b0010: ch <= 2'b11;
					4'b0001: ch <= 2'b10;
					default: ch <= 2'b00;
				endcase
			end
		endcase
	end

	if(we32) begin
		if(addr == 8'h0d) begin
			ram[1] <= data_in32[7:0];
			ram[2] <= data_in32[15:8];
			case(mask)
				4'b1000: ch <= 2'b00;
				4'b0100: ch <= 2'b01;
				4'b0010: ch <= 2'b11;
				4'b0001: ch <= 2'b10;
				default: ch <= 2'b00;
			endcase
	  	end
	end

	// read memory
	case(addr)
		8'h02: 	data_out <= ram[3];
		8'h03:   data_out <= ram[4];
		8'h04: 	data_out <= ram[5];
		8'h05:   data_out <= ram[6];
		8'h06: 	data_out <= ram[7];
		8'h07:   data_out <= ram[8];
		8'h08: 	data_out <= ram[9];
		8'h09:   data_out <= ram[10];
		8'h0a:	data_out <= ram[0];
		8'h0b:   data_out <= ram[1];
		8'h0c:   data_out <= ram[2];
		8'h0d:   data_out <= ram[1];
		8'h0e:	data_out <= ram[2];
	endcase

	// Command: Reset
	if(reset) begin
		ram[0] <= 0;
		ram[1] <= 0;
		ram[2] <= 8'b10001000;
	end
end

// Instantiation dac_7624. Signals and registers are declared.
dac_7624 #(.CLK_FREQ(50000000)) dac_7624_inst
(
	READ,
	nCS,
	nRESET,
	nLDAC,

	startStep,
	start_counter,

	clk,
	reset,
	init,
	we
);

endmodule
