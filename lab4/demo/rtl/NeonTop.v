`timescale 1ns/1ps
module NeonTop(input CLK_undiv,input [15:0] DIP,input [2:0] PB,
    input START,RESET,
    output [15:0] LED,
    output reg [6:0] SevenSegCat,output reg [7:0] SevenSegAn,output DP,
    output reg [3:0] VGA_R,VGA_G,VGA_B,output reg VGA_HS,VGA_VS);
    wire clk,locked;
`ifdef SIMULATION
    reg [1:0] divider=0;
    always @(posedge CLK_undiv) divider<=divider+1'b1;
    assign clk=divider[1];
    assign locked=1'b1;
`else
    wire clock_raw,feedback_raw,feedback;
    MMCME2_BASE #(.CLKIN1_PERIOD(10.0),.CLKFBOUT_MULT_F(8.0),
        .DIVCLK_DIVIDE(1),.CLKOUT0_DIVIDE_F(32.0),.STARTUP_WAIT("FALSE")) clock_manager (
        .CLKIN1(CLK_undiv),.CLKFBIN(feedback),.RST(1'b0),.PWRDWN(1'b0),
        .CLKFBOUT(feedback_raw),.CLKOUT0(clock_raw),.LOCKED(locked));
    BUFG clock_buffer(.I(clock_raw),.O(clk));
    BUFG feedback_buffer(.I(feedback_raw),.O(feedback));
`endif
    (* ASYNC_REG="TRUE" *) reg reset_meta=1,reset_sync=1;
    reg [9:0] startup=0;
    always @(posedge clk) begin
        reset_meta<=RESET;reset_sync<=reset_meta;
        if(!locked) startup<=0;
        else if(!(&startup)) startup<=startup+1'b1;
    end
    wire reset=reset_sync || !(&startup) || !locked;
    wire [9:0] x,y;
    wire visible,hs,vs,frame_boundary;
    wire [2047:0] objects;
    wire [511:0] hud;
    wire [31:0] sevenseg,pc;
    wire [11:0] rgb;
    VgaTiming timing(clk,reset,x,y,visible,hs,vs,frame_boundary);
    GameSoC soc(clk,reset,{START,PB},DIP,frame_boundary,objects,hud,LED,sevenseg,pc);
    GameRenderer renderer(x,y,visible,objects,hud,rgb);
    always @(posedge clk) begin
        VGA_R<=rgb[11:8];VGA_G<=rgb[7:4];VGA_B<=rgb[3:0];VGA_HS<=hs;VGA_VS<=vs;
    end
    reg [14:0] scan=0;
    reg [3:0] nibble;
    always @(posedge clk) scan<=scan+1'b1;
    assign DP=1'b1;
    always @* begin
        SevenSegAn=~(8'b1<<scan[14:12]);
        nibble=(sevenseg>>(scan[14:12]*4)) & 15;
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
