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
-- Description: generate 8-char text box for a VGA controller
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity msg_center is
    Port ( 
		clk        : in  STD_LOGIC;
      en         : in std_logic;
      k1,k2,k3,k4,k5,k6,k7,k8,k9: in std_logic_vector(5 downto 0);
      pow2_div   : in std_logic_vector(7 downto 0);
      bss_cnt, rns_cnt: in std_logic_vector(31 downto 0);
		msg_char_x : out STD_LOGIC_VECTOR(6 downto 0);
		msg_char_y : out STD_LOGIC_VECTOR(4 downto 0);
		msg_char   : out STD_LOGIC_VECTOR(7 downto 0)
	 );
end msg_center;

architecture Behavioral of msg_center is
    function string_to_std_logic_vector(str: string)
    return std_logic_vector is variable res: std_logic_vector(str'length*8-1 downto 0);
    begin
    	for i in 1 to str'high loop 
         res(i*8-1 downto 8*(i-1)):=conv_std_logic_vector(character'pos(str(str'high+1-i)),8);
    	end loop;
    	return res;
    end function;

    function bcd32_to_std_logic_vector(bcd: std_logic_vector(31 downto 0))
    return std_logic_vector is variable res: std_logic_vector(63 downto 0);
    begin
    res:=conv_std_logic_vector(conv_integer(bcd(31 downto 28))+48,8) &
         conv_std_logic_vector(conv_integer(bcd(27 downto 24))+48,8) &
         conv_std_logic_vector(conv_integer(bcd(23 downto 20))+48,8) &
         conv_std_logic_vector(conv_integer(bcd(19 downto 16))+48,8) &
         conv_std_logic_vector(conv_integer(bcd(15 downto 12))+48,8) &
         conv_std_logic_vector(conv_integer(bcd(11 downto 8))+48,8) &
         conv_std_logic_vector(conv_integer(bcd(7 downto 4))+48,8) &
         conv_std_logic_vector(conv_integer(bcd(3 downto 0))+48,8);    
    return res;
    end function;

   component bin24_to_bcd is
    Port ( 
		clk   : in  STD_LOGIC;
      en    : in std_logic;
      bin   : in std_logic_vector(23 downto 0);
      bcd   : out std_logic_vector(31 downto 0);
      ready : out std_logic
	 );
   end component;

   signal k1_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k2_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k3_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k4_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k5_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k6_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k7_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k8_log: std_logic_vector(15 downto 0):=(others=>'0');
   signal k9_log: std_logic_vector(15 downto 0):=(others=>'0');
   
   signal pow2_div_bcd: std_logic_vector(31 downto 0):=(others=>'0');
   signal rns_cnt_bcd: std_logic_vector(31 downto 0):=(others=>'0');
   signal bss_cnt_bcd: std_logic_vector(31 downto 0):=(others=>'0');

   signal pow2_div_bcd_ready: std_logic:='0';
   signal rns_cnt_bcd_ready: std_logic:='0';
   signal bss_cnt_bcd_ready: std_logic:='0';
   
   component msg_box is
    Port ( 
		clk       : in  STD_LOGIC;
      x         : in  STD_LOGIC_VECTOR(7 downto 0);
      y         : in  STD_LOGIC_VECTOR(7 downto 0);
		msg       : in  STD_LOGIC_VECTOR(63 downto 0);
		char_x    : out STD_LOGIC_VECTOR(7 downto 0);
		char_y	 : out STD_LOGIC_VECTOR(7 downto 0);
		char_code : out STD_LOGIC_VECTOR(7 downto 0)
	 );
   end component;

   signal msg_fsm: natural range 0 to 65535:=0;
   
   signal msg1_char_x: std_logic_vector(7 downto 0);
   signal msg1_char_y: std_logic_vector(7 downto 0);
   signal msg1_char: std_logic_vector(7 downto 0);
   
   signal msg2_char_x: std_logic_vector(7 downto 0);
   signal msg2_char_y: std_logic_vector(7 downto 0);
   signal msg2_char: std_logic_vector(7 downto 0);

   signal msg3_char_x: std_logic_vector(7 downto 0);
   signal msg3_char_y: std_logic_vector(7 downto 0);
   signal msg3_char: std_logic_vector(7 downto 0);

   signal msg4_char_x: std_logic_vector(7 downto 0);
   signal msg4_char_y: std_logic_vector(7 downto 0);
   signal msg4_char: std_logic_vector(7 downto 0);

   signal msg5_char_x: std_logic_vector(7 downto 0);
   signal msg5_char_y: std_logic_vector(7 downto 0);
   signal msg5_char: std_logic_vector(7 downto 0);

   signal msg6_char_x: std_logic_vector(7 downto 0);
   signal msg6_char_y: std_logic_vector(7 downto 0);
   signal msg6_char: std_logic_vector(7 downto 0);
 
   signal msg7_char_x: std_logic_vector(7 downto 0);
   signal msg7_char_y: std_logic_vector(7 downto 0);
   signal msg7_char: std_logic_vector(7 downto 0);

   signal msg8_char_x: std_logic_vector(7 downto 0);
   signal msg8_char_y: std_logic_vector(7 downto 0);
   signal msg8_char: std_logic_vector(7 downto 0);

   signal msg9_char_x: std_logic_vector(7 downto 0);
   signal msg9_char_y: std_logic_vector(7 downto 0);
   signal msg9_char: std_logic_vector(7 downto 0);

   signal msg10_char_x: std_logic_vector(7 downto 0);
   signal msg10_char_y: std_logic_vector(7 downto 0);
   signal msg10_char: std_logic_vector(7 downto 0);

   signal msg11_char_x: std_logic_vector(7 downto 0);
   signal msg11_char_y: std_logic_vector(7 downto 0);
   signal msg11_char: std_logic_vector(7 downto 0);

   signal msg12_char_x: std_logic_vector(7 downto 0);
   signal msg12_char_y: std_logic_vector(7 downto 0);
   signal msg12_char: std_logic_vector(7 downto 0);

