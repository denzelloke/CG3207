`timescale 1ns/1ps
module test_video;
    reg clk=0,reset=1;always #5 clk=~clk;
    wire [9:0]x,y;wire visible,hs,vs,boundary;wire[11:0]rgb;
    reg[2047:0]objects=0;reg[511:0]hud=0;
    integer pixels=0,hs_count=0,vs_count=0,frames=0,n,fd=0,cycles=0;
    reg dump=0;
    VgaTiming timing(clk,reset,x,y,visible,hs,vs,boundary);
    GameRenderer renderer(x,y,visible,objects,hud,rgb);
    initial begin
        dump=$test$plusargs("DUMP");
        if(dump)begin fd=$fopen("preview.ppm","w");$fwrite(fd,"P3\n640 480\n255\n");end
        hud[0+:32]=1;hud[32+:32]=32'h00000120;hud[64+:32]=3;hud[96+:32]=2;
        hud[128+:32]=7;hud[160+:32]=32'h00001800;hud[192+:32]=32'h00001200;
        hud[224+:32]=32'h00004800;hud[256+:32]=32'h00000321;hud[288+:32]=32'h00000120;
        hud[384+:32]=32'h00000012;
        objects[0+:32]={16'd440,16'd308};objects[32+:32]=1;objects[64+:32]=12'h0ef;objects[96]=1;
        for(n=1;n<5;n=n+1)begin
            objects[n*128+:32]=(144<<16)+(96+(n-1)*128);
            objects[n*128+32+:32]=2;objects[n*128+64+:32]=12'hf3b;objects[n*128+96]=1;
        end
        objects[5*128+:32]={16'd300,16'd318};objects[5*128+32+:32]=3;
        objects[5*128+64+:32]=12'hfe4;objects[5*128+96]=1;
        repeat(2)@(negedge clk);reset=0;
        repeat(420000)begin
            #1;
            if(visible)begin
                pixels=pixels+1;
                if(dump)$fwrite(fd,"%0d %0d %0d\n",rgb[11:8]*17,rgb[7:4]*17,rgb[3:0]*17);
            end else if(rgb!==0)$fatal(1,"RGB outside visible frame");
            if(!hs)hs_count=hs_count+1;
            if(!vs)vs_count=vs_count+1;
            if(boundary)frames=frames+1;
            @(negedge clk);
        end
        if(pixels!=307200 || hs_count!=50400 || vs_count!=1600 || frames!=1)
            $fatal(1,"VGA geometry %d %d %d %d",pixels,hs_count,vs_count,frames);
        if(dump)$fclose(fd);
        $display("VIDEO PASS pixels=%0d",pixels);$finish;
    end
endmodule
