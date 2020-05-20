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

module multiChannelCounter(

	input clock50Mhz,

	input key_restart,

	output SCK,
	output nCS,
	output nLDAC,
	output SDI,

	output wire  out_port_from_the_LAN_RST,
	output wire  out_port_from_the_LAN_CS, 
	input  wire  MISO_to_the_LAN,          
	output wire  MOSI_from_the_LAN,
	output wire  SCLK_from_the_LAN,        
	input  wire  in_port_to_the_LAN_NINT,  

	input [31:0]count,
	output t_clk
  );

localparam FRQ=50000000;
wire clk;

// Instantiation initializer. Signals and registers are declared.
wire init;
wire reset;
assign clk=clock50Mhz;
initializer#(.clk_freq(FRQ)) initializer_inst
(
	clk,
	init
);

wire [7:0]data_in;

// Instantiation vjtag. Signals and registers are declared.
/*wire [7:0]data_vjtag_out;
wire [7:0]address_vjtag;
wire addr_write_vjtag;
wire write_vjtag;
wire addr_read_vjtag;
vjtag vjtag_inst_interface
(
	init,
	data_in, 
	data_vjtag_out, 
	address_vjtag,
	write_vjtag,
	addr_write_vjtag
); */

// Instantiation eth. Signals and registers are declared.
wire [31:0]time_export;
wire [31:0]signals_export[31:0];

wire [7:0]addr_export;

wire [7:0]wdata_export;
wire swrite_export;
wire sread_export; 

wire cread_export;          
wire addr_write_export;

wire startStep_export;
wire stopStep_export;

wire swrite32_export;
wire [31:0]wdata32_export;
wire [31:0]rdata32_export;

eth_top eth_inst
(
	key_restart,
	out_port_from_the_LAN_RST,
	out_port_from_the_LAN_CS,
	MISO_to_the_LAN,
	MOSI_from_the_LAN,
	SCLK_from_the_LAN,
	clk,		// clock50Mhz
	in_port_to_the_LAN_NINT,

	signals_export[0],
	signals_export[1],
	signals_export[2],
	signals_export[3],
	signals_export[4],
	signals_export[5],
	signals_export[6],
	signals_export[7],
	signals_export[8],
	signals_export[9],
	signals_export[10],
	signals_export[11],
	signals_export[12],
	signals_export[13],
	signals_export[14],
	signals_export[15],
	signals_export[16],
	signals_export[17],
	signals_export[18],
	signals_export[19],
	signals_export[20],
	signals_export[21],
	signals_export[22],
	signals_export[23],
	signals_export[24],
	signals_export[25],
	signals_export[26],
	signals_export[27],
	signals_export[28],
	signals_export[29],
	signals_export[30],
	signals_export[31],

	addr_export,
	data_in, 		// output data (from FPGA)
	wdata_export, 	// input data (from NIOS II)

	swrite_export,
	sread_export,
	cread_export,
	addr_write_export,

	startStep_export,
	stopStep_export,

	swrite32_export,
	wdata32_export,
	rdata32_export
);

// Instantiation command. Signals and registers are declared.
wire write;
wire write32;
wire [7:0]data;
wire [31:0]data32;
wire [7:0]addr;
command#(.CLK_FREQ(FRQ)) command_inst
(
	clk, key_restart, //clock200Mhz
	init, reset,

	addr_write_vjtag,
	address_vjtag,

	addr_write_export,
	addr_export,

	addr,

	write_vjtag,
	swrite_export,
	swrite32_export,

	write,
	write32,

	wdata_export,
	data_vjtag_out,
	wdata32_export,

	data,
	data32
);	

// Instantiation counter. Signals and registers are declared.
wire [7:0]data_counter;
wire start_counter;
reg [31:0]in_cnt;
genvar i;
generate
for (i=0; i<32; i++) begin	: i_channel_count
	assign in_cnt[i] = count[i];
end
endgenerate
assign t_clk = clk;

counter#(.CLK_FREQ(FRQ)) counter_inst
(
	clk,
	addr,
	data, data_counter,
	write, init, reset,

	signals_export,

	start_counter,
	stopStep_export,

	in_cnt//count
);
  
// Instantiation DAC. Signals and registers declared.
wire [7:0]data_DAC;
spidac dac_inst
(
 clk,
 init, reset,
 write, addr,
 data,
 data_DAC,
 
 write32,
 data32,
 
 SCK,
 nCS,
 nLDAC,
 SDI,
 
 startStep_export,
 start_counter
);


reg [7:0]version;
assign version[7:0] = 8'b00010000;

// Instantiation selector. Signals and registers declared.
selector selector_data_vjtag_in(
 addr,
 data_counter,
 version,
 data_DAC,
 
 data_in
);

endmodule
