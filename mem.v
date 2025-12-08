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

    input wire [2:0]    i_opsel_w, //opsel arrives at different times if read or write
    input wire [2:0]    i_opsel_r,
    input wire [31:0]   i_dmem_addr,
    input wire [31:0]   i_dmem_wdata,
    input wire [31:0]   i_dmem_rdata,
    input wire          i_dmem_ren,
    input wire          i_dmem_wen,
    input wire          i_dmem_ren_ff,
    input wire          i_dmem_wen_ff,
    input wire          i_mem_reg,
    input wire [31:0]   i_res,
    input wire [4:0]    i_rd_waddr,
    input wire          i_rd_wen,

    input wire          i_inst_busy,
    input wire          i_data_busy,
    input wire          i_break,

    output wire         o_mem_reg,
    output wire [31:0]  o_res,
    output wire [4:0]   o_rd_waddr,
    output wire         o_rd_wen,
    output wire [31:0]  o_dmem_rdata,


    output wire [31:0]  o_dmem_addr,
    output wire [31:0]  o_dmem_wdata,
    output wire [3:0]   o_dmem_mask,
    output wire         o_dmem_wen,
    output wire         o_dmem_ren,
    output wire         o_vld,
    output wire [31:0]  o_inst,
    output wire [4:0]   o_rs1_raddr,
    output wire [4:0]   o_rs2_raddr,
    output wire [31:0]  o_rs1_rdata,
    output wire [31:0]  o_rs2_rdata,
    output wire [31:0]  o_dmem_addr_ff,
    output wire [3:0]   o_dmem_mask_ff,
    output wire         o_dmem_ren_ff,
    output wire         o_dmem_wen_ff,
    output wire [31:0]  o_dmem_wdata_ff,
    output wire [31:0]  o_dmem_rdata_ff,
    output wire [31:0]  o_dmem_rdata_raw,
    output wire [31:0]  o_pc,
    output wire [31:0]  o_nxt_pc,
    output wire         o_break
);
    // Register Signals
    reg          mem_reg_ff;
    reg [31:0]   res_ff;
    reg [4:0]    rd_waddr_ff;
    reg          rd_wen_ff;
    reg          vld_ff;
    reg [31:0]   inst_ff;
    reg [4:0]    rs1_raddr_ff;
    reg [4:0]    rs2_raddr_ff;
    reg [31:0]   rs1_rdata_ff;
    reg [31:0]   rs2_rdata_ff;
    reg [31:0]   dmem_addr_ff;
    reg [3:0]    dmem_mask_ff;
    wire [3:0]   dmem_mask_r;
    reg [31:0]   dmem_addr_ff1;
    reg [3:0]    dmem_mask_ff1;
    reg          dmem_ren_ff;
    reg          dmem_wen_ff;
    reg [31:0]   dmem_wdata_ff;
    reg [31:0]   dmem_wdata_ff1;
    reg [31:0]   dmem_rdata_ff;
    reg [31:0]   dmem_rdata_raw_ff;
    reg [31:0]   pc_ff;
    reg [31:0]   nxt_pc_ff;
    reg          break_ff;
    reg          data_busy_ff;
    wire         data_busy_fall = i_data_busy & data_busy_ff;

    // Memory handler (determines mask and aligns accesses)
    dmem dmem(.i_opsel_r(i_opsel_r),
                .i_opsel_w(i_opsel_w),
                .i_dmem_addr_w(i_dmem_addr),
                .i_dmem_addr_r(dmem_addr_ff),
                .i_rs2_rdata(i_dmem_wdata),
                .i_dmem_rdata(i_dmem_rdata),
                .o_dmem_addr(o_dmem_addr),
                .o_dmem_wdata(o_dmem_wdata),
                .o_dmem_rdata(o_dmem_rdata),
                .o_dmem_mask_w(o_dmem_mask),
                .o_dmem_mask_r(dmem_mask_r));
    assign o_dmem_wen = i_dmem_wen;
    assign o_dmem_ren = i_dmem_ren;

    // MEM/WB Register
    always @(posedge i_clk) begin
        // Only need reset for vld
        if (i_rst) begin
            vld_ff      <= 1'b0;
            rd_wen_ff   <= 1'b0;
            rd_waddr_ff <= 5'd0;
            res_ff      <= 32'd0;
            mem_reg_ff  <= 1'b0;
            data_busy_ff <= 1'b0;
            break_ff     <= 1'b0;
        end
        else if (!i_data_busy) begin
            mem_reg_ff       <= i_mem_reg;
            res_ff           <= i_res;
            rd_waddr_ff      <= i_rd_waddr;
            rd_wen_ff        <= i_rd_wen;
            vld_ff           <= i_vld;
            inst_ff          <= i_inst;
            rs1_raddr_ff     <= i_rs1_raddr;
            rs2_raddr_ff     <= i_rs2_raddr;
            rs1_rdata_ff     <= i_rs1_rdata;
            rs2_rdata_ff     <= i_rs2_rdata;
            dmem_addr_ff     <= o_dmem_addr;
            dmem_mask_ff     <= o_dmem_mask;
            dmem_addr_ff1    <= dmem_addr_ff;
            dmem_mask_ff1    <= (i_dmem_wen_ff) ? dmem_mask_ff : dmem_mask_r;
            dmem_ren_ff      <= i_dmem_ren_ff;
            dmem_wen_ff      <= i_dmem_wen_ff;
            dmem_wdata_ff    <= o_dmem_wdata;
            dmem_wdata_ff1   <= dmem_wdata_ff;
            dmem_rdata_ff    <= o_dmem_rdata;
            dmem_rdata_raw_ff <= i_dmem_rdata;
            pc_ff            <= i_pc;
            nxt_pc_ff        <= i_nxt_pc;
            break_ff         <= i_break;
        end
        if (i_data_busy)
            vld_ff           <= 1'b0;

        data_busy_ff         <= i_data_busy;
    end

    // Assign Registers to wires
    assign o_mem_reg       = mem_reg_ff;
    assign o_res           = res_ff;
    assign o_rd_waddr      = rd_waddr_ff;
    assign o_rd_wen        = rd_wen_ff;
    assign o_vld           = vld_ff;
    assign o_inst          = inst_ff;
    assign o_rs1_raddr     = rs1_raddr_ff;
    assign o_rs2_raddr     = rs2_raddr_ff;
    assign o_rs1_rdata     = rs1_rdata_ff;
    assign o_rs2_rdata     = rs2_rdata_ff;
    assign o_dmem_addr_ff  = dmem_addr_ff1;
    assign o_dmem_mask_ff  = dmem_mask_ff1;
    assign o_dmem_ren_ff   = dmem_ren_ff;
    assign o_dmem_wen_ff   = dmem_wen_ff;
    assign o_dmem_wdata_ff = dmem_wdata_ff1;
    assign o_dmem_rdata_ff = dmem_rdata_ff;
    assign o_dmem_rdata_raw = dmem_rdata_raw_ff;
    assign o_pc            = pc_ff;
    assign o_nxt_pc        = nxt_pc_ff;
    assign o_break         = break_ff;

endmodule