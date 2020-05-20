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

module selector(
 input [7:0]addr,
 input [7:0]counter,
 input [7:0]version,
 input [7:0]dac,
 output reg [7:0]data
);

always @*
begin
	if (addr==0) begin
		data = version;
	end
	else if ((addr>=8'h02)&&(addr<=8'h06)) begin 
		data = dac;
	end
	else if ((addr>=8'h26)&&(addr<=8'hac)) begin
		data = counter;
	end
	else begin 
		data = 0;
	end
end

endmodule
