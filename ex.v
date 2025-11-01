/**
*   Execute Stage
*/

module ex
(
    // Global clock.
    input  wire         i_clk,
    input  wire         i_rst,
    input  wire         i_vld,

    input  wire         i_auipc,
    input  wire         i_imm,
    input  wire         i_jal,
    input  wire         i_jalr,
    input  wire         i_mem_reg,
    input  wire         i_mem_read,
    input  wire         i_mem_write,
    input  wire [31:0]  i_pc,
    input  wire [31:0]  i_rs1_rdata,
    input  wire [31:0]  i_rs2_rdata,
    input  wire [31:0]  i_alu_res,
    input  wire [31:0]  i_mem_res,
    input  wire [31:0]  i_immediate,
    input  wire [2:0]   i_opsel,
    input  wire [4:0]   i_rd_waddr,
    input  wire         i_rd_wen,
    input  wire         i_branch,
    input  wire         i_sub,
    input  wire         i_unsigned,
    input  wire         i_pass,
    input  wire         i_mem,

    input wire          i_frwd_alu_op1, //forward from alu result op1
    input wire          i_frwd_mem_op1, //forward from memory result op1
    input wire          i_frwd_alu_op2, //forward from alu result op2
    input wire          i_frwd_mem_op2, //forward from memory result op2

    input wire [31:0]      i_inst;
    input wire [4:0]       i_rs1_raddr;
    output wire [4:0]      i_rs2_raddr;
    input wire [31:0]      i_nxt_pc;

    output wire         o_slt,
    output wire         o_eq,
    output wire [31:0]  o_res,
    output wire [4:0]   o_rd_waddr,
    output wire         o_rd_wen,
    output wire         o_mem_reg,
    output wire         o_mem_read,
    output wire         o_mem_write,
    output wire [2:0]   o_opsel,
    output wire         o_branch,
    output wire [31:0]  o_dmem_addr,
    output wire [31:0]  o_dmem_wdata,
    output wire         o_vld

    output wire [31:0]  o_inst;
    output wire [4:0]   o_rs1_raddr;
    output wire [4:0]   o_rs2_raddr;
    output wire [31:0]  o_rs1_rdata;
    output wire [31:0]  o_rs2_rdata;
    output wire [31:0]  o_pc;
    output wire [31:0]  o_nxt_pc;
);
    // Internal Signals
    wire    [31:0] op1;
    wire    [31:0] op2;
    wire    [31:0] res;

    // Arithmetic Logic Unit Operand Selection (forwarding unit)
    frwd frwd( .i_auipc(i_auipc),
                .i_imm(i_imm),
                .i_jal(i_jal),
                .i_jalr(i_jalr),
                .i_mem_reg(i_mem_reg),
                .i_pc(i_pc),
                .i_rs1_rdata(i_rs1_rdata),
                .i_rs2_rdata(i_rs2_rdata),
                .i_alu_res(i_alu_res),
                .i_mem_res(i_mem_res),
                .i_immediate(i_immediate),
                .i_frwd_alu_op1(i_frwd_alu_op1),
                .i_frwd_mem_op1(i_frwd_mem_op1),
                .i_frwd_alu_op2(i_frwd_alu_op2),
                .i_frwd_mem_op2(i_frwd_mem_op2),
                .o_op1(op1),
                .o_op2(op2));

    // Arithmetic Logic Unit
    alu  alu( .i_opsel(i_opsel), 
                .i_sub(i_sub), 
                .i_unsigned(i_unsigned), 
                .i_arith(i_arith), 
                .i_pass(i_pass), 
                .i_mem(i_mem), 
                .i_auipc(i_auipc),
                .i_op1(op1), 
                .i_op2(op2), 
                .o_result(res), 
                .o_eq(o_eq), 
                .o_slt(o_slt));

    // EX/MEM Register
    always @(posedge i_clk) begin
        // Only need reset for certain signals
        if (i_rst) begin
            o_vld       <= 1'b0;
            o_mem_read  <= 1'b0;
            o_mem_write <= 1'b0;
        end
        o_res           <= res;
        o_mem_write     <= i_mem_write;
        o_opsel         <= i_opsel;
        o_mem_reg       <= i_mem_reg;
        o_mem_read      <= i_mem_read;
        o_mem_write     <= i_mem_write;
        o_dmem_addr     <= res;
        o_dmem_wdata    <= op2;
        o_rd_waddr      <= i_rd_waddr;
        o_rd_wen        <= i_rd_wen;
        o_vld           <= i_vld;
        o_inst          <= i_inst;
        o_rs1_raddr     <= i_rs1_raddr;
        o_rs2_raddr     <= i_rs2_raddr;
        o_rs1_rdata     <= i_rs1_rdata;
        o_rs2_rdata     <= i_rs1_rdata;
        o_pc            <= i_pc;
        o_nxt_pc        <= i_nxt_pc;
    end

endmodule