`timescale 1ns / 1ps

module Subword (
    input MemtoReg,  // 1 for load
    input MemWrite,  // 1 for store
    input [2:0] SizeSel,  // 0 byte || 1 halfword (S) || 2 word || 4 byte (U) || 5 halfword (U) || 
    input  [1:0]      ByteIndex,    // 2LSB from ALUResultM. will tell us which is the base byte for loading/storing
    input [31:0] ReadData_in,  // data read from data mem block
    input [31:0] WriteData,  // raw word to be masked before write
    output reg [31:0] ReadData,  // zero/sign extended word that im gna pass to my programme
    output reg [3:0] WriteMask,  // set each bit to 1 if that byte in WriteData_out shd be written
    output reg [31:0] WriteData_out  // actual word being written
);

    // todo: change ReadData so that it zero extends / sign extends ReadData_in by the right amount according to SizeSelM
    // todo: change WriteMask so that only the appropriate bytes are write enabled

    always @(*) begin
        ReadData = 32'b0;

        if (MemtoReg) begin
            // load byte (signed)
            if (SizeSel == 3'h0) begin
                case (ByteIndex) // choose which byte u want to read from ReadData_in. sign extend the MSB of that byte.
                    2'b00: ReadData = {{24{ReadData_in[7]}}, ReadData_in[7:0]};
                    2'b01: ReadData = {{24{ReadData_in[15]}}, ReadData_in[15:8]};
                    2'b10: ReadData = {{24{ReadData_in[23]}}, ReadData_in[23:16]};
                    2'b11: ReadData = {{24{ReadData_in[31]}}, ReadData_in[31:24]};
                endcase
            end

            // load halfword (signed)
            else if (SizeSel == 3'h1) begin
                case (ByteIndex)
                    2'b00: ReadData = {{16{ReadData_in[15]}}, ReadData_in[15:0]};
                    2'b01: ReadData = {{16{ReadData_in[23]}}, ReadData_in[23:8]};
                    2'b10: ReadData = {{16{ReadData_in[31]}}, ReadData_in[31:16]};
                endcase
            end

            // load word
            else if (SizeSel == 3'h2 && ByteIndex == 2'b00) ReadData = ReadData_in;

            // load byte (unsigned)
            if (SizeSel == 3'h4) begin
                case (ByteIndex) // choose which byte u want to read from ReadData_in. sign extend the MSB of that byte.
                    2'b00: ReadData = {24'b0, ReadData_in[7:0]};
                    2'b01: ReadData = {24'b0, ReadData_in[15:8]};
                    2'b10: ReadData = {24'b0, ReadData_in[23:16]};
                    2'b11: ReadData = {24'b0, ReadData_in[31:24]};
                endcase
            end

            // load halfword (unsigned)
            else if (SizeSel == 3'h5) begin
                case (ByteIndex)
                    2'b00: ReadData = {16'b0, ReadData_in[15:0]};
                    2'b01: ReadData = {16'b0, ReadData_in[23:8]};
                    2'b10: ReadData = {16'b0, ReadData_in[31:16]};
                endcase
            end

        end



    end


    // STORE ======================================================================================
    always @(*) begin
        WriteMask = 4'b0000;
        WriteData_out = 32'b0;

        if (MemWrite) begin
            // store byte
            if (SizeSel == 3'h0) begin
                case (ByteIndex)
                    2'b00: begin  // store byte[0] of WriteData
                        WriteMask = 4'b0001;
                        WriteData_out = WriteData;
                    end
                    2'b01: begin  // store byte[1] of WriteData
                        WriteMask = 4'b0010;
                        WriteData_out = {WriteData[23:0], 8'b0};
                    end
                    2'b10: begin  // store byte[2] of WriteData
                        WriteMask = 4'b0100;
                        WriteData_out = {WriteData[15:0], 16'b0};
                    end
                    2'b11: begin  // store byte[3] of WriteData
                        WriteMask = 4'b1000;
                        WriteData_out = {WriteData[7:0], 24'b0};
                    end
                endcase
            end

            // store halfword
            else if (SizeSel == 3'h1) begin
                case (ByteIndex)
                    2'b00: begin  // store byte[1:0] of WriteData
                        WriteMask = 4'b0011;
                        WriteData_out = WriteData;
                    end
                    2'b01: begin  // store byte[2:1] of WriteData (UNALIGNED)
                        WriteMask = 4'b0110;
                        WriteData_out = {8'b0, WriteData[15:0], 8'b0};
                    end
                    2'b10: begin  // store byte[3:2] of WriteData
                        WriteMask = 4'b1100;
                        WriteData_out = {WriteData[15:0], 16'b0};
                    end
                endcase
            end

            // store word
            else if (SizeSel == 3'h2 && ByteIndex == 2'b00) begin
                WriteMask = 4'b1111;
                WriteData_out = WriteData;
            end
        end
    end
endmodule
