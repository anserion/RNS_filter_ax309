------------------------------------------------------------------
--Copyright 2017-2019 Andrey S. Ionisyan (anserion@gmail.com)
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
-- Description: BSS filter of 8-bit grayscale image
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity filter_3x3_bss is
   Port ( 
      clk   : in std_logic;
      ask   : in std_logic;
      ready : out std_logic;
      k1,k2,k3,k4,k5,k6,k7,k8,k9 : in std_logic_vector(7 downto 0);
      pow2_div : in std_logic_vector(7 downto 0);
      p1,p2,p3,p4,p5,p6,p7,p8,p9	: in std_logic_vector(7 downto 0);
      res   : out std_logic_vector(7 downto 0)
      );
end filter_3x3_bss;

architecture ax309 of filter_3x3_bss is
   component add_16bit is
   port (
      clk: in std_logic;
      a,b: in std_logic_vector(15 downto 0);
      res: out std_logic_vector(15 downto 0)
   );
   end component;

   component mul_8bit is
	port (
		clk: in std_logic;
		a_sgn: in std_logic_vector(7 downto 0);
      b  : in std_logic_vector(7 downto 0);
		res: out std_logic_vector(15 downto 0)
	);
   end component;
   
signal k1p1,k2p2,k3p3,k4p4,k5p5,k6p6,k7p7,k8p8,k9p9: std_logic_vector(15 downto 0) := (others=>'0');
signal s12,s34,s56,s78,s1234,s5678,s12345678,sum_reg: std_logic_vector(15 downto 0) := (others=>'0');
signal pow2_shift: integer range 0 to 7 := 0;

begin
   k1p1_chip: mul_8bit port map(clk,k1,p1,k1p1);
   k2p2_chip: mul_8bit port map(clk,k2,p2,k2p2);
   k3p3_chip: mul_8bit port map(clk,k3,p3,k3p3);
   k4p4_chip: mul_8bit port map(clk,k4,p4,k4p4);
   k5p5_chip: mul_8bit port map(clk,k5,p5,k5p5);
   k6p6_chip: mul_8bit port map(clk,k6,p6,k6p6);
   k7p7_chip: mul_8bit port map(clk,k7,p7,k7p7);
   k8p8_chip: mul_8bit port map(clk,k8,p8,k8p8);
   k9p9_chip: mul_8bit port map(clk,k9,p9,k9p9);
   
   s12_chip: add_16bit port map(clk,k1p1,k2p2,s12);
   s34_chip: add_16bit port map(clk,k3p3,k4p4,s34);
   s56_chip: add_16bit port map(clk,k5p5,k6p6,s56);
   s78_chip: add_16bit port map(clk,k7p7,k8p8,s78);
   
   s1234_chip: add_16bit port map(clk,s12,s34,s1234);
   s5678_chip: add_16bit port map(clk,s56,s78,s5678);
   
   s12345678_chip: add_16bit port map(clk,s1234,s5678,s12345678);
   sum_chip: add_16bit port map(clk,s12345678,k9p9,sum_reg);

   pow2_shift<= 0 when pow2_div=1
           else 1 when pow2_div=2
           else 2 when pow2_div=4
           else 3 when pow2_div=8
           else 4 when pow2_div=16
           else 5 when pow2_div=32
           else 6 when pow2_div=64
           else 7 when pow2_div=128
           else 0;

   process (clk)
   variable fsm: integer range 0 to 3 := 0;
   variable sum_cnt: integer range 0 to 127 := 0;
   begin
      if rising_edge(clk) then
         case fsm is
         when 0 =>
            ready<='0';
            sum_cnt:=0;
            if ask='1' then fsm:=1; end if;
         when 1 =>
            -- some latency for all asyncronic calculations
            if sum_cnt=64 then fsm:=2; else sum_cnt:=sum_cnt+1; end if;
         when 2 =>
            if sum_reg(15)='1' then res<=(others=>'0');
            elsif sum_reg(14 downto 8+pow2_shift)/=0 then res<=(others=>'1');
            else res<=sum_reg(7+pow2_shift downto pow2_shift);
            end if;
            fsm:=3;
         when 3=>
            ready<='1';
            if ask='0' then fsm:=0; end if;
         when others => null;
         end case;
      end if;
   end process;
end ax309;
