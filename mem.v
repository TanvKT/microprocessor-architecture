/**
*   Memory Stage
*/

module mem
(
    // Global clock
    input wire          i_clk,
    input wire          i_rst,
    input wire          i_vld,
    input wire [31:0]   i_inst,
    input wire [4:0]    i_rs1_raddr,
    input wire [4:0]    i_rs2_raddr,
    input wire [31:0]   i_rs1_rdata,
    input wire [31:0]   i_rs2_rdata,
    input wire [31:0]   i_pc,
    input wire [31:0]   i_nxt_pc,

    input wire [2:0]  i_opsel,
    input wire [31:0] i_dmem_addr,
    input wire [31:0] i_dmem_wdata,
    input wire [31:0] i_dmem_rdata,
    input wire        i_mem_reg,
    input wire [31:0] i_res,
    input wire [4:0]  i_rd_waddr,
    input wire        i_rd_wen,

    output wire        o_mem_reg,
    output wire [31:0] o_res,
    output wire [4:0]  o_rd_waddr,
    output wire        o_rd_wen,
    output wire [31:0] o_dmem_rdata,


    output wire [31:0] o_dmem_addr,
    output wire [31:0] o_dmem_wdata,
    output wire [31:0] o_dmem_mask,
    output wire        o_vld,
    output wire [31:0]  o_inst,
    output wire [4:0]   o_rs1_raddr,
    output wire [4:0]   o_rs2_raddr,
    output wire [31:0]  o_rs1_rdata,
    output wire [31:0]  o_rs2_rdata,
    output wire [31:0]  o_pc,
    output wire [31:0]  o_nxt_pc
);
    // Internal Signals
    wire [31:0] dmem_rdata;

    // Memory handler (determines mask and aligns accesses)
    dmem dmem(.i_opsel(i_opsel),
                .i_dmem_addr(i_dmem_addr),
                .i_dmem_wdata(i_dmem_wdata),
                .i_dmem_rdata(i_dmem_rdata),
                .o_dmem_addr(o_dmem_addr),
                .o_dmem_wdata(o_dmem_wdata),
                .o_dmem_rdata(dmem_rdata),
                .o_dmem_mask(o_dmem_mask));

    // MEM/WB Register
    always @(posedge i_clk) begin
        // Only need reset for vld
        if (i_rst) begin
            o_vld <= 1'b0;
        end
        o_mem_reg       <= i_mem_reg;
        o_res           <= i_res;
        o_rd_waddr      <= i_rd_waddr;
        o_rd_wen        <= i_rd_wen;
        o_dmem_rdata    <= dmem_rdata;
        o_vld           <= i_vld;
        o_inst          <= i_inst;
        o_rs1_raddr     <= i_rs1_raddr;
        o_rs2_raddr     <= i_rs2_raddr;
        o_rs1_rdata     <= i_rs1_rdata;
        o_rs2_rdata     <= i_rs2_rdata;
        o_pc            <= i_pc;
        o_nxt_pc        <= i_nxt_pc;
    end

endmodule