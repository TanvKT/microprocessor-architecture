/**
*   Hazard Detection Unit
*/

module hzrd
(
    input wire          i_clk,      // Global Clock
    input wire          i_rst,      // Global Reset
    input wire          i_rd_wen,   // Asserted if there is a register file write
    input wire [4:0]    i_rd_waddr, // Write Address of next instruction

    output wire         o_if_id_halt,   //halt IF/ID pipeline
    output wire         o_id_ex_halt,   //halt ID/EX pipeline
    output wire         o_frwd_alu_op1, //forward from alu result op1
    output wire         o_frwd_mem_op1, //forward from memory result op1
    output wire         o_frwd_alu_op2, //forward from alu result op2
    output wire         o_frwd_mem_op2  //forward from memory result op2
);

// Internal Signals
reg [4:0] dec_waddr;
reg [4:0] ex_waddr;
reg [4:0] mem_waddr;
reg [4:0] wb_waddr;

endmodule