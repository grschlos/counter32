//------------------------------------------------------------------------------
// Copyright [2016] [Shchablo Konstantin]
//
// Licensed under the Apache License, Version 2.0 (the "License"); 
// you may not use this file except in compliance with the License. 
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, 
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. 
// See the License for the specific language governing permissions and
// limitations under the License.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Information.
// Company: JINR PMTLab
// Author: Shchablo Konstantin
// Email: ShchabloKV@gmail.com
// Tel: 8-906-796-76-53 (russia)
//-------------------------------------------------------------------------------

module spidac
#(
	parameter DATA_WIDTH=8, parameter ADDR_WIDTH=5 
 )
(
 input wire clk,
 input wire init, input wire res,
 input wire we, input wire [DATA_WIDTH-1:0]addr,
 input wire [DATA_WIDTH-1:0]data_in,
 output wire [DATA_WIDTH-1:0]data_out,

 input wire we32,
 input wire [31:0]data_in32,

 output reg SCK,
 output reg nCS,
 output reg nLDAC,
 output reg SDI,

 input wire start_step,
 output reg start_counter
);

wire clk_40Mhz;
reg [DATA_WIDTH-1:0]ram[ADDR_WIDTH-1:0];

wire [15:0]data;

assign data[7:0] = ram[1];
assign data[15:8] = ram[2];

always @ (posedge clk) begin 

	if(res) begin
		ram[0] <= 8'b00000000;
		ram[1] <= 8'hFF;
		ram[2] <= 8'h0F;
	end

// initialization
	if(init) begin
		ram[0] <= 8'b00000000;
		//ram[1] <= 8'h64;
		//ram[2] <= 8'h00;
		ram[1] <= 8'hFF;
		ram[2] <= 8'h0F;
	end

  // write memory	
	if(we) begin
		case(addr)
			8'h02:  ram[3] <= data_in;
			8'h03:  ram[4] <= data_in;

			8'h04:  ram[0] <= data_in;
			8'h05:  ram[1] <= data_in;
			8'h06:  ram[2] <= data_in;
		endcase
	end

	if(we32) begin
		if(addr == 8'h07) begin
			ram[1] <= data_in32[7:0];
			ram[2] <= data_in32[15:8];		
	  	end
	end

	// read memory  			
	case(addr)
		8'h02: 	data_out <= ram[3];
		8'h03:   data_out <= ram[4];
		8'h04:	data_out <= ram[0];
		8'h05:   data_out <= ram[1];
		8'h06:   data_out <= ram[2];
	endcase

	// Command: Reset 
	if(ram[0] == 8'b00000001 || res) begin
		ram[0] <= 0;
		ram[1] <= 8'hFF;
		ram[2] <= 8'h0F;
	end
end

altpll_m4_d5 altpll_m4_d5_inst
(
	clk,
	clk_40Mhz
);
// Instantiation SPIDAC_MASTER_MCP4921. Signals and registers declared.	
SPIDAC_MASTER_MCP4921 SPIDAC_MASTER_MCP4921_inst
	(
		clk_40Mhz,
		data[11:0],
		start_step,
		
		SCK, 
		nCS,
		nLDAC,
		SDI,
		
		start_counter,
		
		res
	);

endmodule