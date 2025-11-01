/**
*   Fetch Block of Pipeline
*/

module fet
(
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
    input wire          i_hold,

    /* Address Signals */
    // Immediate value used for Branch and Jump
    input wire  [31:0]  i_imm,
    //RS1 input for jalr instruction
    input wire  [31:0]  i_rs1,
    // Next instruction address to execute
    output wire [31:0]  o_imem_raddr,
    // Instruction read from memory
    input wire  [31:0]  i_imem_rdata,
    output wire [31:0]  o_inst,
    // Next PC value to send to control unit to determine if trap needed
    output wire [31:0]  o_nxt_pc,
    // Instruction Valid
    output wire         o_vld
);
    // Internal Signals
    wire        [31:0]  nxt_pc;
    wire                flush;

    // Program Counter
    pc   pc(  .i_clk(i_clk), 
                .i_rst(i_rst),
                .i_eq(i_eq),
                .i_slt(i_slt),
                .i_opsel(i_opsel),
                .i_branch(i_branch),
                .i_jal(i_jal),
                .i_jalr(i_jalr),
                .i_halt(i_halt | i_hold), 
                .i_imm(i_imm),
                .i_rs1(i_rs1_rdata),
                .o_imem_raddr(o_imem_raddr),
                .o_nxt_pc(nxt_pc)
                .o_flush(flush));

    // IF/ID register
    always @(posedge i_clk) begin
        if (i_rst | flush) begin
            //on reset or flush load add x0 and x0 to x0
            o_inst   <= 32'h0x00000033;
            o_vld    <= 1'b0;
        end
        else if (!i_hold) begin
            o_inst   <= i_imem_rdata;
            o_nxt_pc <= nxt_pc;
            o_flush  <= flush;
            o_vld    <= 1'b1;
        end
        // Implied else
    end
endmodule