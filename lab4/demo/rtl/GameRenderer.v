`timescale 1ns/1ps
// Draws CPU-published state only. No movement/collision/scoring logic here.
module GameRenderer(input [9:0] x,y,input visible,
    input [2047:0] objects,input [511:0] hud,output reg [11:0] rgb);
    wire [31:0] state=hud[0+:32];
    wire [31:0] mode=hud[128+:32];
    integer col,row,n,ox,oy,lx,ly,kind,w,h;
    reg sprite_pixel;
    reg [11:0] color;
    reg [7:0] ch;
    wire [34:0] glyph;
    Font5x7 font(ch,glyph);
    function [7:0] letter;
        input [639:0] text;
        input integer length,index;
        begin
            letter=8'h20;
            if(index>=0 && index<length) letter=text[(length-index)*8-1-:8];
        end
    endfunction
    function [7:0] digit;
        input [31:0] number;
        input integer position;
        reg [3:0] nibble;
        begin
            nibble=(number >> ((7-position)*4)) & 15;
            digit=(nibble<10) ? 8'd48+{4'b0,nibble} : 8'd55+{4'b0,nibble};
        end
    endfunction
    always @* begin
        col=x>>3;row=y>>4;
        ch=" ";
        case(row)
            1: ch=letter("NEON SPACE DEFENDER",19,col-30);
            3: begin
                if(col<8) ch=letter("SCORE",5,col-2);
                else if(col<16)ch=digit(hud[32+:32],col-8);
                else if(col<29)ch=letter("HEALTH",6,col-22);
                else if(col==29)ch=8'd48+hud[64+:4];
                else if(col<42)ch=letter("WAVE",4,col-36);
                else if(col<50)ch=digit(hud[96+:32],col-42);
                else if(col<65)ch=letter("DIFFICULTY",10,col-54);
                else if(col==65)ch=8'd48+hud[416+:4];
            end
            4: begin
                if(col<14)ch=letter("CYC/UPDATE",10,col-2);
                else if(col<22)ch=digit(hud[160+:32],col-14);
                else if(col<39)ch=letter("INST/UPDATE",11,col-26);
                else if(col<47)ch=digit(hud[192+:32],col-39);
                else if(col<61)ch=letter("IRQ LAT",7,col-52);
                else if(col<69)ch=mode[1]?digit(hud[384+:32],col-61):"-";
            end
            5: begin
                if(col<12)ch=letter("BRANCHES",8,col-2);
                else if(col<20)ch=digit(hud[224+:32],col-12);
                else if(col<35)ch=letter("MISSES/SEC",10,col-24);
                else if(col<43)ch=digit(hud[256+:32],col-35);
                else if(col<60)ch=letter("UPDATES/SEC",11,col-48);
                else if(col<68)ch=digit(hud[288+:32],col-60);
            end
            6: begin
                if(col<8)ch=letter("PRED",4,col-2);
                else if(col==8)ch=mode[0]?"1":"0";
                else if(col<17)ch=letter("IRQ",3,col-13);
                else if(col==17)ch=mode[1]?"1":"0";
                else if(col<30)ch=letter("SUBWORD",7,col-22);
                else if(col==30)ch=mode[2]?"1":"0";
                else if(col<42)ch=letter("REPLAY",6,col-35);
                else if(col==42)ch=mode[3]?"1":"0";
                else if(col<56)ch=letter("DROPPED",7,col-48);
                else if(col<64)ch=digit(hud[320+:32],col-56);
            end
            14: begin
                if(state==0)ch=letter("PRESS UP TO START",17,col-31);
                if(state==2)ch=letter("GAME OVER",9,col-35);
                if(state==3)ch=letter("REPLAY COMPLETE",15,col-32);
            end
            16: begin
                if(state==0)ch=letter("LEFT RIGHT MOVE - CENTER FIRES",30,col-25);
                if(state==2)ch=letter("PRESS UP TO RESTART",19,col-30);
                if(state==3) begin
                    if(col<39)ch=letter("CHECKSUM",8,col-29);
                    else if(col<47)ch=digit(hud[352+:32],col-39);
                end
            end
            18: if(state==0 || state==3)
                ch=letter("SET SWITCHES THEN DOWN TO CHANGE MODES",38,col-21);
            28: ch=letter("LEFT RIGHT MOVE   CENTER FIRE   UP RESTART   DOWN RESET",55,col-13);
            default: ch=" ";
        endcase
    end
    always @* begin
        rgb=12'h012;color=0;sprite_pixel=0;
        ox=0;oy=0;lx=0;ly=0;kind=0;w=0;h=0;
        // Static starfield avoids consuming gameplay CPU work.
        if(y>=132 && y<458 && ((x[5:0] ^ y[5:0])==6'd17) && y[4:0]==5'd7)
            rgb=12'h235;
        if((y==128 || y==460) && x>=16 && x<624)rgb=12'h067;
        if(state!=0) begin
            for(n=0;n<16;n=n+1) begin
                ox={16'b0,objects[n*128+:16]};oy={16'b0,objects[n*128+16+:16]};
                kind={28'b0,objects[n*128+32+:4]};
                color=objects[n*128+64+:12];
                lx={22'b0,x}-ox;ly={22'b0,y}-oy;
                w=(kind==3 || kind==4)?4:24;h=(kind==3 || kind==4)?10:16;
                sprite_pixel=0;
                if(objects[n*128+96] && lx>=0 && ly>=0 && lx<w && ly<h) begin
                    case(kind)
                        1: sprite_pixel=(lx>=9 && lx<15) || (ly>=7 && lx>=3 && lx<21) || (ly>=12);
                        2: sprite_pixel=(ly>=3 && ly<13) || (ly<3 && lx>=5 && lx<19)
                                        || (ly>=13 && (lx<5 || lx>=19));
                        3: sprite_pixel=1;
                        4: sprite_pixel=(ly<7 || (lx>=1 && lx<3));
                        default: sprite_pixel=0;
                    endcase
                    if(sprite_pixel) begin
                        rgb=color;
                        if(kind==2 && ly>=6 && ly<9 && ((lx>=5 && lx<8)||(lx>=16 && lx<19)))rgb=12'h012;
                        if(kind==1 && ly<6 && lx>=10 && lx<14)rgb=12'hfff;
                        if(kind==3 && lx==1)rgb=12'hfff;
                    end
                end
            end
        end
        // Text occupies 5x14 pixels inside each 8x16 cell.
        if(x[2:0]<5 && y[3:1]<7 && glyph[34-(y[3:1]*5+x[2:0])]) begin
            rgb=(row==1)?12'h0ef:((row>=14 && row<=18)?12'hfe4:12'h9bc);
        end
        if(!visible)rgb=0;
    end
endmodule
