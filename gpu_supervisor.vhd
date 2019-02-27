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
-- Description: video cpu supervisor for a simple overhead operations
--      (copy and rotate video pages, perform main task)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity gpu_supervisor is
    Port ( 
		clk        : in std_logic;
      
      gpu_mem_ask: out std_logic;
      gpu_mem_ready: in std_logic;
      gpu_mem_wr_en: out std_logic;
      gpu_mem_addr : out std_logic_vector(23 downto 0);
      gpu_mem_rd_data: in std_logic_vector(15 downto 0);
      gpu_mem_wr_data: out std_logic_vector(15 downto 0);
      
      hscanline_rd_ask: out std_logic;
      hscanline_rd_ready: in std_logic;
      hscanline_rd_page: out std_logic_vector(3 downto 0);
      hscanline_rd_x: out std_logic_vector(9 downto 0);
      hscanline_rd_y: out std_logic_vector(9 downto 0);
      hscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      hscanline_wr_ask: out std_logic;
      hscanline_wr_ready: in std_logic;
      hscanline_wr_page: out std_logic_vector(3 downto 0);
      hscanline_wr_x: out std_logic_vector(9 downto 0);
      hscanline_wr_y: out std_logic_vector(9 downto 0);
      hscanline_wr_pixel: out std_logic_vector(15 downto 0);

      hscanline_xmin : out std_logic_vector(9 downto 0);
      hscanline_xmax : out std_logic_vector(9 downto 0);

      vscanline_rd_ask: out std_logic;
      vscanline_rd_ready: in std_logic;
      vscanline_rd_page: out std_logic_vector(3 downto 0);
      vscanline_rd_x: out std_logic_vector(9 downto 0);
      vscanline_rd_y: out std_logic_vector(9 downto 0);
      vscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      vscanline_wr_ask: out std_logic;
      vscanline_wr_ready: in std_logic;
      vscanline_wr_page: out std_logic_vector(3 downto 0);
      vscanline_wr_x: out std_logic_vector(9 downto 0);
      vscanline_wr_y: out std_logic_vector(9 downto 0);
      vscanline_wr_pixel: out std_logic_vector(15 downto 0);

      vscanline_ymin : out std_logic_vector(9 downto 0);
      vscanline_ymax : out std_logic_vector(9 downto 0);      

      task_xmin : in std_logic_vector(9 downto 0);
      task_ymin : in std_logic_vector(9 downto 0);
      task_xmax : in std_logic_vector(9 downto 0);
      task_ymax : in std_logic_vector(9 downto 0);

      k1,k2,k3,k4,k5,k6,k7,k8,k9 : in std_logic_vector(5 downto 0);
      pow2_div : in std_logic_vector(7 downto 0);
      bss_cnt, rns_cnt: out std_logic_vector(31 downto 0);
      cnt_reset: in std_logic;
      
      bss_task_xmin : in std_logic_vector(9 downto 0);
      bss_task_ymin : in std_logic_vector(9 downto 0);
      bss_task_xmax : in std_logic_vector(9 downto 0);
      bss_task_ymax : in std_logic_vector(9 downto 0);

      rns_task_xmin: in std_logic_vector(9 downto 0);
      rns_task_ymin: in std_logic_vector(9 downto 0);
      rns_task_xmax: in std_logic_vector(9 downto 0);
      rns_task_ymax: in std_logic_vector(9 downto 0)
	 );
end gpu_supervisor;

