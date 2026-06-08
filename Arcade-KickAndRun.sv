//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
  //Master input clock
  input         CLK_50M,

  //Async reset from top-level module.
  //Can be used as initial reset.
  input         RESET,

  //Must be passed to hps_io module
  inout  [48:0] HPS_BUS,

  //Base video clock. Usually equals to CLK_SYS.
  output        CLK_VIDEO,

  //Multiple resolutions are supported using different CE_PIXEL rates.
  //Must be based on CLK_VIDEO
  output        CE_PIXEL,

  //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
  //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
  output [12:0] VIDEO_ARX,
  output [12:0] VIDEO_ARY,

  output  [7:0] VGA_R,
  output  [7:0] VGA_G,
  output  [7:0] VGA_B,
  output        VGA_HS,
  output        VGA_VS,
  output        VGA_DE,    // = ~(VBlank | HBlank)
  output        VGA_F1,
  output [1:0]  VGA_SL,
  output        VGA_SCALER, // Force VGA scaler
  output        VGA_DISABLE, // analog out is off

  input  [11:0] HDMI_WIDTH,
  input  [11:0] HDMI_HEIGHT,
  output        HDMI_FREEZE,

`ifdef MISTER_FB
  // Use framebuffer in DDRAM
  // FB_FORMAT:
  //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
  //    [3]   : 0=16bits 565 1=16bits 1555
  //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
  //
  // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
  output        FB_EN,
  output  [4:0] FB_FORMAT,
  output [11:0] FB_WIDTH,
  output [11:0] FB_HEIGHT,
  output [31:0] FB_BASE,
  output [13:0] FB_STRIDE,
  input         FB_VBL,
  input         FB_LL,
  output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
  // Palette control for 8bit modes.
  // Ignored for other video modes.
  output        FB_PAL_CLK,
  output  [7:0] FB_PAL_ADDR,
  output [23:0] FB_PAL_DOUT,
  input  [23:0] FB_PAL_DIN,
  output        FB_PAL_WR,
`endif
`endif

  output        LED_USER,  // 1 - ON, 0 - OFF.

  // b[1]: 0 - LED status is system status OR'd with b[0]
  //       1 - LED status is controled solely by b[0]
  // hint: supply 2'b00 to let the system control the LED.
  output  [1:0] LED_POWER,
  output  [1:0] LED_DISK,

  // I/O board button press simulation (active high)
  // b[1]: user button
  // b[0]: osd button
  output  [1:0] BUTTONS,

  input         CLK_AUDIO, // 24.576 MHz
  output [15:0] AUDIO_L,
  output [15:0] AUDIO_R,
  output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
  output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

  //ADC
  inout   [3:0] ADC_BUS,

  //SD-SPI
  output        SD_SCK,
  output        SD_MOSI,
  input         SD_MISO,
  output        SD_CS,
  input         SD_CD,

  //High latency DDR3 RAM interface
  //Use for non-critical time purposes
  output        DDRAM_CLK,
  input         DDRAM_BUSY,
  output  [7:0] DDRAM_BURSTCNT,
  output [28:0] DDRAM_ADDR,
  input  [63:0] DDRAM_DOUT,
  input         DDRAM_DOUT_READY,
  output        DDRAM_RD,
  output [63:0] DDRAM_DIN,
  output  [7:0] DDRAM_BE,
  output        DDRAM_WE,

  //SDRAM interface with lower latency
  output        SDRAM_CLK,
  output        SDRAM_CKE,
  output [12:0] SDRAM_A,
  output  [1:0] SDRAM_BA,
  inout  [15:0] SDRAM_DQ,
  output        SDRAM_DQML,
  output        SDRAM_DQMH,
  output        SDRAM_nCS,
  output        SDRAM_nCAS,
  output        SDRAM_nRAS,
  output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
  //Secondary SDRAM
  //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
  input         SDRAM2_EN,
  output        SDRAM2_CLK,
  output [12:0] SDRAM2_A,
  output  [1:0] SDRAM2_BA,
  inout  [15:0] SDRAM2_DQ,
  output        SDRAM2_nCS,
  output        SDRAM2_nCAS,
  output        SDRAM2_nRAS,
  output        SDRAM2_nWE,
`endif

  input         UART_CTS,
  output        UART_RTS,
  input         UART_RXD,
  output        UART_TXD,
  output        UART_DTR,
  input         UART_DSR,

  // Open-drain User port.
  // 0 - D+/RX
  // 1 - D-/TX
  // 2..6 - USR2..USR6
  // Set USER_OUT to 1 to read from USER_IN.
  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + per-pin push-pull mask, USER_IO widened to 8 bits
  output        USER_OSD,
  output  [7:0] USER_PP,
  input   [7:0] USER_IN,
  output  [7:0] USER_OUT,
  // [MiSTer-DB9 END]

  input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP driven by wrapper; USER_OUT driven by joydb (USER_OUT_DRIVE) below
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

// assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

// assign AUDIO_S = 0;
// assign AUDIO_L = 0;
// assign AUDIO_R = 0;
// assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression. This core has no MT32, so 1'b0 is correct.
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;

// [MiSTer-DB9 BEGIN] - DB9 programmable-remap matrix wires
// joydb_*_mapped = MiSTer-standard joystick words (consumed in Layer B);
// db9_remap_* = 0xFD selector stream driven by the hps_io instance.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;
// [MiSTer-DB9 END]
joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_sys            ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

wire [1:0] ar = status[122:121];

