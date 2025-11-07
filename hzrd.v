/**
*   Hazard Detection Unit
*/

module hzrd
(
    input wire          i_clk,       // Global Clock
    input wire          i_rst,       // Global Reset
    input wire          i_rd_wen,    // Asserted if there is a register file write
    input wire [4:0]    i_rd_waddr,  // Write Address of next instruction
    input wire [4:0]    i_rs1_raddr, // RS1 Address
    input wire [4:0]    i_rs2_raddr, // RS2 Address
    input wire          i_is_load,   // Asserted if load instruction (need to wait for memory)
    input wire          i_flush,     // Asserted if flushing instruction in decode stage

    output wire         o_if_id_halt,       //halt IF/ID pipeline
    output wire         o_id_ex_halt,       //halt ID/EX pipeline
    output wire         o_frwd_alu_op1,     //forward from alu result op1
    output wire         o_frwd_mem_alu_op1, //forward from memory alu result op1
    output wire         o_frwd_mem_op1,     //forward from memory result op1
    output wire         o_frwd_alu_op2,     //forward from alu result op2
    output wire         o_frwd_mem_alu_op2, //forward from memory alu result op2
    output wire         o_frwd_mem_op2      //forward from memory result op2
);

    // Internal Signals
    reg [4:0]   ex_waddr;
    reg         ex_is_load;

    reg [4:0]   mem_waddr;
    reg         mem_is_load;

    wire [4:0]  nxt_waddr;
    wire        nxt_is_load;

    // Detect if current instruction reads from a register
    wire rs1_read = i_rs1_raddr != 5'd0;
    wire rs2_read = i_rs2_raddr != 5'd0;
    
    // Detect RAW hazards for RS1
    wire ex_rs1_hazard  = rs1_read & (i_rs1_raddr == ex_waddr);
    wire mem_rs1_hazard = rs1_read & (i_rs1_raddr == mem_waddr);
    
    // Detect RAW hazards for RS2
    wire ex_rs2_hazard  = rs2_read & (i_rs2_raddr == ex_waddr);
    wire mem_rs2_hazard = rs2_read & (i_rs2_raddr == mem_waddr);
    
    // Load-use hazard: instruction in EX is a load, and current instruction needs that result
    // Must stall for 1 cycle - cannot forward load data until MEM stage
    wire load_use_hazard = ex_is_load & (ex_rs1_hazard | ex_rs2_hazard);
    
    // Stall signals - stall on load-use hazard
    assign o_if_id_halt = load_use_hazard;  // Stall fetch (hold PC and IF/ID register)
    assign o_id_ex_halt = load_use_hazard;  // Insert bubble in EX stage
    
    // Forwarding logic
    // Forward op1
    assign o_frwd_alu_op1       = !ex_is_load & ex_rs1_hazard;
    assign o_frwd_mem_alu_op1   = !mem_is_load & mem_rs1_hazard;
    assign o_frwd_mem_op1       = mem_is_load & mem_rs1_hazard;
    
    // Forward op2
    assign o_frwd_alu_op2       = !ex_is_load & ex_rs2_hazard;
    assign o_frwd_mem_alu_op2   = !mem_is_load & mem_rs2_hazard;
    assign o_frwd_mem_op2       = mem_is_load & mem_rs2_hazard;

    // Assign nxt values for shift register
    assign nxt_waddr    = (load_use_hazard) ? 5'd0 : i_rd_waddr;
    assign nxt_is_load  = (load_use_hazard) ? 1'b0 : i_is_load;

    // Shifting register to keep track of write registers in specific stage
    always @(posedge i_clk) begin
        if (i_rst) begin
            // Default all to zero
            ex_waddr    <= 5'd0;
            ex_is_load  <= 1'b0;

            mem_waddr   <= 5'd0;
            mem_is_load <= 1'b0;
        end
        else begin
            // Else start shifting
            ex_waddr   <= (i_flush) ? 5'd0 : nxt_waddr;
            ex_is_load <= (i_flush) ? 1'b0 : nxt_is_load;

            mem_waddr   <= ex_waddr;
            mem_is_load <= ex_is_load;
        end
    end

endmodule