architecture ax309 of gpu_supervisor is
   component gpu_primitive_module is
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
   end component;
   signal gpu_prim_ask,gpu_prim_ready : std_logic:='0';
   signal gpu_prim_mode: std_logic_vector(2 downto 0):=(others=>'0');
   signal gpu_prim_xmin: std_logic_vector(9 downto 0):=conv_std_logic_vector(208,10);
   signal gpu_prim_ymin: std_logic_vector(9 downto 0):=conv_std_logic_vector(0,10);
   signal gpu_prim_xmax: std_logic_vector(9 downto 0):=conv_std_logic_vector(480,10);
   signal gpu_prim_ymax: std_logic_vector(9 downto 0):=conv_std_logic_vector(480,10);
   signal gpu_prim_rd_page : std_logic_vector(3 downto 0):=(others=>'0');
   signal gpu_prim_wr_page : std_logic_vector(3 downto 0):=(others=>'0');

   component filter_bss_supervisor is
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
   end component;
   signal filter_bss_ask,filter_bss_ready : std_logic:='0';
   signal bss_mem_ask: std_logic:='0';
   signal bss_mem_wr_en: std_logic:='0';
   signal bss_mem_addr : std_logic_vector(23 downto 0):=(others=>'0');
   signal bss_mem_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal bss_pix_cnt: std_logic_vector(31 downto 0):=(others=>'0');
   signal bss_clk_cnt: std_logic_vector(31 downto 0):=(others=>'0');
   signal bss_cnt_reg: std_logic_vector(31 downto 0):=(others=>'0');

   component filter_rns_supervisor is
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
   end component;
   signal filter_rns_ask,filter_rns_ready : std_logic:='0';
   signal rns_mem_ask: std_logic:='0';
   signal rns_mem_wr_en: std_logic:='0';
   signal rns_mem_addr : std_logic_vector(23 downto 0):=(others=>'0');
   signal rns_mem_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal rns_pix_cnt: std_logic_vector(31 downto 0):=(others=>'0');
   signal rns_clk_cnt: std_logic_vector(31 downto 0):=(others=>'0');
   signal rns_cnt_reg: std_logic_vector(31 downto 0):=(others=>'0');
   
begin
   gpu_primitive_chip: gpu_primitive_module port map (
      clk, gpu_prim_ask,gpu_prim_ready,
      
      hscanline_rd_ask, hscanline_rd_ready,
      hscanline_rd_x, hscanline_rd_y,
      hscanline_rd_pixel,

      hscanline_wr_ask, hscanline_wr_ready,
      hscanline_wr_x, hscanline_wr_y,
      hscanline_wr_pixel,
      
      vscanline_rd_ask,vscanline_rd_ready,
      vscanline_rd_x,vscanline_rd_y,
      vscanline_rd_pixel,

      vscanline_wr_ask,vscanline_wr_ready,
      vscanline_wr_x,vscanline_wr_y,
      vscanline_wr_pixel,

      gpu_prim_mode,
      gpu_prim_xmin, gpu_prim_ymin, gpu_prim_xmax, gpu_prim_ymax
   );
-----------------------------------------------------------------

   hscanline_rd_page<=gpu_prim_rd_page;
   vscanline_rd_page<=gpu_prim_rd_page;
   
   hscanline_wr_page<=gpu_prim_wr_page;
   vscanline_wr_page<=gpu_prim_wr_page;
-----------------------------------------------------------------

   filter_bss_supervisor_chip: filter_bss_supervisor port map ( 
		clk, filter_bss_ask, filter_bss_ready,
      bss_mem_ask, gpu_mem_ready, bss_mem_wr_en,
      bss_mem_addr, gpu_mem_rd_data, bss_mem_wr_data,

      k1(5)&k1(5)&k1,
      k2(5)&k2(5)&k2,
      k3(5)&k3(5)&k3,
      k4(5)&k4(5)&k4,
      k5(5)&k5(5)&k5,
      k6(5)&k6(5)&k6,
      k7(5)&k7(5)&k7,
      k8(5)&k8(5)&k8,
      k9(5)&k9(5)&k9,
      pow2_div,
      
      bss_task_xmin,bss_task_ymin,bss_task_xmax,bss_task_ymax,
      "0010", "0011",

      bss_pix_cnt, cnt_reset
	 );
-----------------------------------------------------------------

   filter_rns_supervisor_chip: filter_rns_supervisor port map ( 
		clk, filter_rns_ask, filter_rns_ready,
      rns_mem_ask, gpu_mem_ready, rns_mem_wr_en,
      rns_mem_addr, gpu_mem_rd_data, rns_mem_wr_data,

      k1(5)&k1(5)&k1,
      k2(5)&k2(5)&k2,
      k3(5)&k3(5)&k3,
      k4(5)&k4(5)&k4,
      k5(5)&k5(5)&k5,
      k6(5)&k6(5)&k6,
      k7(5)&k7(5)&k7,
      k8(5)&k8(5)&k8,
      k9(5)&k9(5)&k9,
      pow2_div,
      
      rns_task_xmin,rns_task_ymin,rns_task_xmax,rns_task_ymax,
      "0010", "0011",

      rns_pix_cnt, cnt_reset
	 );
