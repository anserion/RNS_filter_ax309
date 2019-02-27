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
-- Description: filter bss supervisor
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity filter_bss_supervisor is
    Port ( 
		clk        : in std_logic;
      ask        : in std_logic;
      ready      : out std_logic;

      mem_ask: out std_logic;
      mem_ready: in std_logic;
      mem_wr_en: out std_logic;
      mem_addr : out std_logic_vector(23 downto 0);
      mem_rd_data: in std_logic_vector(15 downto 0);
      mem_wr_data: out std_logic_vector(15 downto 0);

      k1,k2,k3,k4,k5,k6,k7,k8,k9 : in std_logic_vector(7 downto 0);
      pow2_div : in std_logic_vector(7 downto 0);
      
      task_xmin: in std_logic_vector(9 downto 0);
      task_ymin: in std_logic_vector(9 downto 0);
      task_xmax: in std_logic_vector(9 downto 0);
      task_ymax: in std_logic_vector(9 downto 0);
      
      page_src : in std_logic_vector(3 downto 0);
      page_dst : in std_logic_vector(3 downto 0);
      
      bss_cnt : out std_logic_vector(31 downto 0);
      reset_cnt : in std_logic
	 );
end filter_bss_supervisor;
      
architecture ax309 of filter_bss_supervisor is
	component filter_3x3_bss is
    Port ( 
		clk   : in STD_LOGIC;
      ask   : in std_logic;
      ready : out std_logic;
      k1,k2,k3,k4,k5,k6,k7,k8,k9 : in std_logic_vector(7 downto 0);
      pow2_div : in std_logic_vector(7 downto 0);
      p1,p2,p3,p4,p5,p6,p7,p8,p9	: in std_logic_vector(7 downto 0);
      res   : out std_logic_vector(7 downto 0)
		);
	end component;

   COMPONENT vram_scanline
   PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
   );
   END COMPONENT;

   ----------------------------------------
   signal wea0,wea1,wea2: std_logic_vector(0 downto 0):=(others=>'0');
   signal wr_addr,rd_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal rd0_data,rd1_data,rd2_data: std_logic_vector(15 downto 0):=(others=>'0');
   
   signal p1,p2,p3,p4,p5,p6,p7,p8,p9: std_logic_vector(7 downto 0) := (others => '0');

   signal filter_bss_ask, filter_bss_ready: std_logic := '0';
   signal filter_bss_res: std_logic_vector(7 downto 0) := (others=>'0');

   signal cnt : std_logic_vector(31 downto 0) := (others => '0');   
begin
   bss_cnt<=cnt;
   
	filter_bss_chip: filter_3x3_bss
	PORT MAP (clk, filter_bss_ask, filter_bss_ready,
      k1,k2,k3,k4,k5,k6,k7,k8,k9, pow2_div,
      p1,p2,p3,p4,p5,p6,p7,p8,p9,
      filter_bss_res);

   scanline0: vram_scanline PORT MAP (clk,wea0,wr_addr,wr_data,clk,rd_addr,rd0_data);
   scanline1: vram_scanline PORT MAP (clk,wea1,wr_addr,wr_data,clk,rd_addr,rd1_data);
   scanline2: vram_scanline PORT MAP (clk,wea2,wr_addr,wr_data,clk,rd_addr,rd2_data);
   
   process(clk)
   variable fsm: integer range 0 to 31 := 0;
   variable x,y: std_logic_vector(9 downto 0):=(others=>'0');
   variable upper_line: std_logic_vector(1 downto 0):="00";
   variable active_line: std_logic_vector(1 downto 0):="01";
   variable lower_line: std_logic_vector(1 downto 0):="10";
   variable tmp_line_code: std_logic_vector(1 downto 0):="00";
   begin
   if rising_edge(clk) then
   case fsm is
   --idle
   when 0=> 
      filter_bss_ask<='0'; mem_ask<='0'; mem_wr_en<='0'; ready<='0';
      if (ask='1')and(mem_ready='0')and(filter_bss_ready='0') then fsm:=1; end if;

  -- for y=task_ymin to task_ymax
   when 1=> y:=task_ymin; fsm:=2;

   --for x=task_xmin to task_xmax
   when 2=> x:=task_xmin; fsm:=3;
   --load p9 pixel from sdram to scanline
   when 3=>
      mem_addr<=page_src & (y+1) & (x+1);
      mem_wr_en<='0';
      wea0(0)<='0'; wea1(0)<='0'; wea2(0)<='0';
      if mem_ready='0' then mem_ask<='1'; wr_addr<=x+1; fsm:=4; end if;
   when 4=>
      if mem_ready='1' then
         case active_line is
         when "00" => wea1(0)<='1';
         when "01" => wea2(0)<='1';
         when "10" => wea0(0)<='1';
         when others => null;
         end case;
         wr_data<=mem_rd_data;
         mem_ask<='0';
         fsm:=5;
      end if;
   when 5=>
      wea0(0)<='0'; wea1(0)<='0'; wea2(0)<='0';
      rd_addr<=x+1; fsm:=6;
      
   -- shift pixels mask to left
   when 6 => p1<=p2; p4<=p5; p7<=p8; fsm:=7;
   when 7 => p2<=p3; p5<=p6; p8<=p9; fsm:=8;

   -- load p3,p6,p9 pixels from scanlines
   when 8=>
      case active_line is
      when "00" => p3<=rd2_data(7 downto 0); p6<=rd0_data(7 downto 0); p9<=rd1_data(7 downto 0);
      when "01" => p3<=rd0_data(7 downto 0); p6<=rd1_data(7 downto 0); p9<=rd2_data(7 downto 0);
      when "10" => p3<=rd1_data(7 downto 0); p6<=rd2_data(7 downto 0); p9<=rd0_data(7 downto 0);
      when others => null;
      end case;
      fsm:=9;

   -- filtering process
   when 9=>  if filter_bss_ready='0' then filter_bss_ask<='1'; fsm:=10; end if;
   when 10=> if filter_bss_ready='1' then filter_bss_ask<='0'; fsm:=11; end if;

   -- write filter_res to sdram
   when 11=> 
      mem_addr<=page_dst & y & x;
      mem_wr_data(15 downto 8)<=(others=>'0');
      mem_wr_data(7 downto 0)<=filter_bss_res;
      if mem_ready='0' then mem_ask<='1'; mem_wr_en<='1'; fsm:=12; end if;
   when 12=> if mem_ready='1' then mem_wr_en<='0'; mem_ask<='0'; fsm:=13; end if;
   
   -- next x
   when 13=>
      if reset_cnt='0' then cnt<=cnt+1; else cnt<=(others=>'0'); end if;
      if x=task_xmax then fsm:=14; else x:=x+1; fsm:=3; end if;

   -- next y
   when 14=> 
      if y=task_ymax
      then fsm:=31;
      else y:=y+1; tmp_line_code:=upper_line; fsm:=15;
      end if;

   --recombination scanlines
   when 15=> upper_line:=active_line; fsm:=16;
   when 16=> active_line:=lower_line; fsm:=17;
   when 17=> lower_line:=tmp_line_code; fsm:=2;

   -- next idle
   when 31=>
      ready<='1';
      if ask='0' then fsm:=0; end if;
   when others=> null;
   end case;
   end if;
   end process;
end ax309;
