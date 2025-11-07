`default_nettype none

/**
*   Forwarding Unit
*   
*   This module selects inputs to ALU based on control signals
*           control signals either come from control unit or hazard detection unit
*   
*   In the case where a Read-After-Write Hazard is detected, we can reduce cpi by
*           forwarding outputs from memory or alu output to alu input
*/

module frwd
(
    input wire          i_auipc,        //load pc into op1
    input wire          i_jal,          //load 4 into op2
    input wire          i_jalr,
    input wire          i_mem_reg,      //select ALU or memory result
    input wire [31:0]   i_pc,           //program counter value
    input wire [31:0]   i_rs1_rdata,    //rs1 data from rf
    input wire [31:0]   i_rs2_rdata,    //rs2 data from rf

    input wire          i_frwd_alu_op1,     //forward from alu result op1
    input wire          i_frwd_mem_alu_op1, //forward from mem alu res op1
    input wire          i_frwd_mem_op1,     //forward from memory result op1
    input wire          i_frwd_alu_op2,     //forward from alu result op2
    input wire          i_frwd_mem_alu_op2, //forward from memory resutl op2
    input wire          i_frwd_mem_op2,     //forward from memory result op2

    input wire [31:0]   i_ex_alu_res,   //alu in ex stage output
    input wire [31:0]   i_mem_alu_res,  //alu in mem stage output
    input wire [31:0]   i_mem_res,      //memory output

    output wire [31:0]  o_op1,          //alu op1
    output wire [31:0]  o_op2           //alu op2
);

    // Data being fed to ALU changes based on specific instruction
    assign o_op1                  =   (i_frwd_alu_op1)      ?   i_ex_alu_res :
                                      (i_frwd_mem_alu_op1)  ?   i_mem_alu_res :
                                      (i_frwd_mem_op1)      ?   i_mem_res :
                                      (i_auipc)             ?   i_pc :
                                                                i_rs1_rdata;


    assign o_op2                  =   (i_frwd_alu_op2)      ?   i_ex_alu_res :
                                      (i_frwd_mem_alu_op2)  ?   i_mem_alu_res :
                                      (i_frwd_mem_op2)      ?   i_mem_res :
                                      (i_jal | i_jalr)      ?   32'd4       :       // When we are jumping, pc is loaded to op1
                                                                            // So we need to store pc + 4 in rd
                                                                i_rs2_rdata;

endmodule