-----------------------------------------------------------------

   gpu_mem_ask<=bss_mem_ask when filter_bss_ask='1' else rns_mem_ask when filter_rns_ask='1' else '0';
   gpu_mem_wr_en<=bss_mem_wr_en when filter_bss_ask='1' else rns_mem_wr_en when filter_rns_ask='1' else '0';
   gpu_mem_addr<=bss_mem_addr when filter_bss_ask='1' else rns_mem_addr when filter_rns_ask='1' else (others=>'0');
   gpu_mem_wr_data<=bss_mem_wr_data when filter_bss_ask='1' else rns_mem_wr_data when filter_rns_ask='1' else (others=>'0');
   
-----------------------------------------------------------------  
   process(clk)
   variable fsm: integer range 0 to 31:=0;
   variable cnt: integer range 0 to 65535 := 0;
   begin
   if rising_edge(clk) then
   case fsm is
   -- super idle
   when 0=>
      gpu_prim_xmin<=conv_std_logic_vector(208,10); gpu_prim_xmax<=conv_std_logic_vector(480,10);
      gpu_prim_ymin<=conv_std_logic_vector(0,10); gpu_prim_ymax<=conv_std_logic_vector(480,10);
      gpu_prim_ask<='0'; 
      if gpu_prim_ready='0' then fsm:=1; end if;

   -- CCW rotate output buffer and copy to videocontroller page
   when 1=> 
      gpu_prim_rd_page<="0101"; gpu_prim_wr_page<="0000";
      gpu_prim_mode<="001"; -- CCW ROTATE mode
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=2; end if;
   when 2=>
      hscanline_xmin<=gpu_prim_xmin; hscanline_xmax<=gpu_prim_xmax;
      vscanline_ymin<=gpu_prim_ymin; vscanline_ymax<=gpu_prim_ymax;
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=3; end if;

   -- "CAMERA page" copy to "Source page"
   when 3=> 
      gpu_prim_rd_page<="0001"; gpu_prim_wr_page<="0010";
      gpu_prim_mode<="000"; -- CLEAR COPY mode
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=4; end if;
   when 4=>
      hscanline_xmin<=gpu_prim_xmin; hscanline_xmax<=gpu_prim_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=7; end if;

   -- BSS filtering process
   when 7=> if filter_bss_ready='0' then filter_bss_ask<='1'; fsm:=8; end if;
   when 8=> if filter_bss_ready='1' then filter_bss_ask<='0'; fsm:=9; end if; 

   -- RNS filtering process
   when 9=> if filter_rns_ready='0' then filter_rns_ask<='1'; fsm:=10; end if;
   when 10=> if filter_rns_ready='1' then filter_rns_ask<='0'; fsm:=11; end if; 
   
   -- compose all pages