begin
   k1_log(15 downto 8)<=conv_std_logic_vector(32,8) when k1(5)='0' else conv_std_logic_vector(45,8);
   k1_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k1)+48,8) when k1(5)='0'
         else conv_std_logic_vector(112-conv_integer(k1),8);
   
   k2_log(15 downto 8)<=conv_std_logic_vector(32,8) when k2(5)='0' else conv_std_logic_vector(45,8);
   k2_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k2)+48,8) when k2(5)='0'
         else conv_std_logic_vector(112-conv_integer(k2),8);

   k3_log(15 downto 8)<=conv_std_logic_vector(32,8) when k3(5)='0' else conv_std_logic_vector(45,8);
   k3_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k3)+48,8) when k3(5)='0'
         else conv_std_logic_vector(112-conv_integer(k3),8);

   k4_log(15 downto 8)<=conv_std_logic_vector(32,8) when k4(5)='0' else conv_std_logic_vector(45,8);
   k4_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k4)+48,8) when k4(5)='0'
         else conv_std_logic_vector(112-conv_integer(k4),8);

   k5_log(15 downto 8)<=conv_std_logic_vector(32,8) when k5(5)='0' else conv_std_logic_vector(45,8);
   k5_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k5)+48,8) when k5(5)='0'
         else conv_std_logic_vector(112-conv_integer(k5),8);

   k6_log(15 downto 8)<=conv_std_logic_vector(32,8) when k6(5)='0' else conv_std_logic_vector(45,8);
   k6_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k6)+48,8) when k6(5)='0'
         else conv_std_logic_vector(112-conv_integer(k6),8);

   k7_log(15 downto 8)<=conv_std_logic_vector(32,8) when k7(5)='0' else conv_std_logic_vector(45,8);
   k7_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k7)+48,8) when k7(5)='0'
         else conv_std_logic_vector(112-conv_integer(k7),8);

   k8_log(15 downto 8)<=conv_std_logic_vector(32,8) when k8(5)='0' else conv_std_logic_vector(45,8);
   k8_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k8)+48,8) when k8(5)='0'
         else conv_std_logic_vector(112-conv_integer(k8),8);

   k9_log(15 downto 8)<=conv_std_logic_vector(32,8) when k9(5)='0' else conv_std_logic_vector(45,8);
   k9_log(7 downto 0)<=conv_std_logic_vector(conv_integer(k9)+48,8) when k9(5)='0'
         else conv_std_logic_vector(112-conv_integer(k9),8);
   
   pow2_bcd_chip: bin24_to_bcd port map (clk,'1',conv_std_logic_vector(0,16)&pow2_div,pow2_div_bcd,pow2_div_bcd_ready);
   rns_bcd_chip: bin24_to_bcd port map (clk,'1',rns_cnt(23 downto 0),rns_cnt_bcd,rns_cnt_bcd_ready);
   bss_bcd_chip: bin24_to_bcd port map (clk,'1',bss_cnt(23 downto 0),bss_cnt_bcd,bss_cnt_bcd_ready);
---------------------------------------------------

   msg1_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(16,8),
      y => conv_std_logic_vector(15,8),
      msg => string_to_std_logic_vector("RNS FILT"),
      char_x => msg1_char_x,
      char_y => msg1_char_y,
      char_code => msg1_char
   );
   
   msg2_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(24,8),
      y => conv_std_logic_vector(15,8),
      msg => string_to_std_logic_vector("ER SCORE"),
      char_x => msg2_char_x,
      char_y => msg2_char_y,
      char_code => msg2_char
   );

   msg3_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(36,8),
      y => conv_std_logic_vector(15,8),
      msg => string_to_std_logic_vector("BSS FILT"),
      char_x => msg3_char_x,
      char_y => msg3_char_y,
      char_code => msg3_char
   );

   msg4_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(44,8),
      y => conv_std_logic_vector(15,8),
      msg => string_to_std_logic_vector("ER SCORE"),
      char_x => msg4_char_x,
      char_y => msg4_char_y,
      char_code => msg4_char
   );
