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

module dac_7624 #(parameter CLK_FREQ=50000000)
(
 output reg READ,
 output reg nCS,
 output reg nRESET,
 output reg nLDAC,

 input wire startStep,
 output reg start_counter,

 input wire clk,
 input wire reset,
 input wire init,
 input wire write
);

(* syn_encoding = "safe" *) reg [3:0] state;
parameter INIT = 0, IDLE = 1, RESET0 = 2, RESET1 = 3, FIN0 = 4, FIN1 = 5, WRITE0 = 6, WRITE1 = 7, WRITE2 = 8, WRITE3 = 9, DLY0 = 10, DLY1 = 11;
/*parameter CLK_CYCLE = 1000000000/CLK_FREQ;
// time parameters for reading
parameter T_RCS   = 200;   // nCS LOW for Read, ns (min)
parameter T_RDS   = 10;    // READ HIGH to nCS LOW, ns (min)
parameter T_RDH   = 0;     // READ HIGH after nCS HIGH, ns (min)
parameter T_DZ    = 100;   // nCS HIGH to Data Bus in High Impedance, ns (typ)
parameter T_CSD   = 100;   // nCS LOW to Data Bus Valid, ns (typ) (160 ns max)
// time parameters for writing
parameter T_WCS   = 50;    // nCS LOW for Write, ns (min)
parameter T_WS    = 0;     // READ LOW to nCS LOW, ns (min)
parameter T_WH    = 0;     // READ LOW after nCS HIGH, ns (min)
parameter T_AS    = 0;     // Address Valid to nCS LOW, ns (min)
parameter T_AH    = 0;     // Address Valid after nCS HIGH, ns (min)
parameter T_LS    = 70;    // nLDAC LOW to nCS LOW, ns (min)
parameter T_LH    = 50;    // nLDAC LOW after nCS HIGH, ns (min)
parameter T_DS    = 0;     // Data Valid to nCS LOW, ns (min)
parameter T_DH    = 0;     // Data Valid after nCS HIGH, ns (min)
parameter T_LWD   = 50;    // nLDAC LOW, ns (min)
parameter T_RESET = 50;    // nRESET LOW, ns (min) */

integer res_count;
integer write_count;
integer start_count;

always @(posedge clk) begin
   if (init)  state <= INIT;
	if (reset) state <= RESET0;
   case (state)
	   // INIT
	   INIT: begin
			READ <= 1'b1;
			nCS <= 1'b1;
		   nRESET <= 1'b1;
			nLDAC <= 1'b1;
			state <= IDLE;
		end

	   // IDLE
	   IDLE: begin
		   if (reset) begin
			   state <= RESET0;
			end
			if (init) begin 
				state <= INIT;
			end
			if (startStep) begin
				state <= FIN0;
			end
			else begin
			   if (write) begin
			      state <= DLY0;
				end
				else begin
					state <= IDLE;
				end
			end
		end

		// FINALIZE
		FIN0: begin
			if (reset) begin
				state <= RESET0;
			end
			start_count <= 5;
			start_counter <= 1'b1;
			state <= FIN1;
		end

		FIN1: begin
			if (reset) begin
				start_counter <= 1'b0;
				state <= RESET0;
			end
			if (start_count > 0) begin
				start_count <= start_count - 1;
			end
			else begin
				start_counter <= 1'b0;
				state <= IDLE;
			end
		end

		// RESET
		RESET0: begin
			nRESET <= 1'b0;
		   res_count <= 3;
			state <= RESET1;
		end

		RESET1: begin
		   if (res_count > 0) begin
				res_count <= res_count - 1;
			end
			else begin
			   state <= INIT;
			end
		end

		// READ
		/*
		READ0: begin
		   read_count <= 1;
			state <= READ1;
		end

		READ1: begin
		   if (read_count>0) begin
				read_count <= read_count - 1;
			end
			else begin
				write_count <= 10;
				nCS <= 1'b0;
			   state <= READ2;
			end
		end

		READ2: begin
			if (read_count>0) begin
				read_count <= read_count - 1;
			end
			else begin
				nCS <= 1'b1;
				state <= IDLE;
			end
		end */

		// DELAY
		DLY0: begin
			if (reset) begin
				state <= RESET0;
			end
			write_count <= 10;
			state <= DLY1;
		end

		DLY1: begin
			if (reset) begin
				state <= RESET0;
			end
			if (write_count>0) begin
				write_count <= write_count - 1;
			end
			else begin
				state <= WRITE0;
			end
		end

		// WRITE
		WRITE0: begin
			if (reset) begin
			   state <= RESET0;
			end
			READ <= 1'b0;
			nLDAC <= 1'b0;
			write_count <= 3;
			state <= WRITE1;
		end

		WRITE1: begin
			if (reset) begin
			   state <= RESET0;
			end
		   if (write_count>0) begin
				write_count <= write_count - 1;
			end
			else begin
			   write_count <= 3;
				nCS <= 1'b0;
			   state <= WRITE2;
			end
		end

		WRITE2: begin
			if (reset) begin
			   state <= RESET0;
			end
			if (write_count>0) begin
				write_count <= write_count - 1;
			end
			else begin
				write_count <= 4;
				nCS <= 1'b1;
				state <= WRITE3;
			end
		end

		WRITE3: begin
			if (reset) begin
			   state <= RESET0;
			end
			if (write_count>0) begin
				write_count <= write_count - 1;
			end
			else begin
				nLDAC <= 1'b1;
				READ <= 1'b1;
				if (startStep) begin
					state <= FIN0;
				end
				else begin
					state <= IDLE;
				end
			end
		end

		default: begin
		   state <= IDLE;
		end
	endcase
end

endmodule
