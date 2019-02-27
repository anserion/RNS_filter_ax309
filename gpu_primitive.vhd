------------------------------------------------------------------
--Copyright 2019 Andrey S. Ionisyan (anserion@gmail.com)
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--    http://www.apache.org/licenses/LICENSE-2.0
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Engineer: Andrey S. Ionisyan <anserion@gmail.com>
-- 
-- Description: typical video operations filter's design (COPY and ROTATE video pages)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity gpu_primitive_module is
    Port ( 
		clk        : in std_logic;
      ask        : in std_logic;
      ready      : out std_logic;      
      
      hscanline_rd_ask: out std_logic;
      hscanline_rd_ready: in std_logic;
      hscanline_rd_x: out std_logic_vector(9 downto 0);
      hscanline_rd_y: out std_logic_vector(9 downto 0);
      hscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      hscanline_wr_ask: out std_logic;
      hscanline_wr_ready: in std_logic;
      hscanline_wr_x: out std_logic_vector(9 downto 0);
      hscanline_wr_y: out std_logic_vector(9 downto 0);
      hscanline_wr_pixel: out std_logic_vector(15 downto 0);

      vscanline_rd_ask: out std_logic;
      vscanline_rd_ready: in std_logic;
      vscanline_rd_x: out std_logic_vector(9 downto 0);
      vscanline_rd_y: out std_logic_vector(9 downto 0);
      vscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      vscanline_wr_ask: out std_logic;
      vscanline_wr_ready: in std_logic;
      vscanline_wr_x: out std_logic_vector(9 downto 0);
      vscanline_wr_y: out std_logic_vector(9 downto 0);
      vscanline_wr_pixel: out std_logic_vector(15 downto 0);
      
      -- 000 - clear copy, 001 - CCW rotate, 010 - CW rotate
      task_code: in std_logic_vector(2 downto 0);
      
      task_xmin: in std_logic_vector(9 downto 0);
      task_ymin: in std_logic_vector(9 downto 0);
      task_xmax: in std_logic_vector(9 downto 0);
      task_ymax: in std_logic_vector(9 downto 0)
	 );
end gpu_primitive_module;

architecture ax309 of gpu_primitive_module is
   constant task_COPY: std_logic_vector(2 downto 0):="000";
   constant task_CCW: std_logic_vector(2 downto 0):="001";
   constant task_CW: std_logic_vector(2 downto 0):="010";
   
begin
   process(clk)
   variable fsm: natural range 0 to 255 := 0;
   variable x,y: std_logic_vector(9 downto 0):=(others=>'0');
--   variable pixel: std_logic_vector(15 downto 0):=(others=>'0');
  
   begin
   if rising_edge(clk) then
   case fsm is
   --idle
   when 0=> 
      hscanline_rd_ask<='0'; hscanline_wr_ask<='0';
      vscanline_rd_ask<='0'; vscanline_wr_ask<='0';
      ready<='0';
      if (ask='1')and
         (hscanline_rd_ready='0')and(hscanline_wr_ready='0')and
         (vscanline_rd_ready='0')and(vscanline_wr_ready='0')
      then fsm:=1;
      end if;

   -- for y=task_ymin to task_ymax
   when 1=> y:=task_ymin; fsm:=2;
   
   --read hscanline(y) from sdram
   when 2=>
      hscanline_rd_y<=y;
      if hscanline_rd_ready='0' then hscanline_rd_ask<='1'; fsm:=3; end if;
   when 3=> if hscanline_rd_ready='1' then hscanline_rd_ask<='0'; fsm:=4; end if;
   
   -- check for a COPY filter mode
   when 4=> if task_code=task_COPY then x:=task_xmin; fsm:=5; else fsm:=8; end if;
   when 5=> hscanline_rd_x<=x; fsm:=6;
   when 6=>
      hscanline_wr_x<=x;
      hscanline_wr_pixel<=hscanline_rd_pixel;
      fsm:=7;
   when 7=> if x=task_xmax then fsm:=250; else x:=x+1; fsm:=5; end if;
   
   -- check for a CCW filter mode
   when 8=> if task_code=task_CCW then x:=task_xmax; fsm:=9; else fsm:=12; end if;
   when 9=> hscanline_rd_x<=x; fsm:=10;
   when 10=>
      vscanline_wr_y<=task_xmax-x;
      vscanline_wr_pixel<=hscanline_rd_pixel;
      fsm:=11;
   when 11=> if x=task_xmin then x:=y; fsm:=252; else x:=x-1; fsm:=9; end if;

   -- check for a CW filter mode
   when 12=> if task_code=task_CW then x:=task_xmin; fsm:=13; else fsm:=254; end if;
   when 13=> hscanline_rd_x<=x; fsm:=14;
   when 14=>
      vscanline_wr_y<=x;
      vscanline_wr_pixel<=hscanline_rd_pixel;
      fsm:=15;
   when 15=> if x=task_xmax then x:=task_xmax-y; fsm:=252; else x:=x+1; fsm:=13; end if;
   
   --------------------------------------------------------------------------------
   -- some usefull subroutines
   --------------------------------------------------------------------------------
   -- write hscanline(y) to SDRAM
   when 250=>
      hscanline_wr_y<=y;
      if hscanline_wr_ready='0' then hscanline_wr_ask<='1'; fsm:=251; end if;
   when 251=> if hscanline_wr_ready='1' then hscanline_wr_ask<='0'; fsm:=254; end if;

   -- write vscanline(x) to SDRAM
   when 252=>
      vscanline_wr_x<=x;
      if vscanline_wr_ready='0' then vscanline_wr_ask<='1'; fsm:=253; end if;
   when 253=> if vscanline_wr_ready='1' then vscanline_wr_ask<='0'; fsm:=254; end if;
   --------------------------------------------------------------------------------
   
   -- end of y loop
   when 254=> if y=task_ymax then fsm:=255; else y:=y+1; fsm:=2; end if;
   
   -- next idle
   when 255=>
      ready<='1';
      if ask='0' then fsm:=0; end if;
   when others=>null;
   end case;
   end if;
   end process;
end ax309;
