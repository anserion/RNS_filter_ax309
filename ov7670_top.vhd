------------------------------------------------------------------
--Copyright 2017 Andrey S. Ionisyan (anserion@gmail.com)
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
-- Description: Top level for the OV7670 camera project (Alinx AX309 board).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ov7670_top is
    Port ( 
		clk50_ucf    : in    STD_LOGIC;

      Sdram_CLK_ucf: out STD_LOGIC; 
      Sdram_CKE_ucf: out STD_LOGIC;
      Sdram_NCS_ucf: out STD_LOGIC;
      Sdram_NWE_ucf: out STD_LOGIC;
      Sdram_NCAS_ucf: out STD_LOGIC;
      Sdram_NRAS_ucf: out STD_LOGIC;
      Sdram_DQM_ucf: out STD_LOGIC_VECTOR(1 downto 0);
      Sdram_BA_ucf: out STD_LOGIC_VECTOR(1 downto 0);
      Sdram_A_ucf: out STD_LOGIC_VECTOR(12 downto 0);
      Sdram_DB_ucf: inout STD_LOGIC_VECTOR(15 downto 0);

		OV7670_SIOC  : out   STD_LOGIC;
		OV7670_SIOD  : inout STD_LOGIC;
		OV7670_RESET : out   STD_LOGIC;
		OV7670_PWDN  : out   STD_LOGIC;
		OV7670_VSYNC : in    STD_LOGIC;
		OV7670_HREF  : in    STD_LOGIC;
		OV7670_PCLK  : in    STD_LOGIC;
		OV7670_XCLK  : out   STD_LOGIC;
		OV7670_D     : in    STD_LOGIC_VECTOR(7 downto 0);

		lcd_red      : out   STD_LOGIC_VECTOR(7 downto 0);
		lcd_green    : out   STD_LOGIC_VECTOR(7 downto 0);
		lcd_blue     : out   STD_LOGIC_VECTOR(7 downto 0);
		lcd_hsync    : out   STD_LOGIC;
		lcd_vsync    : out   STD_LOGIC;
      lcd_dclk     : out   STD_LOGIC;

		vga_red      : out STD_LOGIC_VECTOR(4 downto 0);
		vga_green    : out STD_LOGIC_VECTOR(5 downto 0);
		vga_blue     : out STD_LOGIC_VECTOR(4 downto 0);
		vga_hsync    : out STD_LOGIC;
		vga_vsync    : out STD_LOGIC;
		
		LED          : out   STD_LOGIC_VECTOR(3 downto 0);
		btn			 : in 	STD_LOGIC_VECTOR(3 downto 0);
		reset_n	    : in    STD_LOGIC
	 );
end ov7670_top;

