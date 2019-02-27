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
-- Description: filter rns supervisor
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity filter_rns_supervisor is
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
      
      rns_cnt : out std_logic_vector(31 downto 0);
      reset_cnt : in std_logic
	 );
end filter_rns_supervisor;
      
architecture ax309 of filter_rns_supervisor is
	component filter_3x3_rns is
    Port ( 
		clk   : in STD_LOGIC;
      ask   : in std_logic;
      ready : out std_logic;
      k1,k2,k3,k4,k5,k6,k7,k8,k9 : in std_logic_vector(15 downto 0);
      pow2_div : in std_logic_vector(7 downto 0);
      p1,p2,p3,p4,p5,p6,p7,p8,p9	: in std_logic_vector(15 downto 0);
      res   : out std_logic_vector(7 downto 0)
		);
	end component;

   component bss_8bit_rns_7_15_31_16 is
	port (
		clk: in std_logic;
      ask: in std_logic;
      ready: out std_logic;
      a_dop: in std_logic;
		a: in std_logic_vector(7 downto 0);
		res_7: out std_logic_vector(2 downto 0);
      res_15: out std_logic_vector(3 downto 0);
      res_31: out std_logic_vector(4 downto 0);
      res_16: out std_logic_vector(3 downto 0)
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
     
   signal k1_rns,k2_rns,k3_rns,k4_rns,k5_rns,k6_rns,k7_rns,k8_rns,k9_rns: std_logic_vector(15 downto 0) := (others => '0');
   signal k1_rns_ask,k2_rns_ask,k3_rns_ask,k4_rns_ask,k5_rns_ask,k6_rns_ask,k7_rns_ask,k8_rns_ask,k9_rns_ask: std_logic:='0';
   signal k1_rns_ready,k2_rns_ready,k3_rns_ready,k4_rns_ready,k5_rns_ready,k6_rns_ready,k7_rns_ready,k8_rns_ready,k9_rns_ready: std_logic:='0';
   
   signal p1_rns,p2_rns,p3_rns,p4_rns,p5_rns,p6_rns,p7_rns,p8_rns,p9_rns: std_logic_vector(15 downto 0) := (others => '0');

   signal p_bss: std_logic_vector(15 downto 0) := (others => '0');
   signal p_rns: std_logic_vector(15 downto 0) := (others => '0');
   signal p_bss_rns_ask, p_bss_rns_ready: std_logic := '0';
   
   signal filter_rns_ask, filter_rns_ready: std_logic := '0';
   signal filter_rns_res: std_logic_vector(7 downto 0) := (others=>'0');

   signal cnt : std_logic_vector(31 downto 0) := (others => '0');   
begin
   rns_cnt<=cnt;
------------------------------------------------------------------------------------------

   k1_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k1_rns_ask, k1_rns_ready, '1', k1,
      k1_rns(2 downto 0), k1_rns(6 downto 3), k1_rns(11 downto 7), k1_rns(15 downto 12)
   );

   k2_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k2_rns_ask, k2_rns_ready, '1', k2,
      k2_rns(2 downto 0), k2_rns(6 downto 3), k2_rns(11 downto 7), k2_rns(15 downto 12)
   );

   k3_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k3_rns_ask, k3_rns_ready, '1', k3,
      k3_rns(2 downto 0), k3_rns(6 downto 3), k3_rns(11 downto 7), k3_rns(15 downto 12)
   );

   k4_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k4_rns_ask, k4_rns_ready, '1', k4,
      k4_rns(2 downto 0), k4_rns(6 downto 3), k4_rns(11 downto 7), k4_rns(15 downto 12)
   );

   k5_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k5_rns_ask, k5_rns_ready, '1', k5,
      k5_rns(2 downto 0), k5_rns(6 downto 3), k5_rns(11 downto 7), k5_rns(15 downto 12)
   );

   k6_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k6_rns_ask, k6_rns_ready, '1', k6,
      k6_rns(2 downto 0), k6_rns(6 downto 3), k6_rns(11 downto 7), k6_rns(15 downto 12)
   );

   k7_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k7_rns_ask, k7_rns_ready, '1', k7,
      k7_rns(2 downto 0), k7_rns(6 downto 3), k7_rns(11 downto 7), k7_rns(15 downto 12)
   );

   k8_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k8_rns_ask, k8_rns_ready, '1', k8,
      k8_rns(2 downto 0), k8_rns(6 downto 3), k8_rns(11 downto 7), k8_rns(15 downto 12)
   );

   k9_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, k9_rns_ask, k9_rns_ready, '1', k9,
      k9_rns(2 downto 0), k9_rns(6 downto 3), k9_rns(11 downto 7), k9_rns(15 downto 12)
   );
