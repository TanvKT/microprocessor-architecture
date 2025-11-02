`default_nettype none

/**
*   Program Counter Module
*   Determines next instruction address to be grabbed based on control inputs
*/
module pc #( 
    // Address to reset pc to when i_rst high
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire         i_clk,
    // Synchronous active-high reset.
    input  wire         i_rst,

    /* Control Signals for Program Counter */
    // Branching
    input wire          i_eq,           // OP1 and OP2 Equal
    input wire          i_slt,          // OP1 < OP2
    input wire [2:0]    i_opsel,        // Branch opsel
    input wire          i_branch,       // Current Instruction is branch

    
    // Asserts if we want to load a specific address into the pc (jump)
    input wire          i_jal,
    input wire          i_jalr,
    // Asserts if processor needs to halt
    input wire          i_halt,

    /* Address Signals */
    // Immediate value used for Branch and Jump
    input wire  [31:0]  i_immediate,
    //RS1 input for jalr instruction
    input wire  [31:0]  i_rs1,
    // Next instruction address to execute
    output wire [31:0]  o_imem_raddr,
    // Next PC value to send to control unit to determine if trap needed
    output wire [31:0]  o_nxt_pc,
    // Determines if we need to flush IF/ID register
    output wire         o_flush
);

/* Internal Signals */
wire        br_vld;
wire [31:0] nxt_addr;
reg  [31:0] curr_addr;

/* PC holding FF */
always @(posedge i_clk) begin
    if (i_rst)
        curr_addr <= RESET_ADDR;
    else if (i_halt)
        curr_addr <= curr_addr;  // Hold PC on Halt
    else
        curr_addr <= nxt_addr;
end

/* Determine Branch validity */
// B-Type
assign br_vld       = i_branch &  ((i_eq   & (i_opsel == 3'b000)) | (~i_eq & (i_opsel == 3'b001)) | // Need to invert result if bne taken
                                    (i_slt  & ((i_opsel == 3'b100) | (i_opsel == 3'b110))) |         // If Less Than instruction
                                    (~i_slt & ((i_opsel == 3'b101) | (i_opsel == 3'b111))));         // If Greater Than or Equal

/* Logic to determine next addr */
wire [31:0] jalr_v      = i_rs1 + i_immediate;
assign nxt_addr         = (br_vld | i_jal)    ? curr_addr + i_immediate :   //In this case we branch based offset, if taking this instruction
                                                                            //        immediate is always aligned so no need to fix here
                          (i_jalr)          ? {jalr_v[31:1], 1'b0} :        //Need to clear lsb to ensure aligned
                                               curr_addr + 3'd4;            //In this case we increment PC by one instruction (default)

/* Link output wire */
assign o_imem_raddr = curr_addr;
assign o_nxt_pc     = nxt_addr;

endmodule