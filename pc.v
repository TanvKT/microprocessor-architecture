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
    input wire          i_branch,    // Instruction in EX stage is branch
    
    // Asserts if we want to load a specific address into the pc (jump)
    input wire          i_jal,
    input wire          i_jalr,
    // Asserts if processor needs to halt
    input wire          i_halt,
    input wire          i_hold,

    // Asserts on cache miss
    input wire          i_inst_busy,
    input wire          i_data_busy,

    /* Address Signals */
    // Immediate value used for Branch and Jump
    input wire  [31:0]  i_immediate_de, // From decode stage
    input wire  [31:0]  i_immediate_ex, // From execute stage
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
reg  [31:0] busy_addr;
reg  [31:0] prev_addr;
reg         inst_busy_ff;
reg         data_busy_ff;
wire        busy_ff        = inst_busy_ff | data_busy_ff;
wire        inst_busy_rise = !inst_busy_ff & i_inst_busy;
wire        data_busy_rise = !data_busy_ff & i_data_busy;
wire        inst_busy_fall = i_inst_busy & inst_busy_ff;
wire        data_busy_fall = i_data_busy & data_busy_ff;
wire        busy_rise      = inst_busy_rise | data_busy_rise;
wire        busy_fall      = inst_busy_fall | data_busy_fall;

/* PC holding FF */
always @(posedge i_clk) begin
    if (i_rst) begin
        curr_addr    <= RESET_ADDR;
        busy_addr    <= RESET_ADDR;
        prev_addr    <= RESET_ADDR;
        inst_busy_ff <= 1'b0;
        data_busy_ff <= 1'b0;
    end
    else if ((br_vld | i_jal | i_jalr) & !(busy_ff & !(!i_inst_busy & inst_busy_ff)))
        curr_addr <= nxt_addr + 3'd4;
    else if (!i_halt & !i_hold & !busy_fall)  // Hold PC on Halt or stall
        curr_addr <= nxt_addr;
    // Implied else hold

    // Busy holding flops
    inst_busy_ff  <= i_inst_busy;
    data_busy_ff  <= i_data_busy;

    if (inst_busy_rise)
        busy_addr <= o_imem_raddr;
    else if (data_busy_rise & (i_jal | i_jalr | br_vld)) begin
        busy_addr <= prev_addr;
        curr_addr <= nxt_addr;
    end
    else if (data_busy_rise) begin
        busy_addr <= prev_addr;
        curr_addr <= curr_addr;
    end

    // Store previous address
    prev_addr <= curr_addr;
end

/* Determine Branch validity */
assign br_vld       = i_branch    & ((i_eq   & (i_opsel == 3'b000)) | (~i_eq & (i_opsel == 3'b001)) | // Need to invert result if bne taken
                                     (i_slt  & ((i_opsel == 3'b100) | (i_opsel == 3'b110))) |         // If Less Than instruction
                                     (~i_slt & ((i_opsel == 3'b101) | (i_opsel == 3'b111))));         // If Greater Than or Equal

/* Logic to determine next addr */
wire [31:0] jalr_v      = i_rs1 + i_immediate_de;
assign nxt_addr         = (busy_ff & !(!i_inst_busy & inst_busy_ff))         ? curr_addr + 3'd4 :                    //Busy takes precedence over jumps
                          (br_vld)          ? curr_addr + i_immediate_ex - 4'd8 :   //In this case we branch based offset, if taking this instruction
                                                                                    //        immediate is always aligned so no need to fix here
                          (i_jal)           ? curr_addr + i_immediate_de - 3'd4 :
                          (i_jalr)          ? {jalr_v[31:1], 1'b0} :                //Need to clear lsb to ensure aligned
                                               curr_addr + 3'd4;                    //In this case we increment PC by one instruction (default)

/* Link output wire */
assign o_imem_raddr = ((i_jal | i_jalr | br_vld) & data_busy_rise)  ? prev_addr :
                      (data_busy_rise)                              ? prev_addr :
                      ((i_jal | i_jalr | br_vld) & !(busy_ff & !(!i_inst_busy & inst_busy_ff)))        ? nxt_addr :
                      (busy_fall)                                   ? busy_addr :
                      (i_hold)                                      ? curr_addr - 3'd4 : 
                                                                      curr_addr;
assign o_nxt_pc     = nxt_addr;
assign o_flush      = br_vld;  // Flush if branch valid

endmodule