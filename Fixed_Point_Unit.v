`include "Defines.vh"

module Fixed_Point_Unit 
#(
    parameter WIDTH = 32,
    parameter FBITS = 10
)
(
    input wire clk,
    input wire reset,
    
    input wire [WIDTH - 1 : 0] operand_1,
    input wire [WIDTH - 1 : 0] operand_2,
    
    input wire [ 1 : 0] operation,

    output reg [WIDTH - 1 : 0] result,
    output reg ready
);
    always @(*)
    begin
        case (operation)
            `FPU_ADD    : begin result <= operand_1 + operand_2; ready <= 1; end
            `FPU_SUB    : begin result <= operand_1 - operand_2; ready <= 1; end
            `FPU_MUL    : begin result <= product[WIDTH + FBITS - 1 : FBITS]; ready <= product_ready; end
            `FPU_SQRT   : begin result <= root; ready <= root_ready; end
            default     : begin result <= 'bz; ready <= 0; end
        endcase
    end
    
    always @(posedge reset)
    begin
        if (reset)  ready = 0;
        else        ready = 'bz;
    end
    // ------------------- //
    // Square Root Circuit //
    // ------------------- //
    reg [WIDTH - 1 : 0] root;
    reg root_ready;
    
    // Root Calculator Circuit
    
    reg sqrt_active;
    
    integer x;
    
    reg [(WIDTH - 1):0] t = 'b0;
    reg [4:0]           last_bit = 'b0;
    reg [4:0]           last_bit_ff = 'b0;
    reg [(WIDTH - 1):0] op = 'b0;
    
    reg [2:0] sqrt_state;
    reg [2:0] sqrt_next_state;
    
    reg signed [(WIDTH - 1):0] res = 'b0;
    reg signed [(WIDTH - 1):0] sub = 'b0;
    reg signed [(WIDTH - 1):0] sub_t = 'b0;
    reg signed [(WIDTH - 1):0] num = 'b0;
    reg signed [1:0]           two_bits = 'b0;
    
    always @(*)
    begin
        sqrt_next_state = 3'b000;
        
        t  = 'b0;
        last_bit = 'b0;
        two_bits = 'b0;
        sub_t = 'b0;
        num   = 'b0;
        
        case (sqrt_state)
            3'b000:
            begin
                sqrt_next_state = 3'b000;
            end
            
            3'b001:
            begin
                t = {WIDTH{1'b0}} | operand_1;
                
                for (x = 0; x < (WIDTH - 1); x = x + 1)
                begin
                    if (t[x] == 1'b1)
                    begin
                        last_bit = x + 1'b1;
                    end
                end
                
                sqrt_next_state = 3'b010;
            end
            
            3'b010:
            begin
                two_bits = op[(last_bit_ff - 1) -: 2];
                num     = {sub[(WIDTH - 3):0], two_bits};
                sub_t = num - {res, 2'b01};
                
                if (last_bit_ff == 5'b00010)
                begin
                    sqrt_next_state = 3'b011;
                end
                else
                begin
                    sqrt_next_state = 3'b010;
                end
            end
                    
            3'b011:
            begin
                sqrt_next_state = 3'b000;
            end
            
            default:
            begin
            end
        endcase
    end
    
    always @(posedge clk)
    begin
        sqrt_state <= sqrt_next_state;
        
        root_ready <= 'b0;
        
        case (sqrt_state)
            3'b000:
            begin
            end
            
            3'b001:
            begin
                op <= t;
                
                if (last_bit[0] == 1'b1)
                begin
                    last_bit_ff <= last_bit + 1'b1;
                end
                else
                begin
                    last_bit_ff <= last_bit;
                end
            end
            
            3'b010:
            begin
                last_bit_ff <= last_bit_ff - 2'b10;
                
                if (sub_t[WIDTH - 1] == 1'b0)
                begin
                    res <= {res[(WIDTH - 2):0], 1'b1};
                    sub <= sub_t;
                end
                else
                begin
                    res    <= {res[(WIDTH - 2):0], 1'b0};
                    sub <= num;
                end
            end
            
            3'b011:
            begin
                root <= {res[(WIDTH - 6):0], 5'b00000};
                
                root_ready <= 1'b1;
                
                sqrt_active <= 'b0;
            end
            
            default:
            begin
                root <= 'b0;   
                sqrt_active <= 'b0;
                sqrt_state <= 3'b000;
            end
        endcase
        
        if ((operation == `FPU_SQRT) && (sqrt_active == 1'b0))
        begin
            sqrt_active <= 1'b1;
            
            sqrt_state <= 3'b001;
        end
        
        if (reset == 1'b1)
        begin
            root <= 'b0;    
            sqrt_active <= 'b0;
            sqrt_state <= 3'b000;
        end
    end

    // ------------------ //
    // Multiplier Circuit //
    // ------------------ //   
    reg [64 - 1 : 0] product = 'bz;
    reg product_ready = 'bz;

    reg     [15 : 0] multiplierCircuitInput1 = 'bz;
    reg     [15 : 0] multiplierCircuitInput2 = 'bz;
    wire    [31 : 0] multiplierCircuitResult;

    Multiplier multiplier_circuit
    (
        .operand_1(multiplierCircuitInput1),
        .operand_2(multiplierCircuitInput2),
        .product(multiplierCircuitResult)
    );

    reg     [31 : 0] partialProduct1 = 'bz;
    reg     [31 : 0] partialProduct2 = 'bz;
    reg     [31 : 0] partialProduct3 = 'bz;
    reg     [31 : 0] partialProduct4 = 'bz;
    
    // Multiplier Calculator Circuit
    
    reg active = 1'b0;
    
    parameter s1 = 3'b000, s2 = 3'b001, s3 = 3'b010, s4 = 3'b011, s5 = 3'b100, s6 = 3'b101;
    
    reg [2:0] state  = s1;
    reg [2:0] next_state = s1;
    
    always @(*)
    begin
        next_state = s1;
        multiplierCircuitInput1 = 'b0;
        multiplierCircuitInput2 = 'b0;
        
        case (state)
            s1:
            begin
                next_state = s1;
            end
            
            s2:
            begin
                multiplierCircuitInput1 = operand_1[((WIDTH / 2) - 1) : 0];
                multiplierCircuitInput2 = operand_2[((WIDTH / 2) - 1) : 0];
                
                next_state = s3;
            end
            
            s3:
            begin
                multiplierCircuitInput1 = operand_1[(WIDTH - 1) -: (WIDTH / 2)];
                multiplierCircuitInput2 = operand_2[((WIDTH / 2) - 1) : 0];
                
                next_state = s4;
            end
            
            s4:
            begin
                multiplierCircuitInput1 = operand_1[((WIDTH / 2) - 1) : 0];
                multiplierCircuitInput2 = operand_2[(WIDTH - 1) -: (WIDTH / 2)];
                
                next_state = s5;
            end
            
            s5:
            begin
                multiplierCircuitInput1 = operand_1[(WIDTH - 1) -: (WIDTH / 2)];
                multiplierCircuitInput2 = operand_2[(WIDTH - 1) -: (WIDTH / 2)];
                
                next_state = s6;
            end
            
            s6:
            begin
                next_state = s1;
            end
            
            default:
            begin
            end
        endcase
    end
    
    always @(posedge clk)
    begin
        state <= next_state;
        
        product_ready <= 'b0;
        
        case (state)
            s1:
            begin
            end
            
            s2:
            begin
                partialProduct1 <= multiplierCircuitResult;
            end
            
            s3:
            begin
                product <= product + {{WIDTH{1'b0}}, partialProduct1};
                
                partialProduct2 <= multiplierCircuitResult;
            end
            
            s4:
            begin
                product <= product + {{WIDTH{1'b0}}, partialProduct2};
                
                partialProduct3 <= multiplierCircuitResult;
            end
            
            s5:
            begin
                product <= product + {{WIDTH{1'b0}}, partialProduct3};
                
                partialProduct4 <= multiplierCircuitResult;
            end
            
            s6:
            begin
                product <= partialProduct1 + partialProduct2 + partialProduct3 + partialProduct4;
                product_ready <= 1'b1;
                active <= 'b0;
            end
            
            default:
            begin
                product <= 'b0;  
                active <= 'b0;
                state <= s1;
            end
        endcase
        
        if ((operation == `FPU_MUL) && (active == 1'b0))
        begin
            active <= 1'b1;
            state <= s2;
        end
        
        if (reset == 1'b1)
        begin
            product <= 'b0;       
            active <= 'b0;
            state <= s1;
        end
    end
    
    
    
endmodule

module Multiplier
(
    input wire [15 : 0] operand_1,
    input wire [15 : 0] operand_2,

    output reg [31 : 0] product
);

    always @(*)
    begin
        product <= operand_1 * operand_2;
    end
endmodule
