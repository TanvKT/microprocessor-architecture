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
    input  wire [31:0]  i_immediate,
    input  wire [2:0]   i_opsel,
    input  wire [4:0]   i_rd_waddr,
    input  wire         i_rd_wen,
    input  wire         i_branch,
    input  wire         i_sub,
    input  wire         i_unsigned,
    input  wire         i_pass,
    input  wire         i_mem,

    input wire [31:0]      i_inst,
    input wire [4:0]       i_rs1_raddr,
    output wire [4:0]      i_rs2_raddr,
    input wire [31:0]      i_nxt_pc,

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
    output wire         o_vld,

    output wire [31:0]  o_inst,
    output wire [4:0]   o_rs1_raddr,
    output wire [4:0]   o_rs2_raddr,
    output wire [31:0]  o_rs1_rdata,
    output wire [31:0]  o_rs2_rdata,
    output wire [31:0]  o_pc,
    output wire [31:0]  o_nxt_pc
);
    // Internal Signals
    wire    [31:0] op1;
    wire    [31:0] op2;
    wire    [31:0] res;

    // Registers
    reg [31:0]   res_ff;
    reg          mem_write_ff;
    reg [2:0]    opsel_ff;
    reg          mem_reg_ff;
    reg          mem_read_ff;
    reg [31:0]   dmem_addr_ff;
    reg [31:0]   dmem_wdata_ff;
    reg [4:0]    rd_waddr_ff;
    reg          rd_wen_ff;
    reg          vld_ff;
    reg [31:0]   inst_ff;
    reg [4:0]    rs1_raddr_ff;
    reg [4:0]    rs2_raddr_ff;
    reg [31:0]   rs1_rdata_ff;
    reg [31:0]   rs2_rdata_ff;
    reg [31:0]   pc_ff;
    reg [31:0]   nxt_pc_ff;

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
            vld_ff       <= 1'b0;
            mem_read_ff  <= 1'b0;
            mem_write_ff <= 1'b0;
        end
        res_ff           <= res;
        opsel_ff         <= i_opsel;
        mem_reg_ff       <= i_mem_reg;
        mem_read_ff      <= i_mem_read;
        mem_write_ff     <= i_mem_write;
        dmem_addr_ff     <= res;
        dmem_wdata_ff    <= op2;
        rd_waddr_ff      <= i_rd_waddr;
        rd_wen_ff        <= i_rd_wen;
        vld_ff           <= i_vld;
        inst_ff          <= i_inst;
        rs1_raddr_ff     <= i_rs1_raddr;
        rs2_raddr_ff     <= i_rs2_raddr;
        rs1_rdata_ff     <= i_rs1_rdata;
        rs2_rdata_ff     <= i_rs1_rdata;
        pc_ff            <= i_pc;
        nxt_pc_ff        <= i_nxt_pc;
    end

    // Assign wires to register
    assign o_res           = res_ff;
    assign o_opsel         = opsel_ff;
    assign o_mem_reg       = mem_reg_ff;
    assign o_mem_read      = mem_read_ff;
    assign o_mem_write     = mem_write_ff;
    assign o_dmem_addr     = dmem_addr_ff;
    assign o_dmem_wdata    = dmem_wdata_ff;
    assign o_rd_waddr      = rd_waddr_ff;
    assign o_rd_wen        = rd_wen_ff;
    assign o_vld           = vld_ff;
    assign o_inst          = inst_ff;
    assign o_rs1_raddr     = rs1_raddr_ff;
    assign o_rs2_raddr     = rs2_raddr_ff;
    assign o_rs1_rdata     = rs1_rdata_ff;
    assign o_rs2_rdata     = rs1_rdata_ff;
    assign o_pc            = pc_ff;
    assign o_nxt_pc        = nxt_pc_ff;

endmodule