------------------------------------------------------------------------------------------

   p_bss8_rns_chip: bss_8bit_rns_7_15_31_16 port map (
      clk, p_bss_rns_ask, p_bss_rns_ready, '0', p_bss(7 downto 0),
      p_rns(2 downto 0),p_rns(6 downto 3),p_rns(11 downto 7),p_rns(15 downto 12) 
   );
------------------------------------------------------------------------------------------

	filter_rns_chip: filter_3x3_rns
	PORT MAP (clk, filter_rns_ask, filter_rns_ready,
      k1_rns,k2_rns,k3_rns,k4_rns,k5_rns,k6_rns,k7_rns,k8_rns,k9_rns, pow2_div,
      p1_rns,p2_rns,p3_rns,p4_rns,p5_rns,p6_rns,p7_rns,p8_rns,p9_rns,
      filter_rns_res);

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
      filter_rns_ask<='0'; mem_ask<='0'; mem_wr_en<='0'; ready<='0';
      k1_rns_ask<='0'; k2_rns_ask<='0'; k3_rns_ask<='0';
      k4_rns_ask<='0'; k5_rns_ask<='0'; k6_rns_ask<='0';
      k7_rns_ask<='0'; k8_rns_ask<='0'; k9_rns_ask<='0';
      if (ask='1')and(mem_ready='0')and(filter_rns_ready='0')and
         (k1_rns_ready='0')and(k2_rns_ready='0')and(k3_rns_ready='0')and
         (k4_rns_ready='0')and(k5_rns_ready='0')and(k6_rns_ready='0')and
         (k7_rns_ready='0')and(k8_rns_ready='0')and(k9_rns_ready='0')
      then fsm:=1; end if;

  -- for y=task_ymin to task_ymax
   when 1=>
      y:=task_ymin;
      k1_rns_ask<='1'; k2_rns_ask<='1'; k3_rns_ask<='1';
      k4_rns_ask<='1'; k5_rns_ask<='1'; k6_rns_ask<='1';
      k7_rns_ask<='1'; k8_rns_ask<='1'; k9_rns_ask<='1';
      if (k1_rns_ready='1')and(k2_rns_ready='1')and(k3_rns_ready='1')and
         (k4_rns_ready='1')and(k5_rns_ready='1')and(k6_rns_ready='1')and
         (k7_rns_ready='1')and(k8_rns_ready='1')and(k9_rns_ready='1')
      then fsm:=2; end if;

   --for x=task_xmin to task_xmax
   when 2=> x:=task_xmin; fsm:=3;
   --load p9 pixel from sdram to scanline
   when 3=>
      p_bss_rns_ask<='0';
      mem_addr<=page_src & (y+1) & (x+1);
      mem_wr_en<='0';
      wea0(0)<='0'; wea1(0)<='0'; wea2(0)<='0';
      if (mem_ready='0')and(p_bss_rns_ready='0') then mem_ask<='1'; wr_addr<=x+1; fsm:=4; end if;
   when 4=>
      if mem_ready='1' then
         p_bss<=mem_rd_data;
         p_bss_rns_ask<='1';
         if p_bss_rns_ready='1' then
            case active_line is
            when "00" => wea1(0)<='1';
            when "01" => wea2(0)<='1';
            when "10" => wea0(0)<='1';
            when others => null;
            end case;
            wr_data<=p_rns;
            fsm:=5;
         end if;
         mem_ask<='0';
      end if;
   when 5=>
      wea0(0)<='0'; wea1(0)<='0'; wea2(0)<='0';
      rd_addr<=x+1; fsm:=6;
      
   -- shift pixels mask to left
   when 6 => p1_rns<=p2_rns; p4_rns<=p5_rns; p7_rns<=p8_rns; fsm:=7;
   when 7 => p2_rns<=p3_rns; p5_rns<=p6_rns; p8_rns<=p9_rns; fsm:=8;

   -- load p3,p6,p9 pixels from scanlines
   when 8=>
      case active_line is
      when "00" => p3_rns<=rd2_data; p6_rns<=rd0_data; p9_rns<=rd1_data;
      when "01" => p3_rns<=rd0_data; p6_rns<=rd1_data; p9_rns<=rd2_data;
      when "10" => p3_rns<=rd1_data; p6_rns<=rd2_data; p9_rns<=rd0_data;
      when others => null;
      end case;
      fsm:=9;

   -- filtering process
   when 9=>  if filter_rns_ready='0' then filter_rns_ask<='1'; fsm:=10; end if;
   when 10=> if filter_rns_ready='1' then filter_rns_ask<='0'; fsm:=11; end if;

   -- write filter_res to sdram
   when 11=> 
      mem_addr<=page_dst & y & x;
      mem_wr_data(15 downto 8)<=(others=>'0');
      mem_wr_data(7 downto 0)<=filter_rns_res;
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
