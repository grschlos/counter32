--------------------------------------------------------------------------------
--  Copyright 2016 Konstantin Shchablo
--  Copyright 2018 Ilya Butorov
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <https://www.gnu.org/licenses/>.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--      Information
-- Company: JINR PMTLab
-- Author: Ilya Butorov
-- Email: butorov.ilya@gmail.com
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity initializer is
   generic( clk_freq : integer := 50000000 );
	port(
		clk   : in  std_logic; -- 50 mHz
		--
		res   : out std_logic;
		n_res : out std_logic);
end initializer;

architecture behavior of initializer IS
	type state_type is (
		idle,
		cycle_Tdel,
		cycle_Tdel_x50k,
		--
		cycle_Tos_x50k,
		empty_cycle);

	signal state  : state_type;
	signal res_iv : std_logic;

begin
	state_process : process(clk)
		variable cnt_T   : integer range 0 to 262143;
		variable cnt_64k : integer range 0 to 262143;

	begin
		if (clk'event and clk = '0') then
			case state is
				----
				when idle =>
					res_iv <= '0';
					cnt_T  := 1;        -- 100 mSec

					state <= cycle_Tdel;
				----	
				when cycle_Tdel =>      -- 100 mSec delay
					if (cnt_T > 0) then
						cnt_T   := cnt_T - 1;
						cnt_64k := clk_freq/1000;  -- 50000 x 20 nS = 1 mSec	

						state <= cycle_Tdel_x50k;
					else
						cnt_64k := clk_freq/1000;  -- 50000 x 20 nS = 1 mSec
						res_iv  <= '1';
						state   <= cycle_Tos_x50k;
					end if;
				----
				when cycle_Tdel_x50k =>
					if (cnt_64k > 0) then
						cnt_64k := cnt_64k - 1;

						state <= cycle_Tdel_x50k;
					else
						state <= cycle_Tdel;
					end if;
				----
				when cycle_Tos_x50k =>  -- 1 mSec res pulse			
					if (cnt_64k > 0) then
						cnt_64k := cnt_64k - 1;

						state <= cycle_Tos_x50k;
					else
						res_iv <= '0';

						state <= empty_cycle;
					end if;
				-----		
				when empty_cycle =>
					state <= empty_cycle;
				-----				
				when others =>
					state <= idle;
			----
			end case;
		end if;
	end process state_process;
	--
	res   <= res_iv;
	n_res <= not (res_iv);
--
end behavior;
