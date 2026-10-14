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

module MCycle

    #(parameter width = 32) 
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
    

    localparam IDLE = 1'b0 ;
    localparam COMPUTING = 1'b1 ;

    // Last value of count for each multiplication. Part-selected where they are
    // used, so the comparisons against count do not silently widen it.
    localparam COUNT_LAST_W  = width - 1 ;    // unsigned multiply
    localparam COUNT_LAST_2W = 2*width - 1 ;  // signed multiply, whose operands are sign extended to 2*width
    localparam BOOTH_Q_WIDTH = 2 * ((width + 2) / 2);
    localparam BOOTH_STEPS   = BOOTH_Q_WIDTH / 2;

    reg state = IDLE ;
    reg n_state = IDLE ;

    reg done = 1'b0 ;
    reg [7:0] count = 0 ; // assuming no computation takes more than 256 cycles.
    reg [2*width-1:0] temp_sum = 0 ;
    reg [2*width-1:0] shifted_op2 = 0 ;

    // What each of the above becomes at the next edge. The computation is
    // written as a sequence of steps over these, so that the registers
    // themselves are only ever assigned with <= , in one place.
    reg [7:0] n_count ;
    reg n_done ;
    reg [2*width-1:0] n_temp_sum ;
    reg [2*width-1:0] n_shifted_op2 ;
    reg [width-1:0] n_Result1 ;
    reg [width-1:0] n_Result2 ;

    //booth Multi
    reg signed [2*width:0] A, n_A;
    reg signed [2*width:0] M, n_M;
    reg signed [BOOTH_Q_WIDTH-1:0] Q, n_Q;
    reg                    Q_previous_bit, n_Q_previous_bit;
    reg [2:0] booth_bits;

    //divide reg
    reg [width:0] trial_remainder; 
    reg [width-1:0] quotient_work;
    reg [width-1:0] div_operand1, div_operand2;


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


    always@(*) begin : COMPUTING_PROCESS 
        n_count = count;
        n_temp_sum = temp_sum;
        n_shifted_op2 = shifted_op2;
        n_Result1 = Result1;
        n_Result2 = Result2;
        n_done = 1'b0;
        n_A = A;
        n_M = M;
        n_Q = Q;
        n_Q_previous_bit = Q_previous_bit;
        booth_bits = 3'b000;

        trial_remainder = 0;
        quotient_work = 0;
        div_operand1 = Operand1;
        div_operand2 = Operand2;

        if (MCycleOp == 2'b10) begin //signed div, change sign if needed
            if (Operand1[width-1])
                div_operand1 = ~Operand1 + 1'b1;

            if (Operand2[width-1])
                div_operand2 = ~Operand2 + 1'b1;
        end

        // n_state == COMPUTING and state == IDLE implies we are just transitioning into COMPUTING
        if (RESET | (n_state == COMPUTING & state == IDLE)) begin
            n_count = 0;
            n_done = 0;

            // Booth accumulator starts at zero
            n_A = 0;

            // Sign-extend or zero-extend multiplicand
            if (MCycleOp == 2'b00) begin
                // Signed multiplication: sign-extend both operands.
                n_M = {{(width+1){Operand2[width-1]}}, Operand2};
                n_Q = {{(BOOTH_Q_WIDTH-width){Operand1[width-1]}}, Operand1};
            end
            else begin
                // Unsigned multiplication: zero-extend both operands.
                n_M = {{(width+1){1'b0}}, Operand2};
                n_Q = {{(BOOTH_Q_WIDTH-width){1'b0}}, Operand1};
            end

            n_Q_previous_bit = 1'b0;

            // Existing division initialisation
            if (MCycleOp[1]) begin
                n_temp_sum = {{width{1'b0}}, div_operand1};
                n_shifted_op2 = {{width{1'b0}}, div_operand2};
            end
        end

        // Guarded so that the cycle in which Busy falls - the one the processor uses to write the result back - does not run another iteration over it, and so that the results are held while idle.
        if( n_state == COMPUTING && state == COMPUTING) begin
            if( ~MCycleOp[1] ) begin // Multiply
                booth_bits = {Q[1:0], Q_previous_bit};

                case (booth_bits)
                    3'b000, 3'b111: n_A = A + 0;
                    3'b001, 3'b010: n_A = A + M;
                    3'b011:         n_A = A + (M <<< 1);
                    3'b100:         n_A = A + (-(M <<< 1));
                    3'b101, 3'b110: n_A = A + (-M);
                    default:        n_A = A + 0;
                endcase

                // Arithmetic shift of the combined {A, Q, Q-1} register by 2 bits
                n_Q_previous_bit = Q[1];
                n_Q = {n_A[1:0], Q[BOOTH_Q_WIDTH-1:2]}; //shift down by 2, first 2 bits of A in, last 2 bits out
                n_A = n_A >>> 2; //shift A by 2

                if (count == BOOTH_STEPS - 1) begin
                    n_done = 1'b1;

                    n_temp_sum = {n_A, n_Q};
                    n_Result1 = n_temp_sum[width-1:0];
                    n_Result2 = n_temp_sum[2*width-1:width];
                end
            end

            else begin

                // remainder[4 bits], put the highest bit inside as the lowest
                trial_remainder = {n_temp_sum[2*width-1:width], n_temp_sum[width-1]}; 

                quotient_work = n_temp_sum[width-1:0] << 1; //shift by 1 to remove the highest bit that is already in trial_remainder

                //subtract divisor
                trial_remainder = trial_remainder - {1'b0, n_shifted_op2[width-1:0]};

                if(trial_remainder[width]) begin
                    //neagtive number -- add back remainder
                    trial_remainder = trial_remainder + {1'b0, n_shifted_op2[width-1:0]};
                end else begin //can divide
                    quotient_work[0] = 1'b1;
                end

                n_temp_sum = {trial_remainder[width-1:0], quotient_work};

                if (count == COUNT_LAST_W[7:0]) begin
                    if (MCycleOp == 2'b10) begin
                        // Correct quotient sign.
                        if (Operand1[width-1] ^ Operand2[width-1])
                            n_temp_sum[width-1:0] =
                                ~n_temp_sum[width-1:0] + 1'b1;
                
                        // Correct remainder sign.
                        if (Operand1[width-1])
                            n_temp_sum[2*width-1:width] =
                                ~n_temp_sum[2*width-1:width] + 1'b1;
                    end
                
                    n_Result2 = n_temp_sum[2*width-1 : width] ;
                    n_Result1 = n_temp_sum[width-1 : 0] ;
                    n_done = 1'b1;
                end

                
            end
            n_count = n_count + 1 ;
        end
    end


    always@( posedge CLK ) begin : STATE_UPDATE_PROCESS // the only place any of this is registered
        state <= n_state ;
        count <= n_count ;
        done <= n_done ;

        A <= n_A;
        M <= n_M;
        Q <= n_Q;
        Q_previous_bit <= n_Q_previous_bit;

        temp_sum <= n_temp_sum ;
        shifted_op2 <= n_shifted_op2 ;

        Result1 <= n_Result1 ;
        Result2 <= n_Result2 ;
    end

endmodule
