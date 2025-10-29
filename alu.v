`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it in phase 3.
module alu (
    // Major operation selection.
    // NOTE: In order to simplify instruction decoding in phase 4, both 3'b010
    // and 3'b011 are used for set less than (they are equivalent).
    // Unsigned comparison is controlled through the `i_unsigned` signal.
    //
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is only used for branch comparisons and set less than.
    // For branch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b011` (shift right).
    input  wire        i_arith,
    // Pass Value through
    input  wire        i_pass,
    // Memory Instruction Flag (forces opsel to be ignored)
    input  wire        i_mem,
    // AUI PC instruction Flag (load PC into OP1)
    input  wire        i_auipc,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out (from addition) should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_eq,
    // Set less than result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_slt
);
    // Internal Signals
    wire [2:0]         a_opsel;
    wire [31:0]        l_shft;
    wire [31:0]        r_shft;
    wire [31:0]        l_result;

    // Instantiate Shifter Modules
    l_shifter u_lft(.i_op1(i_op1), .i_op2(i_op2[4:0]), .o_res(l_shft));
    r_shifter u_rht(.i_op1(i_op1), .i_op2(i_op2[4:0]), .i_arith(i_arith), .o_res(r_shft));     

    // Assign internal signals based on if memory instruction (load/store) or auipc occuring
    assign a_opsel     = (i_mem | i_auipc) ? 3'b000  : i_opsel;

    // Structural replacement for combinational ALU result (replaces previous always block)
                        // 3'b000: addition/subtraction if `i_sub` asserted
    assign l_result =  (a_opsel == 3'b000) ? ((i_sub) ? i_op1 - i_op2 : i_op1 + i_op2) :    
                        // 3'b001: shift left logical
                       (a_opsel == 3'b001) ? l_shft :
                       // 3'b010/3'b011: set less than/unsigned if `i_unsigned` asserted
                       ((a_opsel == 3'b010) | (a_opsel == 3'b011)) ? {{31{1'b0}}, o_slt} :
                       // 3'b100: exclusive or
                       (a_opsel == 3'b100) ? (i_op1 ^ i_op2) :
                       // 3'b101: shift right logical/arithmetic if `i_arith` asserted
                       (a_opsel == 3'b101) ? r_shft :
                       // 3'b110: or
                       (a_opsel == 3'b110) ? (i_op1 | i_op2) :
                       // 3'b111: and
                       (a_opsel == 3'b111) ? (i_op1 & i_op2) :
                       // Default
                       32'b0;

    // Tie o_eq and o_slt to always assert if i_op1 and i_op2 are equal or less than respectively
    assign o_eq         = i_op1 == i_op2;
    assign o_slt        = (i_unsigned) ? i_op1 < i_op2 : $signed(i_op1) < $signed(i_op2);
    // Tie output wires to intermediate reg nets
    assign o_result     = (i_pass) ? i_op2 : l_result;
endmodule

/**
*   Left Shifter
*/
module l_shifter(
    input wire  [31:0]   i_op1,
    input wire  [4:0]    i_op2,
    output wire [31:0]   o_res
);
wire [31:0] res [31:0];
assign res[0] = i_op1;
// Generate a barrel shifter
genvar i;
generate 
    for (i = 1; i < 32; i = i+1) begin
        assign res[i] = i_op1 << i;
    end
endgenerate
assign o_res = res[i_op2];
endmodule

/**
*   Right Shifter
*/
module r_shifter(
    input wire  [31:0]   i_op1,
    input wire  [4:0]    i_op2,
    input wire           i_arith,
    output wire [31:0]   o_res
);
wire [31:0] res [31:0];
assign res[0] = i_op1;
// Generate a barrel shifter
genvar i;
generate
    for (i = 1; i < 32; i = i+1) begin
        // The following line is a little confusing, so I am going to break it down:
        //          First I create a mask of 32 bits of the sign bit
        //          Then I shift that left by the difference between the maximum number of bits (32)
        //              and the value I want to shift, this creates a gap of only zero's that is the length
        //              of the remaining bits of i_op1
        //          Lastly I place those i_op1 bits back in by using a bitwise or
        assign res[i] = (i_arith) ? (({32{i_op1[31]}} << (6'd32 - i)) | (i_op1 >> i)) : i_op1 >> i;
    end
endgenerate
assign o_res = res[i_op2];
endmodule

`default_nettype wire
