`timescale 1ns/1ps
// 640x480, 800x525 total; 25 MHz yields 59.524 Hz. Negative sync polarity.
module VgaTiming(input clk,reset,output reg [9:0] x,output reg [9:0] y,
                 output visible,hsync,vsync,frame_boundary);
    always @(posedge clk) begin
        if(reset) begin x<=0;y<=0;end
        else if(x==799) begin
            x<=0;
            if(y==524)y<=0;else y<=y+1'b1;
        end else x<=x+1'b1;
    end
    assign visible=(x<640 && y<480);
    assign hsync=!(x>=656 && x<752);
    assign vsync=!(y>=490 && y<492);
    assign frame_boundary=(x==0 && y==480);
endmodule
