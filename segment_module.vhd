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
-- Description: multiple filter's design
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity segment_module is
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
      
      contrast   : in std_logic_vector(7 downto 0);
      pixels_num : in std_logic_vector(31 downto 0);
      task_xmin: in std_logic_vector(9 downto 0);
      task_ymin: in std_logic_vector(9 downto 0);
      task_xmax: in std_logic_vector(9 downto 0);
      task_ymax: in std_logic_vector(9 downto 0)
      );
end segment_module;

architecture ax309 of segment_module is
   COMPONENT ram_16kw
   PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
   );
   END COMPONENT;
   signal ram16_wea: std_logic_vector(0 downto 0):=(others=>'0');
   signal ram16_addr: std_logic_vector(13 downto 0):=(others=>'0');
   signal ram16_rd_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal ram16_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
  
   component rnd16_module is
   Generic (seed:STD_LOGIC_VECTOR(31 downto 0));
   Port (clk: in  STD_LOGIC; rnd16: out STD_LOGIC_VECTOR(15 downto 0) );
   end component;
   signal rnd16: std_logic_vector(15 downto 0):=(others=>'0');
   signal noise_level_17bit:std_logic_vector(16 downto 0):=conv_std_logic_vector(10000,17);
   
   signal rd_page_src: std_logic_vector(3 downto 0):="0010";
   signal rd_page_mid: std_logic_vector(3 downto 0):="0011";
   signal wr_page_mid: std_logic_vector(3 downto 0):="0011";
   signal wr_page_out: std_logic_vector(3 downto 0):="0100";
   
   type pixel_array_type is array (0 to 24) of std_logic_vector(15 downto 0);
	signal p,p_sorted,pp: pixel_array_type:=(others=>(others=>'0'));
begin
   rnd16_chip: rnd16_module generic map (conv_std_logic_vector(26535,32)) port map(clk,rnd16);

   RAM_16kw_chip: ram_16kw port map (clk, ram16_wea, ram16_addr, ram16_wr_data, ram16_rd_data);
  
   process(clk)
   variable fsm,sub_fsm: natural range 0 to 255 := 0;
   variable x,y: std_logic_vector(9 downto 0):=(others=>'0');
   variable pixel: std_logic_vector(15 downto 0):=(others=>'0');
   variable x_rnd,y_rnd: std_logic_vector(9 downto 0):=(others=>'0');
   variable seg_xmin,seg_xmax: std_logic_vector(9 downto 0):=(others=>'0');
   variable seg_ymin,seg_ymax: std_logic_vector(9 downto 0):=(others=>'0');
   variable probes_num: integer range 0 to 1000:=100;
   variable k: integer range 0 to 1000:=0;
   variable i: integer range 0 to 8192:=0;
   variable c0: std_logic_vector(15 downto 0):=(others=>'0');
  
   begin
   if rising_edge(clk) then
   case fsm is
   --idle
   when 0=> 
      k:=0;
      mem_ask<='0'; mem_wr_en<='0';
      ready<='0';
      if (ask='1')and(mem_ready='0') then fsm:=1; end if;

   -- while k<probes_num do
   when 1=> if k<probes_num then k:=k+1; fsm:=2; else fsm:=255; end if;
   
   -- generate probe coordinates
   when 2=> x_rnd:="0" & rnd16(8 downto 0); fsm:=3;
   when 3=> y_rnd:="0" & rnd16(8 downto 0); fsm:=4;
   when 4=> if (x_rnd>task_xmin)and(x_rnd<task_xmax) and
               (y_rnd>task_ymin)and(y_rnd<task_ymax)
            then fsm:=5;
            else fsm:=2;
            end if;
   
   -- c0:=GetPixel(x_rnd,y_rnd,page_mid)
   when 5=>
      mem_addr<=rd_page_mid & y_rnd & x_rnd; mem_wr_en<='0';
      if mem_ready='0' then mem_ask<='1'; fsm:=6; end if;
   when 6=> if mem_ready='1' then mem_ask<='0'; c0:=mem_rd_data; fsm:=7; end if;
   
   -- if c0>0 then next stage else go to new attempt to find segment
   when 7=> if c0(15 downto 8)="00000000" then fsm:=8; else fsm:=1; end if;
   
   --FloodFillFuzzy process
   when 8=> fsm:=254;

   -- reject false image
   when 128=> if n<pixels_num then n:=0; fsm:=1; else fsm:=129; end if;
   
   -- find bounds of segment
   -- seg_xmin:=ram16[0]; seg_xmax:=ram16[0]
   when 129=> ram16_wea<=(0=>'0'); ram16_addr<=conv_std_logic_vector(0,13); fsm:=130;
   when 130=> seg_xmin:=ram16_rd_data; seg_xmax:=ram16_rd_data; fsm:=131;
   -- seg_ymin:=ram16[1]; seg_ymax:=ram16[1]
   when 131=> ram16_addr<=conv_std_logic_vector(1,13); fsm:=132;
   when 132=> seg_ymin:=ram16_rd_data; seg_ymax:=ram16_rd_data; fsm:=133;
   
   -- while i<n do
   when 133=> if i<n then fsm:=134; else fsm:=1; end if;
   
   -- x:=ram16[2*i];
   when 134=> ram16_addr<=conv_std_logic_vector(2*i,13); fsm:=135;
   -- if x<seg_xmin then seg_xmin:=x
   -- if x>seg_xmax then seg_xmax:=x
   when 135=>
      if ram16_rd_data<seg_xmin then seg_xmin:=ram16_rd_data(9 downto 0); end if;
      if ram16_rd_data>seg_xmax then seg_xmax:=ram16_rd_data; end if;
      fsm:=136;
      
   -- y:=ram16[2*i+1];
   when 136=> ram16_addr<=conv_std_logic_vector(2*i+1,13); fsm:=137;
   -- if y<seg_ymin then seg_ymin:=y
   -- if y>seg_ymax then seg_ymax:=y
   when 137=>
      if ram16_rd_data<seg_ymin then seg_ymin:=ram16_rd_data; end if;
      if ram16_rd_data>seg_ymax then seg_ymax:=ram16_rd_data; end if;
      fsm:=138;

   -- next i
   when 138=> i:=i+1; fsm:=133;
   
   -- next idle
   when 255=>
      ready<='1';
      if ask='0' then fsm:=0; end if;
   when others=>null;
   end case;
   end if;
   end process;
end ax309;