architecture Behavioral of ov7670_top is
   component clocking_core
   port (
      CLK_50_in : in  std_logic;
      CLK_50    : out std_logic;
      CLK_100   : out std_logic;
      CLK_25    : out std_logic;
      CLK_10    : out std_logic;
      CLK_12_5  : out std_logic;
      CLK_4     : out std_logic
      );
   end component;

   COMPONENT vram_128x32_8bit
   PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
   );
   END COMPONENT;

   component sdram_controller
	generic (
				--memory frequency in MHz
				sdram_frequency	: integer := 100
				);
	port (
			--ready operation
			ready						: out std_logic;
			--clk
			clk						: in std_logic;
			--read interface
			rd_req					: in std_logic;
			rd_adr					: in std_logic_vector(23 downto 0);
			rd_data					: out std_logic_vector(15 downto 0);
			rd_valid					: out std_logic;
			--write interface
			wr_req					: in std_logic;
			wr_adr					: in std_logic_vector(23 downto 0);
			wr_data					: in std_logic_vector(15 downto 0);
			--SDRAM interface
			sdram_wren_n			: out std_logic := '1';
			sdram_cas_n				: out std_logic := '1';
			sdram_ras_n				: out std_logic := '1';
			sdram_a					: out std_logic_vector(12 downto 0);
			sdram_ba					: out std_logic_vector(1 downto 0);
			sdram_dqm				: out std_logic_vector(1 downto 0);
			sdram_dq					: inout std_logic_vector(15 downto 0);
			sdram_clk_n				: out std_logic
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

   component ov7670_capture is
    Port (
      en    : in std_logic;
      clk   : in std_logic;
      vsync : in std_logic;
		href  : in std_logic;
		din   : in std_logic_vector(7 downto 0);
      cam_x : out std_logic_vector(9 downto 0);
      cam_y : out std_logic_vector(9 downto 0);
      pixel : out std_logic_vector(15 downto 0);
      ready : out std_logic
		);
   end component;

   COMPONENT lcd_AN430
    Port ( 
      en      : in std_logic;
		clk     : in  STD_LOGIC;
		red     : out STD_LOGIC_VECTOR(7 downto 0);
		green   : out STD_LOGIC_VECTOR(7 downto 0);
		blue    : out STD_LOGIC_VECTOR(7 downto 0);
		hsync   : out STD_LOGIC;
		vsync   : out STD_LOGIC;
		de	     : out STD_LOGIC;
		x       : out STD_LOGIC_VECTOR(9 downto 0);
		y       : out STD_LOGIC_VECTOR(9 downto 0);
      dirty_x : out STD_LOGIC_VECTOR(9 downto 0);
      dirty_y : out STD_LOGIC_VECTOR(9 downto 0);
      pixel   : in STD_LOGIC_VECTOR(23 downto 0);
		char_x    : out STD_LOGIC_VECTOR(6 downto 0);
		char_y	 : out STD_LOGIC_VECTOR(4 downto 0);
		char_code : in  STD_LOGIC_VECTOR(7 downto 0)
	 );
	END COMPONENT;

   COMPONENT vga
    Port (
      en    : in std_logic;
		clk   : in  STD_LOGIC;
		red   : out STD_LOGIC_VECTOR(4 downto 0);
		green : out STD_LOGIC_VECTOR(5 downto 0);
		blue  : out STD_LOGIC_VECTOR(4 downto 0);
		hsync : out STD_LOGIC;
		vsync : out STD_LOGIC;
      de    : out STD_LOGIC;
		x     : out STD_LOGIC_VECTOR(9 downto 0);
		y     : out STD_LOGIC_VECTOR(9 downto 0);
      dirty_x : out STD_LOGIC_VECTOR(9 downto 0);
      dirty_y : out STD_LOGIC_VECTOR(9 downto 0);
      pixel :  in STD_LOGIC_VECTOR(15 downto 0);
		char_x    : out STD_LOGIC_VECTOR(6 downto 0);
		char_y	 : out STD_LOGIC_VECTOR(4 downto 0);
		char_code : in  STD_LOGIC_VECTOR(7 downto 0)
	 );
   END COMPONENT;

   component msg_center is
    Port ( 
		clk        : in  STD_LOGIC;
      en         : in std_logic;
      filter1_cnt: in std_logic_vector(23 downto 0);
      filter2_cnt: in std_logic_vector(23 downto 0);
      capture_en : in std_logic;
		msg_char_x : out STD_LOGIC_VECTOR(6 downto 0);
		msg_char_y : out STD_LOGIC_VECTOR(4 downto 0);
		msg_char   : out STD_LOGIC_VECTOR(7 downto 0)
	 );
   end component;

   component sdram_supervisor is
   generic(
      filter1_x_min: natural range 0 to 1023 := 128;
      filter1_y_min: natural range 0 to 1023 := 16;
      filter1_x_max: natural range 0 to 1023 := 255;
      filter1_y_max: natural range 0 to 1023 := 248;

      filter2_x_min: natural range 0 to 1023 := 256;
      filter2_y_min: natural range 0 to 1023 := 16;
      filter2_x_max: natural range 0 to 1023 := 384;
      filter2_y_max: natural range 0 to 1023 := 248
   );
   Port ( 
      clk : in std_logic;
      en  : in std_logic;
      vga_en    : in std_logic;
      lcd_en    : in std_logic;
      cam_en    : in std_logic;
      filter1_en              : in std_logic;
      filter2_en              : in std_logic;

      sdram_rd_req   : out std_logic; 
      sdram_rd_valid : in std_logic;
      sdram_wr_req   : out std_logic;
      sdram_rd_addr  : out std_logic_vector(23 downto 0);
      sdram_wr_addr  : out std_logic_vector(23 downto 0);
      sdram_rd_data  : in std_logic_vector(15 downto 0);
      sdram_wr_data  : out std_logic_vector(15 downto 0);

      vga_width : in std_logic_vector(9 downto 0);
      vga_y     : in std_logic_vector(9 downto 0);
      vga_vsync : in std_logic;
      vga_wr_en : out std_logic;
      vga_wr_addr: out std_logic_vector(9 downto 0);
      vga_wr_data: out std_logic_vector(15 downto 0);

      lcd_width : in std_logic_vector(9 downto 0);
      lcd_y     : in std_logic_vector(9 downto 0);
      lcd_vsync : in std_logic;
      lcd_wr_en : out std_logic;
      lcd_wr_addr: out std_logic_vector(9 downto 0);
      lcd_wr_data: out std_logic_vector(15 downto 0);

      filter1_scanline_ask    : in std_logic;
      filter1_scanline_ack    : out std_logic;
      filter1_scanline_ready  : out std_logic;
      filter1_scanline_wr_addr: out std_logic_vector(9 downto 0);
      filter1_scanline_y      : in std_logic_vector(9 downto 0);
      filter1_scanline_wr_data: out std_logic_vector(15 downto 0);
      filter1_scanline_we     : out std_logic;

      filter2_scanline_ask    : in std_logic;
      filter2_scanline_ack    : out std_logic;
      filter2_scanline_ready  : out std_logic;
      filter2_scanline_wr_addr: out std_logic_vector(9 downto 0);
      filter2_scanline_y      : in std_logic_vector(9 downto 0);
      filter2_scanline_wr_data: out std_logic_vector(15 downto 0);
      filter2_scanline_we     : out std_logic;
      
      cam_width : in std_logic_vector(9 downto 0);
      cam_y     : in std_logic_vector(9 downto 0);
      cam_rd_addr  : out std_logic_vector(9 downto 0);
      cam_rd_data0 : in std_logic_vector(15 downto 0);
      cam_rd_data1 : in std_logic_vector(15 downto 0);

      filter1_res_y       : in std_logic_vector(9 downto 0);
      filter1_res_rd_addr : out std_logic_vector(9 downto 0);
      filter1_res_rd_data0: in std_logic_vector(15 downto 0);
      filter1_res_rd_data1: in std_logic_vector(15 downto 0);
      
      filter2_res_y       : in std_logic_vector(9 downto 0);
      filter2_res_rd_addr : out std_logic_vector(9 downto 0);
      filter2_res_rd_data0: in std_logic_vector(15 downto 0);
      filter2_res_rd_data1: in std_logic_vector(15 downto 0)
	);
   end component;

   component filter_bss_supervisor is
   generic (
      x_min : natural range 0 to 1023 := 0;
      y_min : natural range 0 to 1023 := 0;
      x_max : natural range 0 to 1023 := 639;
      y_max : natural range 0 to 1023 := 479;
		k1: integer :=0;
		k2: integer :=0;
		k3: integer :=0;
		k4: integer :=0;
		k5: integer :=1;
		k6: integer :=0;
		k7: integer :=0;
		k8: integer :=0;
		k9: integer :=0;
		pow2_divider: integer :=0
      );
    Port ( 
      clk : in std_logic;
      en  : in std_logic;
      reset_cnt : in std_logic;
      filter_res_y   : out std_logic_vector(9 downto 0);
      filter_res_addr   : out std_logic_vector(9 downto 0);
      filter_res_data   : out std_logic_vector(15 downto 0);
      filter_scanline_y   : out std_logic_vector(9 downto 0);
      filter_scanline_ask    : out std_logic;
      filter_scanline_ack    : in std_logic;
      filter_scanline_ready  : in std_logic;
      filter_scanline_addr   : out std_logic_vector(9 downto 0);
      filter_scanline_data   : in std_logic_vector(15 downto 0);
      filter_cnt : out std_logic_vector(23 downto 0)
      );
   end component;

   component filter_rns_supervisor is
   generic (
      x_min : natural range 0 to 1023 := 0;
      y_min : natural range 0 to 1023 := 0;
      x_max : natural range 0 to 1023 := 639;
      y_max : natural range 0 to 1023 := 479;
		k1: integer :=0;
		k2: integer :=0;
		k3: integer :=0;
		k4: integer :=0;
		k5: integer :=1;
		k6: integer :=0;
		k7: integer :=0;
		k8: integer :=0;
		k9: integer :=0;
		pow2_divider: integer :=0
      );
    Port ( 
      clk : in std_logic;
      en  : in std_logic;
      reset_cnt : in std_logic;
      filter_res_y   : out std_logic_vector(9 downto 0);
      filter_res_addr   : out std_logic_vector(9 downto 0);
      filter_res_data   : out std_logic_vector(15 downto 0);
      filter_scanline_y   : out std_logic_vector(9 downto 0);
      filter_scanline_ask    : out std_logic;
      filter_scanline_ack    : in std_logic;
      filter_scanline_ready  : in std_logic;
      filter_scanline_addr   : out std_logic_vector(9 downto 0);
      filter_scanline_data   : in std_logic_vector(15 downto 0);
      filter_cnt : out std_logic_vector(23 downto 0)
      );
   end component;
   
   signal msg_char_x: std_logic_vector(6 downto 0);
   signal msg_char_y: std_logic_vector(4 downto 0);
   signal msg_char: std_logic_vector(7 downto 0);
   
   signal vga_en    : std_logic := '1';
   signal vga_de    : std_logic := '0';
	signal vga_reg_hsync: STD_LOGIC :='1';
	signal vga_reg_vsync: STD_LOGIC :='1';
   signal vga_x     : std_logic_vector(9 downto 0) := (others => '0');
   signal vga_y     : std_logic_vector(9 downto 0) := (others => '0');
   signal vga_dirty_x: std_logic_vector(9 downto 0) := (others => '0');
   signal vga_dirty_y: std_logic_vector(9 downto 0) := (others => '0');	
   signal vga_pixel : std_logic_vector(15 downto 0) := (others => '0');	
   signal vga_char_x: std_logic_vector(6 downto 0) := (others => '0');
	signal vga_char_y: std_logic_vector(4 downto 0) := (others => '0');
   signal vga_char  : std_logic_vector(7 downto 0);
   signal vga_scanline_wea   : std_logic_vector(0 downto 0);
   signal vga_scanline_wr_addr: std_logic_vector(9 downto 0);
   signal vga_scanline_wr_data: std_logic_vector(15 downto 0);
   
	signal lcd_en    : std_logic := '1';
	signal lcd_de    : std_logic :='0';
	signal lcd_reg_hsync: STD_LOGIC :='1';
	signal lcd_reg_vsync: STD_LOGIC :='1';
   signal lcd_x     : std_logic_vector(9 downto 0) := (others => '0');
   signal lcd_y     : std_logic_vector(9 downto 0) := (others => '0');
   signal lcd_dirty_x: std_logic_vector(9 downto 0) := (others => '0');
   signal lcd_dirty_y: std_logic_vector(9 downto 0) := (others => '0');	
   signal lcd_pixel : std_logic_vector(23 downto 0) := (others => '0');	
	signal lcd_char_x: std_logic_vector(6 downto 0) := (others => '0');
	signal lcd_char_y: std_logic_vector(4 downto 0) := (others => '0');
   signal lcd_char  : std_logic_vector(7 downto 0);
   signal lcd_scanline_wea   : std_logic_vector(0 downto 0);
   signal lcd_scanline_wr_addr: std_logic_vector(9 downto 0);
   signal lcd_scanline_wr_data: std_logic_vector(15 downto 0);

   signal cam_en       : std_logic := '1';
   signal cam_pixel_ready: std_logic := '0';
   signal cam_y        : std_logic_vector(9 downto 0):=(others=>'0');
   signal cam_wr_addr  : std_logic_vector(9 downto 0):=(others=>'0');
   signal cam_wr_data  : std_logic_vector(15 downto 0):=(others=>'0');
   signal cam_rd_addr  : std_logic_vector(9 downto 0):=(others=>'0');
   signal cam_rd_data0 : std_logic_vector(15 downto 0):=(others=>'0');
   signal cam_rd_data1 : std_logic_vector(15 downto 0):=(others=>'0');
   
   signal sdram_ready,sdram_rd_req,sdram_rd_valid,sdram_wr_req:std_logic:='0';
   signal sdram_rd_addr,sdram_wr_addr:std_logic_vector(23 downto 0);
   signal sdram_rd_data,sdram_wr_data:std_logic_vector(15 downto 0);

   signal filter1_cnt  : std_logic_vector(23 downto 0);
   signal filter2_cnt  : std_logic_vector(23 downto 0);
   signal filter1_cnt_reset: std_logic:='0';
   signal filter2_cnt_reset: std_logic:='0';
   
   signal filter1_res_y : std_logic_vector(9 downto 0):=(others=>'0');
   signal filter1_res_rd_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter1_res_wr_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter1_res_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal filter1_res_rd_data0: std_logic_vector(15 downto 0):=(others=>'0');
   signal filter1_res_rd_data1: std_logic_vector(15 downto 0):=(others=>'0');

   signal filter1_scanline_ask    : std_logic:='0';
   signal filter1_scanline_ack    : std_logic:='0';
   signal filter1_scanline_ready  : std_logic:='0';
   signal filter1_scanline_rd_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter1_scanline_wr_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter1_scanline_y      : std_logic_vector(9 downto 0):=(others=>'0');
   signal filter1_scanline_wea    : std_logic_vector(0 downto 0):=(others=>'0');
   signal filter1_scanline_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal filter1_scanline_rd_data: std_logic_vector(15 downto 0):=(others=>'0');

   signal filter2_res_y : std_logic_vector(9 downto 0):=(others=>'0');
   signal filter2_res_rd_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter2_res_wr_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter2_res_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal filter2_res_rd_data0: std_logic_vector(15 downto 0):=(others=>'0');
   signal filter2_res_rd_data1: std_logic_vector(15 downto 0):=(others=>'0');
   
   signal filter2_scanline_ask    : std_logic:='0';
   signal filter2_scanline_ack    : std_logic:='0';
   signal filter2_scanline_ready  : std_logic:='0';
   signal filter2_scanline_rd_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter2_scanline_wr_addr: std_logic_vector(9 downto 0):=(others=>'0');
   signal filter2_scanline_y      : std_logic_vector(9 downto 0):=(others=>'0');
   signal filter2_scanline_wea    : std_logic_vector(0 downto 0):=(others=>'0');
   signal filter2_scanline_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal filter2_scanline_rd_data: std_logic_vector(15 downto 0):=(others=>'0');

   signal filter1_en   : std_logic := '0';
   signal filter2_en   : std_logic := '0';
   constant filter1_x_min: natural range 0 to 1023 := 128;
   constant filter1_y_min: natural range 0 to 1023 := 16;
   constant filter1_x_max: natural range 0 to 1023 := 255;
   constant filter1_y_max: natural range 0 to 1023 := 248;

   constant filter2_x_min: natural range 0 to 1023 := 257;
   constant filter2_y_min: natural range 0 to 1023 := 16;
   constant filter2_x_max: natural range 0 to 1023 := 384;
   constant filter2_y_max: natural range 0 to 1023 := 248;
   
   signal sdram_clk    : std_logic;
   signal lcd_clk      : std_logic;
	signal cam_clk      : std_logic;
   signal cam_clk_div2 : std_logic;
   signal vga_clk      : std_logic;
   signal msg_clk      : std_logic;
   signal filter1_clk  : std_logic;
   signal filter2_clk  : std_logic;

   signal clk100      : std_logic;
	signal clk50       : std_logic;
	signal clk25       : std_logic;
	signal clk10       : std_logic;
   signal clk12_5     : std_logic;
	signal clk4        : std_logic;

   signal filter_ram_data: std_logic_vector(23 downto 0);
begin
   clocking_chip : clocking_core
   PORT MAP (
      CLK_50_in => CLK50_ucf,
      CLK_100 =>CLK100,
      CLK_50 => CLK50,
      CLK_25 => CLK25,
      CLK_10 => CLK10,
		CLK_12_5=> CLK12_5,
		CLK_4 => CLK4
      );
      
	cam_clk<=clk25;
   cam_clk_div2<=clk12_5;
	lcd_clk<=clk4;
	lcd_dclk<=lcd_clk;
   sdram_clk<=clk100;
   vga_clk<=clk25;
   msg_clk<=clk10;
   filter1_clk<=clk25 when btn(3)='1' else clk100;
   filter2_clk<=clk25 when btn(3)='1' else clk100;
---------------------------------------------------
   
   led(0)<=not(btn(0));
   led(1)<=not(btn(1));
   led(2)<=not(btn(2));
   led(3)<=not(btn(3));
   
   vga_en<=btn(0);
   lcd_en<='1';--btn(3);
   filter1_en<=btn(1);
   filter2_en<=btn(1);
   cam_en<=btn(2);
   filter1_cnt_reset<=not(reset_n);
   filter2_cnt_reset<=not(reset_n);
   
   vga_hsync<=vga_reg_hsync;
   vga_vsync<=vga_reg_vsync;
   lcd_hsync<=lcd_reg_hsync;
   lcd_vsync<=lcd_reg_vsync;
---------------------------------------------------
   ch_lcd_chip : vram_128x32_8bit
   PORT MAP (
    clka => msg_clk,
    wea => (others=>'1'),
    addra => msg_char_y & msg_char_x,
    dina => msg_char,
    clkb => lcd_clk,
    addrb => lcd_char_y & lcd_char_x,
    doutb => lcd_char
   );

   ch_vga_chip : vram_128x32_8bit
   PORT MAP (
    clka => msg_clk,
    wea => (others=>'1'),
    addra => msg_char_y & msg_char_x,
    dina => msg_char,
    clkb => vga_clk,
    addrb => vga_char_y & vga_char_x,
    doutb => vga_char
   );
   
   msg_center_chip: msg_center port map (msg_clk,'1',filter1_cnt,filter2_cnt,cam_en,
                                          msg_char_x,msg_char_y,msg_char);


---------------------------------------------------
   filter1_scanline : vram_scanline
   PORT MAP (
    clka  => sdram_clk,
    wea   => filter1_scanline_wea,
    addra => filter1_scanline_wr_addr,
    dina  => filter1_scanline_wr_data,
    clkb  => filter1_clk,
    addrb => filter1_scanline_rd_addr,
    doutb => filter1_scanline_rd_data
   );

   filter1_res_scanline0 : vram_scanline
   PORT MAP (
    clka  => filter1_clk,
    wea   => (0=>filter1_res_y(0)),
    addra => filter1_res_wr_addr,
    dina  => filter1_res_wr_data,
    clkb  => sdram_clk,
    addrb => filter1_res_rd_addr,
    doutb => filter1_res_rd_data0
   );

   filter1_res_scanline1 : vram_scanline
   PORT MAP (
    clka  => filter1_clk,
    wea   => (0=>not(filter1_res_y(0))),
    addra => filter1_res_wr_addr,
    dina  => filter1_res_wr_data,
    clkb  => sdram_clk,
    addrb => filter1_res_rd_addr,
    doutb => filter1_res_rd_data1
   );
   
   filter_rns_supervisor_chip: filter_rns_supervisor 
   generic map (
      x_min => filter1_x_min,
      y_min => filter1_y_min,
      x_max => filter1_x_max,
      y_max => filter1_y_max,
		k1=> 52079, k2=> 52079, k3=> 52079,
      k4=> 52079, k5=> 8, k6=> 52079,
      k7=> 52079, k8=> 52079, k9=> 52079,
		pow2_divider=>0
      )
    Port map ( 
      clk => filter1_clk,
      en  => filter1_en,
      reset_cnt => filter1_cnt_reset,
      filter_res_y     => filter1_res_y,
      filter_res_addr  => filter1_res_wr_addr,
      filter_res_data  => filter1_res_wr_data,
      filter_scanline_y     => filter1_scanline_y,
      filter_scanline_ask   => filter1_scanline_ask,
      filter_scanline_ack   => filter1_scanline_ack,
      filter_scanline_ready => filter1_scanline_ready,
      filter_scanline_addr  => filter1_scanline_rd_addr,
      filter_scanline_data  => filter1_scanline_rd_data,
      filter_cnt => filter1_cnt
    );
   
   filter2_scanline : vram_scanline
   PORT MAP (
    clka  => sdram_clk,
    wea   => filter2_scanline_wea,
    addra => filter2_scanline_wr_addr,
    dina  => filter2_scanline_wr_data,
    clkb  => filter2_clk,
    addrb => filter2_scanline_rd_addr,
    doutb => filter2_scanline_rd_data
   );

   filter2_res_scanline0 : vram_scanline
   PORT MAP (
    clka  => filter2_clk,
    wea   => (0=>filter2_res_y(0)),
    addra => filter2_res_wr_addr,
    dina  => filter2_res_wr_data,
    clkb  => sdram_clk,
    addrb => filter2_res_rd_addr,
    doutb => filter2_res_rd_data0
   );

   filter2_res_scanline1 : vram_scanline
   PORT MAP (
    clka  => filter2_clk,
    wea   => (0=>not(filter2_res_y(0))),
    addra => filter2_res_wr_addr,
    dina  => filter2_res_wr_data,
    clkb  => sdram_clk,
    addrb => filter2_res_rd_addr,
    doutb => filter2_res_rd_data1
   );

   
   filter_bss_supervisor_chip: filter_bss_supervisor 
   generic map (
      x_min => filter2_x_min,
      y_min => filter2_y_min,
      x_max => filter2_x_max,
      y_max => filter2_y_max,
		k1=> -1, k2=> -1, k3=> -1,
      k4=> -1, k5=> 8, k6=> -1,
      k7=> -1, k8=> -1, k9=> -1,
		pow2_divider=>0
      )
    Port map ( 
      clk => filter2_clk,
      en  => filter2_en,
      reset_cnt => filter2_cnt_reset,
      filter_res_y     => filter2_res_y,
      filter_res_addr  => filter2_res_wr_addr,
      filter_res_data  => filter2_res_wr_data,
      filter_scanline_y     => filter2_scanline_y,
      filter_scanline_ask   => filter2_scanline_ask,
      filter_scanline_ack   => filter2_scanline_ack,
      filter_scanline_ready => filter2_scanline_ready,
      filter_scanline_addr  => filter2_scanline_rd_addr,
      filter_scanline_data  => filter2_scanline_rd_data,
      filter_cnt => filter2_cnt
    );

---------------------------------------------------

   sdram_CKE_ucf<='1'; --sdram chip clock always turn on
   sdram_NCS_ucf<='0'; --sdram chip always selected (zero active level)
   SDRAM_chip: sdram_controller generic map (100)
                   port map (
                             sdram_ready, sdram_clk,
                             sdram_rd_req, sdram_rd_addr, sdram_rd_data, sdram_rd_valid,
                             sdram_wr_req, sdram_wr_addr, sdram_wr_data,
                             sdram_nwe_ucf, sdram_ncas_ucf, sdram_nras_ucf,
                             sdram_a_ucf, sdram_ba_ucf, sdram_dqm_ucf, sdram_db_ucf,
                             sdram_clk_ucf
                             );
---------------------------------------------------
   sdram_supervisor_chip: sdram_supervisor
   generic map(
      filter1_x_min => filter1_x_min,
      filter1_y_min => filter1_y_min,
      filter1_x_max => filter1_x_max,
      filter1_y_max => filter1_y_max,

      filter2_x_min => filter2_x_min,
      filter2_y_min => filter2_y_min,
      filter2_x_max => filter2_x_max,
      filter2_y_max => filter2_y_max
   )
   Port map( 
      clk => sdram_clk,
      en  => sdram_ready,
      vga_en      => vga_en,
      lcd_en      => lcd_en,
      cam_en      => cam_en,
      filter1_en  => filter1_en,
      filter2_en  => filter2_en,

      sdram_rd_req   => sdram_rd_req,
      sdram_rd_valid => sdram_rd_valid,
      sdram_wr_req   => sdram_wr_req,
      sdram_rd_addr  => sdram_rd_addr,
      sdram_wr_addr  => sdram_wr_addr,
      sdram_rd_data  => sdram_rd_data,
      sdram_wr_data  => sdram_wr_data,

      vga_width   => conv_std_logic_vector(640,10),
      vga_y       => vga_y,
      vga_vsync   => vga_reg_vsync,
      vga_wr_en   => vga_scanline_wea(0),
      vga_wr_addr => vga_scanline_wr_addr,
      vga_wr_data => vga_scanline_wr_data,

      lcd_width   => conv_std_logic_vector(480,10),
      lcd_y       => lcd_y,
      lcd_vsync   => lcd_reg_vsync,
      lcd_wr_en   => lcd_scanline_wea(0),
      lcd_wr_addr => lcd_scanline_wr_addr,
      lcd_wr_data => lcd_scanline_wr_data,
      
      filter1_scanline_ask     => filter1_scanline_ask,
      filter1_scanline_ack     => filter1_scanline_ack,
      filter1_scanline_ready   => filter1_scanline_ready,
      filter1_scanline_wr_addr => filter1_scanline_wr_addr,
      filter1_scanline_y       => filter1_scanline_y,
      filter1_scanline_wr_data => filter1_scanline_wr_data,
      filter1_scanline_we      => filter1_scanline_wea(0),

      filter2_scanline_ask     => filter2_scanline_ask,
      filter2_scanline_ack     => filter2_scanline_ack,
      filter2_scanline_ready   => filter2_scanline_ready,
      filter2_scanline_wr_addr => filter2_scanline_wr_addr,
      filter2_scanline_y       => filter2_scanline_y,
      filter2_scanline_wr_data => filter2_scanline_wr_data,
      filter2_scanline_we      => filter2_scanline_wea(0),
      
      cam_width    => conv_std_logic_vector(640,10),
      cam_y        => cam_y,
      cam_rd_addr  => cam_rd_addr,
      cam_rd_data0 => cam_rd_data0,
      cam_rd_data1 => cam_rd_data1,

      filter1_res_y       => filter1_res_y,
      filter1_res_rd_addr => filter1_res_rd_addr,
      filter1_res_rd_data0 => filter1_res_rd_data0,
      filter1_res_rd_data1 => filter1_res_rd_data1,
      
      filter2_res_y       => filter2_res_y,
      filter2_res_rd_addr => filter2_res_rd_addr,
      filter2_res_rd_data0 => filter2_res_rd_data0,
      filter2_res_rd_data1 => filter2_res_rd_data1
	);
   
---------------------------------------------------

   lcd_pixel(23 downto 16)<=(others=>'0');
   lcd_scanline : vram_scanline
   PORT MAP (
    clka  => sdram_clk,
    wea   => lcd_scanline_wea,
    addra => lcd_scanline_wr_addr,
    dina  => lcd_scanline_wr_data,
    clkb  => lcd_clk,
    addrb => lcd_x,
    doutb => lcd_pixel(15 downto 0)
   );
   
   lcd_pixel(23 downto 16)<=(others=>'0');
   lcd_AN430_chip: lcd_AN430 PORT MAP(
      en    => lcd_en,
		clk   => lcd_clk,
		red   => lcd_red,
		green => lcd_green,
		blue  => lcd_blue,
		hsync => lcd_reg_hsync,
		vsync => lcd_reg_vsync,
		de	   => lcd_de,
		x     => lcd_x,
		y     => lcd_y,
      dirty_x=>lcd_dirty_x,
      dirty_y=>lcd_dirty_y,
      pixel => lcd_pixel,
		char_x=> lcd_char_x,
		char_y=> lcd_char_y,
		char_code  => lcd_char
      );
---------------------------------------------------

   vga_scanline : vram_scanline
   PORT MAP (
    clka  => sdram_clk,
    wea   => vga_scanline_wea,
    addra => vga_scanline_wr_addr,
    dina  => vga_scanline_wr_data,
    clkb  => vga_clk,
    addrb => vga_x,
    doutb => vga_pixel
   );

	vga_640x480_chip: vga PORT MAP(
      en    => vga_en,
		clk   => vga_clk,
		red   => vga_red,
		green => vga_green,
		blue  => vga_blue,
		hsync => vga_reg_hsync,
		vsync => vga_reg_vsync,
      de    => vga_de,
		x     => vga_x,
		y     => vga_y,
      dirty_x=>vga_dirty_x,
      dirty_y=>vga_dirty_y,
		pixel => vga_pixel,
		char_x=> vga_char_x,
		char_y=> vga_char_y,
		char_code  => vga_char
      );
---------------------------------------------------
   cam_scanline0 : vram_scanline
   PORT MAP (
    clka  => cam_clk_div2,
    wea   => (0=>cam_y(0)),
    addra => cam_wr_addr,
    dina  => cam_wr_data,
    clkb  => sdram_clk,
    addrb => cam_rd_addr,
    doutb => cam_rd_data0
   );

   cam_scanline1 : vram_scanline
   PORT MAP (
    clka  => cam_clk_div2,
    wea   => (0=> not(cam_y(0))),
    addra => cam_wr_addr,
    dina  => cam_wr_data,
    clkb  => sdram_clk,
    addrb => cam_rd_addr,
    doutb => cam_rd_data1
   );
   
   --minimal OV7670 grayscale mode
   OV7670_PWDN  <= '0'; --0 - power on
   OV7670_RESET <= '1'; --0 -activate reset
   OV7670_XCLK  <= cam_clk;
   ov7670_siod  <= 'Z';
   ov7670_sioc  <= '0';
   
   capture: ov7670_capture PORT MAP(
      en    => cam_en,
		clk   => OV7670_PCLK,
		vsync => OV7670_VSYNC,
		href  => OV7670_HREF,
		din    => OV7670_D,
      cam_x =>cam_wr_addr,
      cam_y =>cam_y,
      pixel =>cam_wr_data,
		ready =>cam_pixel_ready
      );
end Behavioral;