---------------------------------------------------

   msg5_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(25,8),
      y => conv_std_logic_vector(0,8),
      msg => string_to_std_logic_vector("DIGITAL "),
      char_x => msg5_char_x,
      char_y => msg5_char_y,
      char_code => msg5_char
   );

   msg6_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(35,8),
      y => conv_std_logic_vector(0,8),
      msg => string_to_std_logic_vector("FILTERS "),
      char_x => msg6_char_x,
      char_y => msg6_char_y,
      char_code => msg6_char
   );

---------------------------------------------------

   msg7_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(4,8),
      y => conv_std_logic_vector(4,8),
      msg =>k1_log & conv_std_logic_vector(32,8) & k2_log & conv_std_logic_vector(32,8) & k3_log,
      char_x => msg7_char_x,
      char_y => msg7_char_y,
      char_code => msg7_char
   );
         
   msg8_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(4,8),
      y => conv_std_logic_vector(5,8),
      msg =>k4_log & conv_std_logic_vector(32,8) & k5_log & conv_std_logic_vector(32,8) & k6_log,
      char_x => msg8_char_x,
      char_y => msg8_char_y,
      char_code => msg8_char
   );

   msg9_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(4,8),
      y => conv_std_logic_vector(6,8),
      msg =>k7_log & conv_std_logic_vector(32,8) & k8_log & conv_std_logic_vector(32,8) & k9_log,
      char_x => msg9_char_x,
      char_y => msg9_char_y,
      char_code => msg9_char
   );

   msg10_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(4,8),
      y => conv_std_logic_vector(8,8),
      msg =>
         string_to_std_logic_vector("DIV     ")(63 downto 32) &
         bcd32_to_std_logic_vector(pow2_div_bcd)(23 downto 0) &
         conv_std_logic_vector(0,8),
      char_x => msg10_char_x,
      char_y => msg10_char_y,
      char_code => msg10_char
   );

---------------------------------------------------
   msg11_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(20,8),
      y => conv_std_logic_vector(16,8),
      msg => bcd32_to_std_logic_vector(rns_cnt_bcd),
      char_x => msg11_char_x,
      char_y => msg11_char_y,
      char_code => msg11_char
   );

   msg12_chip: msg_box
   port map (
      clk => clk,
      x => conv_std_logic_vector(40,8),
      y => conv_std_logic_vector(16,8),
      msg => bcd32_to_std_logic_vector(bss_cnt_bcd),
      char_x => msg12_char_x,
      char_y => msg12_char_y,
      char_code => msg12_char
   );
---------------------------------------------------

   process (clk)
   begin
      if rising_edge(clk) then
         if msg_fsm=0 then
            msg_char_x<=msg1_char_x(6 downto 0);
            msg_char_y<=msg1_char_y(4 downto 0);
            msg_char<=msg1_char;
         end if;
         if msg_fsm=8 then
            msg_char_x<=msg2_char_x(6 downto 0);
            msg_char_y<=msg2_char_y(4 downto 0);
            msg_char<=msg2_char;
         end if;
         if msg_fsm=16 then
            msg_char_x<=msg3_char_x(6 downto 0);
            msg_char_y<=msg3_char_y(4 downto 0);
            msg_char<=msg3_char;
         end if;
         if msg_fsm=24 then
            msg_char_x<=msg4_char_x(6 downto 0);
            msg_char_y<=msg4_char_y(4 downto 0);
            msg_char<=msg4_char;
         end if;
         if msg_fsm=32 then
            msg_char_x<=msg5_char_x(6 downto 0);
            msg_char_y<=msg5_char_y(4 downto 0);
            msg_char<=msg5_char;
         end if;
         if msg_fsm=40 then
            msg_char_x<=msg6_char_x(6 downto 0);
            msg_char_y<=msg6_char_y(4 downto 0);
            msg_char<=msg6_char;
         end if;
         if msg_fsm=48 then
            msg_char_x<=msg7_char_x(6 downto 0);
            msg_char_y<=msg7_char_y(4 downto 0);
            msg_char<=msg7_char;
         end if;
         if msg_fsm=56 then
            msg_char_x<=msg8_char_x(6 downto 0);
            msg_char_y<=msg8_char_y(4 downto 0);
            msg_char<=msg8_char;
         end if;
         if msg_fsm=64 then
            msg_char_x<=msg9_char_x(6 downto 0);
            msg_char_y<=msg9_char_y(4 downto 0);
            msg_char<=msg9_char;
         end if;
         if msg_fsm=72 then
            msg_char_x<=msg10_char_x(6 downto 0);
            msg_char_y<=msg10_char_y(4 downto 0);
            msg_char<=msg10_char;
         end if;
         if msg_fsm=80 then
            msg_char_x<=msg11_char_x(6 downto 0);
            msg_char_y<=msg11_char_y(4 downto 0);
            msg_char<=msg11_char;
         end if;
         if msg_fsm=88 then
            msg_char_x<=msg12_char_x(6 downto 0);
            msg_char_y<=msg12_char_y(4 downto 0);
            msg_char<=msg12_char;
         end if;

         if msg_fsm=96 then msg_fsm<=0; else msg_fsm<=msg_fsm+1; end if;
      end if;
   end process;

end Behavioral;