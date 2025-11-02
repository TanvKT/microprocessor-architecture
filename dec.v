/**
*   Decode Stage
*/

module dec
(
    // Global clock.
    input  wire         i_clk,
    // Synchronous active-high reset.
    input  wire         i_rst,
    // Next PC
    input  wire [31:0]  i_nxt_pc,
    // Instruction Valid
    input  wire         i_vld,
    input  wire [31:0]  i_pc,

    // Instruction data
    input  wire [31:0]  i_inst,
    input  wire [31:0]  i_dmem_addr,

    // Write back inputs
    input  wire [4:0]   i_rd_waddr,
    input  wire         i_rd_wen,
    input  wire [31:0]  i_rd_wdata,

    // Control outputs
    output wire             o_mem_read,     // Asserted if reading from memory
    output wire             o_mem_reg,      // Asserted if writing memory value to register file
    output wire             o_mem_write,    // Asserted if writing to memory
    output wire             o_imm,          // Asserted on immediate instruction
    output wire             o_auipc,        // Asserted if pc needs to be loaded to rs1
    output wire             o_break,        // Asserted on break instruction
    output wire             o_trap,         // Asserted if invalid instruction given
    output wire             o_branch,       // Asserted if branch instruction

    // ALU Control
    output wire [2:0]       o_opsel,        // Operation select (funct3)
    output wire             o_sub,          // Asserted if subtracting (funct7[5])
    output wire             o_unsigned,     // Asserted if unsigned comparison (funt3[0])
    output wire             o_arith,        // Asserted if arithmetic shift operation (funct7[5])
    output wire             o_pass,         // Asserted if register value needs to be passed through ALU
    output wire             o_mem,          // Asserted on load/store instruction
    output wire             o_jal,          // Asserted on jump instruction
    output wire             o_jalr,         // Asserted on jalr instruction
    output wire [31:0]      o_immediate,    // Immediate value

    // Register Control
    output wire [ 4:0]      o_rd_waddr,     // RD address (inst[11:7])
    output wire             o_rd_wen,       // Asserted when writing to register file
    output wire [31:0]      o_rs1_rdata,    // RS1 Data
    output wire [31:0]      o_rs2_rdata,    // RS2 Data

    // Instruction Valid
    output wire             o_vld,
    output wire             o_hold,

    // Forwarding Signals
    output wire          o_frwd_alu_op1, //forward from alu result op1
    output wire          o_frwd_mem_op1, //forward from memory result op1
    output wire          o_frwd_alu_op2, //forward from alu result op2
    output wire          o_frwd_mem_op2, //forward from memory result op2

    // Pipelining debug signals
    output wire [31:0]      o_inst,
    output wire [4:0]       o_rs1_raddr,
    output wire [4:0]       o_rs2_raddr,
    output wire [31:0]      o_pc,
    output wire [31:0]      o_nxt_pc
);

    // Internal Signals
    wire [31:0] immediate;    // Immediate value
    wire [ 4:0] rs1_raddr;    // RS1 address (inst[19:15])
    wire [ 4:0] rs2_raddr;    // RS2 address (inst[24:20])
    wire [31:0] rs1_rdata;    // RS1 Data
    wire [31:0] rs2_rdata;    // RS2 Data
    wire [5:0]  format;       // One hot encoding for immediate formatting
    wire        mem_read;     // Asserted if reading from memory
    wire        mem_reg;      // Asserted if writing memory value to register file
    wire        mem_write;    // Asserted if writing to memory
    wire        imm;          // Asserted on immediate instruction
    wire        auipc;        // Asserted if pc needs to be loaded to rs1
    wire        break;        // Asserted on break instruction
    wire        trap;         // Asserted if invalid instruction given
    wire        branch;       // Asserted if branch instruction
    wire [2:0]  opsel;        // Operation select (funct3)
    wire        sub;          // Asserted if subtracting (funct7[5])
    wire        _unsigned;    // Asserted if unsigned comparison (funt3[0])
    wire        arith;        // Asserted if arithmetic shift operation (funct7[5])
    wire        pass;         // Asserted if register value needs to be passed through ALU
    wire        mem;          // Asserted on load/store instruction
    wire        jal;          // Asserted on jump instruction
    wire        jalr;         // Asserted on jalr instruction
    wire        rd_wen;       // Asserted if instruction writing to to register
    wire [4:0]  rd_waddr;     // Register file address to write to for current instruction
    wire        if_id_hold;   // Hold IF/ID register
    wire        id_ex_hold;   // Hold ID/EX register

    /* Registers for Pipeline */
    reg         mem_read_ff;
    reg         mem_reg_ff;
    reg         mem_write_ff;
    reg         imm_ff;
    reg         auipc_ff;
    reg         break_ff;
    reg         trap_ff;
    reg         branch_ff;
    reg [2:0]   opsel_ff;
    reg         sub_ff;
    reg         unsigned_ff;
    reg         arith_ff;
    reg         pass_ff;
    reg         mem_ff;
    reg         jal_ff;
    reg         jalr_ff;
    reg [4:0]   rd_waddr_ff;
    reg         rd_wen_ff;
    reg [31:0]  rs1_rdata_ff;
    reg [31:0]  rs2_rdata_ff;
    reg [31:0]  immediate_ff;
    reg         vld_ff;
    reg [31:0]  inst_ff;
    reg [4:0]   rs1_raddr_ff;
    reg [4:0]   rs2_raddr_ff;
    reg [31:0]  pc_ff;
    reg [31:0]  nxt_pc_ff;

    // Immediate Encoder
    imm  u_imm( .i_inst(i_inst), 
                .i_format(format), 
                .o_immediate(immediate));

    // Register File
    rf          #(.BYPASS_EN(1)) u_rf(  
                .i_clk(i_clk), 
                .i_rst(i_rst), 
                .i_rs1_raddr(rs1_raddr), 
                .i_rs2_raddr(rs2_raddr), 
                .o_rs1_rdata(rs1_rdata), 
                .o_rs2_rdata(rs2_rdata),
                .i_rd_wen(i_rd_wen), 
                .i_rd_waddr(i_rd_waddr), 
                .i_rd_wdata(i_rd_wdata));

    // Hazard Detection Unit
    hzrd u_hzrd
    (
                .i_clk(i_clk),
                .i_rst(i_rst),
                .i_rd_wen(rd_wen),
                .i_rd_waddr(rd_waddr),
                .o_if_id_halt(if_id_hold),
                .o_id_ex_halt(id_ex_hold),
                .o_frwd_alu_op1(o_frwd_alu_op1),
                .o_frwd_mem_op1(o_frwd_mem_op1),
                .o_frwd_alu_op2(o_frwd_alu_op2),
                .o_frwd_mem_op2(o_frwd_mem_op2)
    );

    // Control Unit
    ctrl u_ctrl(.i_rst(i_rst),
                .i_nxt_pc(i_nxt_pc),
                .i_dmem_addr(i_dmem_addr),
                .i_imem_rdata(i_inst),
                .i_immediate(immediate),
                .o_mem_read(mem_read), 
                .o_mem_reg(mem_reg), 
                .o_mem_write(dmem_wen), 
                .o_imm(imm), 
                .o_auipc(auipc), 
                .o_break(retire_halt), 
                .o_trap(retire_trap),
                .o_branch(branch),
                .o_opsel(opsel), 
                .o_sub(sub), 
                .o_unsigned(_unsigned), 
                .o_arith(arith), 
                .o_pass(pass), 
                .o_mem(mem), 
                .o_jal(jal),
                .o_jalr(jalr),
                .o_rs1_raddr(rs1_raddr), 
                .o_rs2_raddr(rs2_raddr), 
                .o_rd_waddr(rd_waddr), 
                .o_rd_wen(rd_wen), 
                .o_format(format));

    // ID/EX register
    always @(posedge i_clk) begin
        // Only need reset for certain signals
        if (i_rst) begin
            vld_ff           <= 1'b0;
            mem_read_ff      <= 1'b0;
            mem_write_ff     <= 1'b0;
        end
        if (!id_ex_hold) begin
            mem_read_ff      <= mem_read;
            mem_reg_ff       <= mem_reg;
            mem_write_ff     <= mem_write;
            imm_ff           <= imm;
            auipc_ff         <= auipc;
            break_ff         <= break;
            trap_ff          <= trap;
            branch_ff        <= branch;
            opsel_ff         <= opsel;
            sub_ff           <= sub;
            unsigned_ff      <= _unsigned;
            arith_ff         <= arith;
            pass_ff          <= pass;
            mem_ff           <= mem;
            jal_ff           <= jal;
            jalr_ff          <= jalr;
            rd_waddr_ff      <= rd_waddr;
            rd_wen_ff        <= rd_wen;
            rs1_rdata_ff     <= rs1_rdata;
            rs2_rdata_ff     <= rs2_rdata;
            immediate_ff     <= immediate;
            vld_ff           <= i_vld;
            inst_ff          <= i_inst;
            rs1_raddr_ff     <= rs1_raddr;
            rs2_raddr_ff     <= rs2_raddr;
            pc_ff            <= i_pc;
            nxt_pc_ff        <= i_nxt_pc;
        end
        // Implied else hold
    end

    // Assign hold output 
    assign o_hold = if_id_hold;

    // Assign wire output to reg values
    assign o_mem_read      = mem_read_ff;
    assign o_mem_reg       = mem_reg_ff;
    assign o_mem_write     = mem_write_ff;
    assign o_imm           = imm_ff;
    assign o_auipc         = auipc_ff;
    assign o_break         = break_ff;
    assign o_trap          = trap_ff;
    assign o_branch        = branch_ff;
    assign o_opsel         = opsel_ff;
    assign o_sub           = sub_ff;
    assign o_unsigned      = unsigned_ff;
    assign o_arith         = arith_ff;
    assign o_pass          = pass_ff;
    assign o_mem           = mem_ff;
    assign o_jal           = jal_ff;
    assign o_jalr          = jalr_ff;
    assign o_rd_waddr      = rd_waddr_ff;
    assign o_rd_wen        = rd_wen_ff;
    assign o_rs1_rdata     = rs1_rdata_ff;
    assign o_rs2_rdata     = rs2_rdata_ff;
    assign o_immediate     = immediate_ff;
    assign o_vld           = vld_ff;
    assign o_inst          = inst_ff;
    assign o_rs1_raddr     = rs1_raddr_ff;
    assign o_rs2_raddr     = rs2_raddr_ff;
    assign o_pc            = pc_ff;
    assign o_nxt_pc        = nxt_pc_ff;

endmodule