--   -- "source page" copy to "output buffer"
--   when 11=>
--      gpu_prim_rd_page<="0010"; gpu_prim_wr_page<="0101";
--      gpu_prim_mode<="000"; -- CLEAR COPY mode
--      gpu_prim_xmin<=conv_std_logic_vector(208,10); gpu_prim_xmax<=conv_std_logic_vector(480,10);
--      gpu_prim_ymin<=conv_std_logic_vector(0,10); gpu_prim_ymax<=conv_std_logic_vector(480,10);
--      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=12; end if;
--   when 12=>
--      hscanline_xmin<=gpu_prim_xmin; hscanline_xmax<=gpu_prim_xmax;
--      vscanline_ymin<=gpu_prim_ymin; vscanline_ymax<=task_ymin;
--      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=19; end if;
   
   -- "source page" copy to "output buffer" (except filters zones)
   when 11=>
      gpu_prim_rd_page<="0010"; gpu_prim_wr_page<="0101";
      gpu_prim_mode<="000"; -- CLEAR COPY mode
      gpu_prim_xmin<=conv_std_logic_vector(208,10); gpu_prim_xmax<=conv_std_logic_vector(480,10);
      gpu_prim_ymin<=conv_std_logic_vector(0,10); gpu_prim_ymax<=task_ymin;
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=12; end if;
   when 12=>
      hscanline_xmin<=gpu_prim_xmin; hscanline_xmax<=gpu_prim_xmax;
      vscanline_ymin<=gpu_prim_ymin; vscanline_ymax<=task_ymin;
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=13; end if;

   when 13=>
      gpu_prim_rd_page<="0010"; gpu_prim_wr_page<="0101";
      gpu_prim_mode<="000"; -- CLEAR COPY mode
      gpu_prim_xmin<=conv_std_logic_vector(208,10); gpu_prim_xmax<=task_xmin;
      gpu_prim_ymin<=task_ymin; gpu_prim_ymax<=task_ymax;
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=14; end if;
   when 14=>
      hscanline_xmin<=gpu_prim_xmin; hscanline_xmax<=task_xmin;
      vscanline_ymin<=task_ymin; vscanline_ymax<=task_ymax;
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=15; end if;

   when 15=>
      gpu_prim_rd_page<="0010"; gpu_prim_wr_page<="0101";
      gpu_prim_mode<="000"; -- CLEAR COPY mode
      gpu_prim_xmin<=task_xmax; gpu_prim_xmax<=conv_std_logic_vector(480,10);
      gpu_prim_ymin<=task_ymin; gpu_prim_ymax<=task_ymax;
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=16; end if;
   when 16=>
      hscanline_xmin<=task_xmax; hscanline_xmax<=gpu_prim_xmax;
      vscanline_ymin<=task_ymin; vscanline_ymax<=task_ymax;
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=17; end if;

   when 17=>
      gpu_prim_rd_page<="0010"; gpu_prim_wr_page<="0101";
      gpu_prim_mode<="000"; -- CLEAR COPY mode
      gpu_prim_xmin<=conv_std_logic_vector(208,10); gpu_prim_xmax<=conv_std_logic_vector(480,10);
      gpu_prim_ymin<=task_ymax; gpu_prim_ymax<=conv_std_logic_vector(480,10);
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=18; end if;
   when 18=>
      hscanline_xmin<=gpu_prim_xmin; hscanline_xmax<=gpu_prim_xmax;
      vscanline_ymin<=task_ymax; vscanline_ymax<=gpu_prim_ymax;
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=19; end if;
      
   -- "BSS filter result" copy to "output buffer"
   when 19=>
      gpu_prim_rd_page<="0011"; gpu_prim_wr_page<="0101";
      gpu_prim_mode<="000"; -- CLEAR COPY mode
      gpu_prim_xmin<=bss_task_xmin; gpu_prim_xmax<=bss_task_xmax;
      gpu_prim_ymin<=bss_task_ymin; gpu_prim_ymax<=bss_task_ymax;
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=20; end if;
   when 20=>
      hscanline_xmin<=bss_task_xmin; hscanline_xmax<=bss_task_xmax;
      vscanline_ymin<=bss_task_ymin; vscanline_ymax<=bss_task_ymax;
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=21; end if;

   -- "RNS filter result" copy to "output buffer"
   when 21=>
      gpu_prim_rd_page<="0011"; gpu_prim_wr_page<="0101";
      gpu_prim_mode<="000"; -- CLEAR COPY mode
      gpu_prim_xmin<=rns_task_xmin; gpu_prim_xmax<=rns_task_xmax;
      gpu_prim_ymin<=rns_task_ymin; gpu_prim_ymax<=rns_task_ymax;      
      if gpu_prim_ready='0' then gpu_prim_ask<='1'; fsm:=22; end if;
   when 22=>
      hscanline_xmin<=rns_task_xmin; hscanline_xmax<=rns_task_xmax;
      vscanline_ymin<=rns_task_ymin; vscanline_ymax<=rns_task_ymax;
      if gpu_prim_ready='1' then gpu_prim_ask<='0'; fsm:=0; end if;
      
   when others=>null;
   end case;
   end if;
   end process;

   -- BSS filter statistica
   process(clk)
   begin
   if rising_edge(clk) then
      if cnt_reset='1' then
         bss_clk_cnt<=(others=>'0');
         bss_cnt<=bss_cnt_reg;
      elsif  filter_bss_ask='1' then 
         bss_clk_cnt<=bss_clk_cnt+1;
         bss_cnt_reg<=bss_clk_cnt;
      end if;
   end if;
   end process;

   -- RNS filter statistica
   process(clk)
   begin
   if rising_edge(clk) then
      if cnt_reset='1' then
         rns_clk_cnt<=(others=>'0');
         rns_cnt<=rns_cnt_reg;
      elsif  filter_rns_ask='1' then 
         rns_clk_cnt<=rns_clk_cnt+1;
         rns_cnt_reg<=rns_clk_cnt;
      end if;
   end if;
   end process;
   
end ax309;
