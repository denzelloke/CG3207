`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NUS
// Engineer: Shahzor Ahmad, Rajesh C Panicker
// 
// Create Date: 27.09.2016 10:59:44
// Design Name: 
// Module Name: MCycle
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
/* 
----------------------------------------------------------------------------------
--	(c) Shahzor Ahmad, Rajesh C Panicker
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post it on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(iv) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(v) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NUS
// Engineer: Shahzor Ahmad, Rajesh C Panicker
// 
// Create Date: 27.09.2016 10:59:44
// Design Name: 
// Module Name: MCycle
// Project Name: 
// Target Devices: Nexys 4 / Basys 3
// Tool Versions: Vivado 2019.2
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
/* 
----------------------------------------------------------------------------------
--	(c) Shahzor Ahmad, Rajesh C Panicker
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post it on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate anyone's intellectual property.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--		(vi) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/

module MCycle

    #(
        parameter width = 32,
        parameter ENHANCED_MUL = 1'b1
    )

    (
        input CLK,
        input RESET,
        input Start,
        input [1:0] MCycleOp,
        input [width-1:0] Operand1,
        input [width-1:0] Operand2,
        output reg [width-1:0] Result1,
        output reg [width-1:0] Result2,
        output reg Busy
    );
    
// DONE! use the Busy signal to reset WE_PC to 0 in RV.v (aka "freeze" PC). The two signals are complements of each other
// since the IDLE_PROCESS is combinational, instantaneously asserts Busy once Start is asserted

    localparam IDLE = 1'b0 ;
    localparam COMPUTING = 1'b1 ;

    // Last value of count for each multiplication. Part-selected where they are
    // used, so the comparisons against count do not silently widen it.
    localparam COUNT_LAST_W  = width - 1 ;    // unsigned multiply
    localparam COUNT_LAST_2W = 2*width - 1 ;  // signed multiply, whose operands are sign extended to 2*width

    // Last value of count for enhanced radix-4 multiplication.
    // Two multiplier bits are processed during each iteration.
    localparam [7:0] COUNT_LAST_RADIX4 = ((width + 1) / 2) - 1 ;

    reg state = IDLE ;
    reg n_state = IDLE ;

    reg done = 1'b0 ;
    reg [7:0] count = 0 ; // assuming no computation takes more than 256 cycles.
    reg [2*width-1:0] temp_sum = 0 ;
    reg [2*width-1:0] shifted_op1 = 0 ;
    reg [2*width-1:0] shifted_op2 = 0 ;

    // What each of the above becomes at the next edge. The computation is
    // written as a sequence of steps over these, so that the registers
    // themselves are only ever assigned with <= , in one place.

    reg [7:0] n_count ;     //used in division too               
    reg n_done ;            //used in division too
    reg [2*width-1:0] n_temp_sum ;
    reg [2*width-1:0] n_shifted_op1 ;
    reg [2*width-1:0] n_shifted_op2 ;
    reg [width-1:0] n_Result1 ;
    reg [width-1:0] n_Result2 ;


    // For division
    reg [width:0] remainder = 0;
    reg [width:0] n_remainder;
    reg [width-1:0] dividend = 0;
    reg [width-1:0] n_dividend;
    reg [width-1:0] quotient = 0;
    reg [width-1:0] n_quotient;
    reg [width-1:0] divisor = 0;
    reg [width-1:0] n_divisor;

    //for signed division
    reg dividend_sign = 1'b0;
    reg n_dividend_sign;   
    reg divisor_sign = 1'b0;
    reg n_divisor_sign;


    always@(*) begin : IDLE_PROCESS

        // default outputs
        Busy = 1'b0 ;
        n_state = IDLE ;

        // reset
        if(~RESET)
            case(state)
                IDLE: begin
                    if(Start) begin // note: a mealy machine, since output depends on current state (IDLE) & input (Start)
                        n_state = COMPUTING ;
                        Busy = 1'b1 ;
                    end
                end

                COMPUTING: begin
                    if(~done) begin
                        n_state = COMPUTING ;
                        Busy = 1'b1 ;
                    end
                end
            endcase
    end


    //calculates next cycle's value
    always@(*) begin : COMPUTING_PROCESS // process which does the actual computation

        // Hold, unless something below says otherwise.
        n_count = count ;       //used for division too
        n_temp_sum = temp_sum ;
        n_shifted_op1 = shifted_op1 ;
        n_shifted_op2 = shifted_op2 ;
        n_Result1 = Result1 ;
        n_Result2 = Result2 ;
        n_done = 1'b0 ;         //used for division too
        

        //for division
        n_remainder = remainder;
        n_dividend = dividend;
        n_quotient = quotient;
        n_divisor = divisor;

        //for signed division
        n_dividend_sign = dividend_sign;
        n_divisor_sign = divisor_sign;


        // n_state == COMPUTING and state == IDLE implies we are just transitioning into COMPUTING
        if( RESET | (n_state == COMPUTING & state == IDLE) ) begin // 2nd condition is true during the very 1st clock cycle of the multiplication

            n_count = 0 ;
            n_temp_sum = 0 ;

            n_shifted_op1 = {
                {width{~MCycleOp[0] & Operand1[width-1]}},
                Operand1
            } ; // sign extend the operands

            n_shifted_op2 = {
                {width{~MCycleOp[0] & Operand2[width-1]}},
                Operand2
            } ;

            //for division
            n_remainder = 0;
            n_dividend = Operand1;
            n_quotient = 0;
            n_divisor = Operand2;

            //for signed division
            n_dividend_sign = Operand1[width-1];
            n_divisor_sign = Operand2[width-1];

        end


        // Guarded so that the cycle in which Busy falls - the one the processor uses to write the result back - does not run another iteration over it, and so that the results are held while idle.
        if( n_state == COMPUTING ) begin

            if( ~MCycleOp[1] ) begin // Multiply

                // Enhanced radix-4 multiplication.
                // This path is selected for unsigned multiplication.
                // Two multiplier bits are processed during each iteration.
                if(ENHANCED_MUL && MCycleOp[0]) begin

                    // The two least-significant multiplier bits select
                    // the partial product to add:
                    //
                    // 00: add 0 * multiplicand
                    // 01: add 1 * multiplicand
                    // 10: add 2 * multiplicand
                    // 11: add 3 * multiplicand

                    case(n_shifted_op2[1:0])

                        2'b00: begin
                            n_temp_sum = n_temp_sum ;
                        end

                        2'b01: begin
                            n_temp_sum = n_temp_sum + n_shifted_op1 ;
                        end

                        2'b10: begin
                            // 2 * multiplicand = multiplicand shifted left by 1
                            n_temp_sum = n_temp_sum + (n_shifted_op1 << 1) ;
                        end

                        2'b11: begin
                            // 3 * multiplicand =
                            // multiplicand + 2 * multiplicand
                            n_temp_sum = n_temp_sum
                                        + n_shifted_op1
                                        + (n_shifted_op1 << 1) ;
                        end

                    endcase

                    // Discard the two multiplier bits already processed.
                    n_shifted_op2 = n_shifted_op2 >> 2 ;

                    // Shift the multiplicand by two because the next
                    // multiplier digit represents four times the value
                    // of the current digit.
                    n_shifted_op1 = n_shifted_op1 << 2 ;

                    // A width-bit multiplication requires approximately
                    // width/2 iterations.
                    if(n_count == COUNT_LAST_RADIX4) begin
                        n_done = 1'b1 ;
                    end

                    n_count = n_count + 1 ;

                end

                // Original multiplier.
                // Set ENHANCED_MUL to 1'b0 to use this
                else begin

                    // if( ~MCycleOp[0] ), takes 2*'width' cycles to execute, returns signed(Operand1)*signed(Operand2)
                    // if( MCycleOp[0] ), takes 'width' cycles to execute, returns unsigned(Operand1)*unsigned(Operand2)

                    if( n_shifted_op2[0] ) // add only if b0 = 1
                        n_temp_sum = n_temp_sum + n_shifted_op1 ; // partial product for multiplication

                    n_shifted_op2 = {
                        1'b0,
                        n_shifted_op2[2*width-1 : 1]
                    } ;

                    n_shifted_op1 = {
                        n_shifted_op1[2*width-2 : 0],
                        1'b0
                    } ;

                    if(
                        (MCycleOp[0] &
                         n_count == COUNT_LAST_W[7:0]) |
                        (~MCycleOp[0] &
                         n_count == COUNT_LAST_2W[7:0])
                    ) // last cycle?
                        n_done = 1'b1 ;

                    n_count = n_count + 1 ;

                end
            end


            // DONE: Change this to signed [ if(~MCycleOp[0]) ] and unsigned [ if(MCycleOp[0]) ] division.
            // DONE: Task 1: div and divu
            else if (~MCycleOp[0]) begin   // signed division

                // need to check signs
                if (n_count == 1'b0 && n_dividend_sign) begin
                    n_dividend = ~n_dividend + 1'b1;
                end

                if (n_count == 1'b0 && n_divisor_sign) begin
                    n_divisor = ~n_divisor + 1'b1;
                end

                //bring next divident bit into remainder (MSB to LSB)
                n_remainder = {
                    n_remainder[width-1:0],
                    n_dividend[width-1]
                };

                //shift divident left
                n_dividend = {
                    n_dividend[width-2:0],
                    1'b0
                };

                //shift quotient left for next quotient bit
                n_quotient = {
                    n_quotient[width-2:0],
                    1'b0
                };

                //proceed with division checks
                if (n_remainder >= {1'b0, n_divisor}) begin
                    n_remainder = n_remainder - {1'b0, n_divisor};

                    n_quotient[0] = 1'b1;   //set current quotient bit to 1
                end

                else begin
                    n_quotient[0] = 1'b0;   //set current quotient bit to 0;
                end


                // takes 'width' cycles to execute
                if (n_count == COUNT_LAST_W[7:0]) begin
                    n_done = 1'b1;

                    if (dividend_sign && divisor_sign) begin
                        //only remainder negative
                        n_remainder = ~n_remainder + 1'b1;
                    end

                    else if (dividend_sign) begin
                        //both will be negative
                        n_quotient = ~n_quotient + 1'b1;
                        n_remainder = ~n_remainder + 1'b1;
                    end

                    else if (divisor_sign) begin
                        //only quotient negative
                        n_quotient = ~n_quotient + 1'b1;
                    end
                end

                //store quotient and remainder tin temp
                n_temp_sum[2*width-1:width] =
                    n_remainder[width-1:0];

                n_temp_sum[width-1:0] =
                    n_quotient;

                n_count = n_count + 1;

            end


            else if (MCycleOp[0]) begin   // unsigned division

                //just take binary at face value and perform division, dont need to check signs

                //bring next divident bit into remainder (MSB to LSB)
                n_remainder = {
                    n_remainder[width-1:0],
                    n_dividend[width-1]
                };

                //shift divident left
                n_dividend = {
                    n_dividend[width-2:0],
                    1'b0
                };

                //shift quotient left for next quotient bit
                n_quotient = {
                    n_quotient[width-2:0],
                    1'b0
                };

                //proceed with division checks
                if (n_remainder >= {1'b0, n_divisor}) begin
                    n_remainder = n_remainder - {1'b0, n_divisor};

                    n_quotient[0] = 1'b1;   //set current quotient bit to 1
                end

                else begin
                    n_quotient[0] = 1'b0;   //set current quotient bit to 0;
                end

                //store quotient and remainder tin temp
                n_temp_sum[2*width-1:width] =
                    n_remainder[width-1:0];

                n_temp_sum[width-1:0] =
                    n_quotient;

                // takes 'width' cycles to execute
                if (n_count == COUNT_LAST_W[7:0]) begin
                    n_done = 1'b1;
                end

                n_count = n_count + 1;

            end
            
            //The dummy code below takes 1 cycle to execute, just returns the operands. 
            else begin 

                //returns Operand1 in Result2 and Operand2 in Result1.
                n_temp_sum[2*width-1 : width] = Operand1 ;
                n_temp_sum[width-1 : 0] = Operand2 ;
                n_done = 1'b1 ;

            end

            n_Result2 = n_temp_sum[2*width-1 : width] ;     //remainder
            n_Result1 = n_temp_sum[width-1 : 0] ;           //quotient

        end
    end
 
    //clocked block, stores the next cycle's value
    always@( posedge CLK ) begin : STATE_UPDATE_PROCESS // the only place any of this is registered

        state <= n_state ;
        count <= n_count ;
        done <= n_done ;
        temp_sum <= n_temp_sum ;
        shifted_op1 <= n_shifted_op1 ;
        shifted_op2 <= n_shifted_op2 ;
        Result1 <= n_Result1 ;
        Result2 <= n_Result2 ;

        //for division
        dividend <= n_dividend;
        quotient <= n_quotient;
        divisor <= n_divisor;
        remainder <= n_remainder;

        //for signed division
        dividend_sign <= n_dividend_sign;
        divisor_sign <= n_divisor_sign;

    end

endmodule
