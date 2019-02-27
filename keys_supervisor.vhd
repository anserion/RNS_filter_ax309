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
-- Description: keys supervisor.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity keys_supervisor is
   Port ( 
      clk : in std_logic;
      en  : in std_logic;
      key : in std_logic_vector(3 downto 0);
      key_rst: in std_logic;
      k1,k2,k3,k4,k5,k6,k7,k8,k9 : out std_logic_vector(5 downto 0);
      pow2_div : out std_logic_vector(7 downto 0);
      sector : out std_logic_vector(3 downto 0);
      video_out: out std_logic
	);
end keys_supervisor;

architecture ax309 of keys_supervisor is
   signal fsm: natural range 0 to 7 := 0;
   signal debounce_cnt: natural range 0 to 1023 :=0;
   signal k1_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal k2_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal k3_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal k4_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal k5_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(8,6);
   signal k6_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal k7_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal k8_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal k9_reg: std_logic_vector(5 downto 0):=conv_std_logic_vector(-1,6);
   signal pow2_div_reg: std_logic_vector(7 downto 0):=conv_std_logic_vector(2,8);
   signal sector_reg: std_logic_vector(3 downto 0):=conv_std_logic_vector(10,4);
   signal video_out_reg: std_logic:='0';
begin
   k1<=k1_reg; k2<=k2_reg; k3<=k3_reg;
   k4<=k4_reg; k5<=k5_reg; k6<=k6_reg;
   k7<=k7_reg; k8<=k8_reg; k9<=k9_reg;
   pow2_div<=pow2_div_reg;
   video_out<=video_out_reg;
   sector<=sector_reg;
   process(clk)
   begin
      if rising_edge(clk) and en='1' then
         case fsm is
         -- wait for press any control key
         when 0 =>
            if (key(0)='0')or(key(1)='0')or(key(2)='0')or(key(3)='0')or(key_rst='0')
            then debounce_cnt<=0; fsm<=1;
            end if;
         -- debounce
         when 1 =>
            if debounce_cnt=500
            then fsm<=2;
            else debounce_cnt<=debounce_cnt+1;
            end if;
         -- change registers
         when 2 =>
            if (key(0)='0')and(sector_reg>1) then sector_reg<=sector_reg-1; end if;
            if (key(1)='0')and(sector_reg<10) then sector_reg<=sector_reg+1; end if;
            
            if (key(2)='0')and((k1_reg>55)or(k1_reg<10))and(sector_reg=1) then k1_reg<=k1_reg-1;end if;
            if (key(2)='0')and((k2_reg>55)or(k2_reg<10))and(sector_reg=2) then k2_reg<=k2_reg-1;end if;
            if (key(2)='0')and((k3_reg>55)or(k3_reg<10))and(sector_reg=3) then k3_reg<=k3_reg-1;end if;
            if (key(2)='0')and((k4_reg>55)or(k4_reg<10))and(sector_reg=4) then k4_reg<=k4_reg-1;end if;
            if (key(2)='0')and((k5_reg>55)or(k5_reg<10))and(sector_reg=5) then k5_reg<=k5_reg-1;end if;
            if (key(2)='0')and((k6_reg>55)or(k6_reg<10))and(sector_reg=6) then k6_reg<=k6_reg-1;end if;
            if (key(2)='0')and((k7_reg>55)or(k7_reg<10))and(sector_reg=7) then k7_reg<=k7_reg-1;end if;
            if (key(2)='0')and((k8_reg>55)or(k8_reg<10))and(sector_reg=8) then k8_reg<=k8_reg-1;end if;
            if (key(2)='0')and((k9_reg>55)or(k9_reg<10))and(sector_reg=9) then k9_reg<=k9_reg-1;end if;
            if (key(2)='0')and(pow2_div_reg/=1)and(sector_reg=10) then pow2_div_reg<='0'&pow2_div_reg(7 downto 1);end if;

            if (key(3)='0')and((k1_reg>54)or(k1_reg<9))and(sector_reg=1) then k1_reg<=k1_reg+1;end if;
            if (key(3)='0')and((k2_reg>54)or(k2_reg<9))and(sector_reg=2) then k2_reg<=k2_reg+1;end if;
            if (key(3)='0')and((k3_reg>54)or(k3_reg<9))and(sector_reg=3) then k3_reg<=k3_reg+1;end if;
            if (key(3)='0')and((k4_reg>54)or(k4_reg<9))and(sector_reg=4) then k4_reg<=k4_reg+1;end if;
            if (key(3)='0')and((k5_reg>54)or(k5_reg<9))and(sector_reg=5) then k5_reg<=k5_reg+1;end if;
            if (key(3)='0')and((k6_reg>54)or(k6_reg<9))and(sector_reg=6) then k6_reg<=k6_reg+1;end if;
            if (key(3)='0')and((k7_reg>54)or(k7_reg<9))and(sector_reg=7) then k7_reg<=k7_reg+1;end if;
            if (key(3)='0')and((k8_reg>54)or(k8_reg<9))and(sector_reg=8) then k8_reg<=k8_reg+1;end if;
            if (key(3)='0')and((k9_reg>54)or(k9_reg<9))and(sector_reg=9) then k9_reg<=k9_reg+1;end if;
            if (key(3)='0')and(pow2_div_reg/=128)and(sector_reg=10) then pow2_div_reg<=pow2_div_reg(6 downto 0)&'0';end if;
            
            if key_rst='0' then
               video_out_reg<=not(video_out_reg);
            end if;
            fsm<=3;
         -- wait for release all control keys
         when 3 =>
            if (key(0)='1')and(key(1)='1')and(key(2)='1')and(key(3)='1')and(key_rst='1')
            then debounce_cnt<=0; fsm<=4;
            end if;
         -- debounce
         when 4 =>
            if debounce_cnt=500
            then fsm<=0;
            else debounce_cnt<=debounce_cnt+1;
            end if;
         when others => null;
         end case;
      end if;
   end process;
end;

