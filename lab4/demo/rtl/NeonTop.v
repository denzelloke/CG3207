`timescale 1ns/1ps
// Single 25 MHz clock drives both the CPU and VGA timing.
module NeonTop
    (input CLK_undiv,input [15:0] DIP,input [2:0] PB,
    input START,RESET,
    output [15:0] LED,
    output reg [6:0] SevenSegCat,output reg [7:0] SevenSegAn,output DP,
    output reg [3:0] VGA_R,VGA_G,VGA_B,output reg VGA_HS,VGA_VS);
    localparam integer TICK_CYCLES=416667;
    localparam integer DEBOUNCE_CYCLES=250000;
    wire cpu_clk,pixel_clk,locked;
`ifdef SIMULATION
    // Behavioural clock model for the fixed 100 MHz board oscillator.
    // Delays are simulation-only; hardware uses the MMCM below.
    reg [1:0] divider=0;
    always @(posedge CLK_undiv) divider<=divider+1'b1;
    assign cpu_clk=divider[1]; assign pixel_clk=cpu_clk;
    assign locked=1'b1;
`else
    wire clock_raw,feedback_raw,feedback;
    MMCME2_BASE #(.CLKIN1_PERIOD(10.0),.CLKFBOUT_MULT_F(8.0),
        .DIVCLK_DIVIDE(1),.CLKOUT0_DIVIDE_F(32.0),.STARTUP_WAIT("FALSE")) clock_manager (
        .CLKIN1(CLK_undiv),.CLKFBIN(feedback),.RST(1'b0),.PWRDWN(1'b0),
        .CLKFBOUT(feedback_raw),.CLKOUT0(clock_raw),.LOCKED(locked));
    BUFG clock_buffer(.I(clock_raw),.O(cpu_clk)); assign pixel_clk=cpu_clk;
    BUFG feedback_buffer(.I(feedback_raw),.O(feedback));
`endif
    // Common asynchronous assertion; independent synchronous release per domain.
    wire reset_request=RESET || !locked;
    (* ASYNC_REG="TRUE" *) reg [2:0] cpu_reset_sync=3'b111;
    (* ASYNC_REG="TRUE" *) reg [2:0] pixel_reset_sync=3'b111;
    reg [9:0] cpu_startup=0,pixel_startup=0;
    always @(posedge cpu_clk or posedge reset_request) begin
        if(reset_request) begin cpu_reset_sync<=3'b111;cpu_startup<=0;end
        else begin
            cpu_reset_sync<={cpu_reset_sync[1:0],1'b0};
            if(!(&cpu_startup))cpu_startup<=cpu_startup+1'b1;
        end
    end
    always @(posedge pixel_clk or posedge reset_request) begin
        if(reset_request) begin pixel_reset_sync<=3'b111;pixel_startup<=0;end
        else begin
            pixel_reset_sync<={pixel_reset_sync[1:0],1'b0};
            if(!(&pixel_startup))pixel_startup<=pixel_startup+1'b1;
        end
    end
    wire cpu_reset=cpu_reset_sync[2] || !(&cpu_startup);
    wire pixel_reset=cpu_reset;
    wire [9:0] x,y;
    wire visible,hs,vs,frame_boundary;
    wire [2047:0] objects;
    wire [511:0] hud;
    wire [31:0] sevenseg,pc;
    wire [11:0] rgb;
    VgaTiming timing(pixel_clk,pixel_reset,x,y,visible,hs,vs,frame_boundary);
    GameSoC #(.TICK_CYCLES(TICK_CYCLES),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) soc
        (cpu_clk,cpu_reset,{START,PB},DIP,frame_boundary,objects,hud,LED,sevenseg,pc);
    GameRenderer renderer(x,y,visible,objects,hud,rgb);
    always @(posedge pixel_clk) begin
        if(pixel_reset) begin VGA_R<=0;VGA_G<=0;VGA_B<=0;VGA_HS<=1;VGA_VS<=1;end
        else begin
            VGA_R<=rgb[11:8];VGA_G<=rgb[7:4];VGA_B<=rgb[3:0];VGA_HS<=hs;VGA_VS<=vs;
        end
    end
    // Keep sevenseg data and scanning together in the CPU domain.
    reg [31:0] scan_count=0;
    reg [2:0] scan_digit=0;
    reg [3:0] nibble;
    always @(posedge cpu_clk) begin
        if(cpu_reset)begin scan_count<=0;scan_digit<=0;end
        else if(scan_count==SCAN_CYCLES-1)begin scan_count<=0;scan_digit<=scan_digit+1'b1;end
        else scan_count<=scan_count+1'b1;
    end
    assign DP=1'b1;
    always @* begin
        SevenSegAn=~(8'b1<<scan_digit);
        nibble=(sevenseg>>(scan_digit*4)) & 15;
        case(nibble)
            0:SevenSegCat=7'b1000000;1:SevenSegCat=7'b1111001;
            2:SevenSegCat=7'b0100100;3:SevenSegCat=7'b0110000;
            4:SevenSegCat=7'b0011001;5:SevenSegCat=7'b0010010;
            6:SevenSegCat=7'b0000010;7:SevenSegCat=7'b1111000;
            8:SevenSegCat=7'b0000000;9:SevenSegCat=7'b0010000;
            10:SevenSegCat=7'b0001000;11:SevenSegCat=7'b0000011;
            12:SevenSegCat=7'b1000110;13:SevenSegCat=7'b0100001;
            14:SevenSegCat=7'b0000110;15:SevenSegCat=7'b0001110;
            default:SevenSegCat=7'b1111111;
        endcase
    end
endmodule