`include "build_id.v"
localparam CONF_STR = {
  "KickAndRun;;",
  "-;",
  "O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "OFH,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
  "-;",
  // [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
  "O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
  "O[125],UserIO Players, 1 Player,2 Players;",
  // [MiSTer-DB9-Pro END]
  "DIP;",
  "-;",
  "T[0],Reset;",
  "R[0],Reset and close OSD;",
  "v,0;",
  "V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: rename USB joystick wires
wire [15:0] joy0_USB, joy1_USB;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open; per-core remap
// joydb output bit order (Genesis MD layout): {M,S,Z,Y,X,C,B,A,U,D,L,R} = bits
// 11..0. The core consumes joy0/joy1 as:
//   [3:0]=R/L/D/U dirs, [5:4] & [7:6]=action buttons, [8]=coin, [9]=start.
// REMAP to feed a DB9/DB15/Saturn pad into those slots:
//   out[3:0]  = joydb_1[3:0]   directions  (identity)
//   out[5:4]  = joydb_1[5:4]   B/C  -> primary kick/jump fire buttons
//   out[7:6]  = joydb_1[7:6]   A/X  -> extra action buttons (unused by 2-btn game)
//   out[8]    = joydb_1[11]    Mode -> Coin
//   out[9]    = joydb_1[10]    Start-> Start
wire [15:0] joy0 = joydb_1ena ? (OSD_STATUS ? 16'b0 : {6'd0, joydb_1[10], joydb_1[11], joydb_1[7:0]}) : joy0_USB;
wire [15:0] joy1 = joydb_2ena ? (OSD_STATUS ? 16'b0 : {6'd0, joydb_2[10], joydb_2[11], joydb_2[7:0]}) : joydb_1ena ? joy0_USB : joy1_USB;
// [MiSTer-DB9-Pro END]

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),
  .EXT_BUS(),
  .gamma_bus(gamma_bus),

  .forced_scandoubler(forced_scandoubler),

  .ioctl_download     ( ioctl_download     ),
  .ioctl_wr           ( ioctl_wr           ),
  .ioctl_addr         ( ioctl_addr         ),
  .ioctl_dout         ( ioctl_dout         ),
  .ioctl_wait         ( ioctl_wait         ),
  .ioctl_index        ( ioctl_index        ),

  .buttons            ( buttons            ),
  .status             ( status             ),
  .status_menumask    ( {status[5]}        ),

  .joystick_0         ( joy0_USB           ),
  .joystick_1         ( joy1_USB           ),
  .ps2_key            ( ps2_key            ),
  // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
  .joy_raw            ( OSD_STATUS ? joy_raw_payload : 16'b0 ),
  // [MiSTer-DB9 END]
  // [MiSTer-DB9-Pro BEGIN] - Saturn key gate
  .saturn_unlocked    ( saturn_unlocked    )
  // [MiSTer-DB9-Pro END]
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;

pll pll
(
  .refclk(CLK_50M),
  .rst(0),
  .outclk_0(clk_sys)
  // .locked(locked)
);

wire reset = RESET | status[0] | buttons[1] | ioctl_download;


////////////////////


/******** VIDEO ********/

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire vga_de;

video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[11:10])
);

reg [3:0] red, green, blue;
wire [2:0] fx = status[17:15];

arcade_video #(240,12,0) arcade_video(
  .*,
  .clk_video          ( clk_sys              ),
  .ce_pix             ( ce_pix               ),
  .RGB_in             ( { red, green, blue } ),
  .HBlank             ( HBlank               ),
  .VBlank             ( VBlank               ),
  .HSync              ( HSync                ),
  .VSync              ( VSync                ),
  .fx                 ( fx                   ),
  .forced_scandoubler ( forced_scandoubler   ),
  .gamma_bus          ( gamma_bus            ),
  .VGA_DE             ( vga_de               )
);


/******** AUDIO MIX ********/

wire [15:0] sound_mix;

assign AUDIO_S = 1'b1;
assign AUDIO_L = sound_mix;
assign AUDIO_R = sound_mix;
assign AUDIO_MIX = 2'd3;

/******** CORE ********/


reg [7:0] sw[8];
always @(posedge clk_sys)
  if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

wire core_download = ioctl_download && (ioctl_index==0);

wire [7:0] in0 =  { 4'hf, 2'b00, joy0[9], joy0[8] };
wire [7:0] in1 = ~{ joy1[4], joy1[5], joy1[0], joy1[1], joy1[2], joy1[3] };
wire [7:0] in2 = ~{ joy0[4], joy0[5], joy0[0], joy0[1], joy0[2], joy0[3] };
wire [7:0] in3 = ~{ joy0[6], joy0[7], 3'b000 };


core u_core(
  .reset          ( reset            ),
  .clk_sys        ( clk_sys          ),
  .dsw1           ( sw[0]            ),
  .dsw2           ( sw[1]            ),
  .in0            ( in0              ),
  .in1            ( in1              ),
  .in2            ( in2              ),
  .in3            ( in3              ),
  .in4            ( 8'hff            ),
  .in5            ( 8'hff            ),
  .in6            ( 8'hff            ),
  .in7            ( 8'hff            ),
  .ioctl_download ( core_download    ),
  .ioctl_addr     ( ioctl_addr       ),
  .ioctl_dout     ( ioctl_dout       ),
  .ioctl_wr       ( ioctl_wr         ),
  .red            ( red              ),
  .green          ( green            ),
  .blue           ( blue             ),
  .vs             ( VSync            ),
  .vb             ( VBlank           ),
  .hs             ( HSync            ),
  .hb             ( HBlank           ),
  .ce_pix         ( ce_pix           ),
  .sound_mix      ( sound_mix        )
);


endmodule
