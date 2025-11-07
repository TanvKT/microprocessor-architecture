`default_nettype none

/*
*   Memory Masking Module
*   Enables functionality of sub-word writes
*/
module dmem(
    input wire [2:0]        i_opsel_r,      // funct3 opsel for read
    input wire [2:0]        i_opsel_w,      // funct3 opsel for write
    input wire [31:0]       i_dmem_addr_w,  // Memory address used for write
    input wire [31:0]       i_dmem_addr_r,  // Memory address used for read
    input wire [31:0]       i_rs2_rdata,    // rs2 data for write
    input wire [31:0]       i_dmem_rdata,   // Unmasked memory read data

    output wire [31:0]      o_dmem_addr,    // Aligned Memory Address
    output wire [31:0]      o_dmem_wdata,   // Memory write data
    output wire [31:0]      o_dmem_rdata,   // Memory read data
    output wire [3:0]       o_dmem_mask_w,  // Memory access mask for write
    output wire [3:0]       o_dmem_mask_r   // Memory access mask for read
);
    /* Internal wires to ease readability */
    wire byte_r       =   i_opsel_r[1:0] == 2'b00;
    wire half_word_r  =   i_opsel_r[0];
    wire zero_ext     =   i_opsel_r[2];
    wire byte_w       =   i_opsel_w[1:0] == 2'b00;
    wire half_word_w  =   i_opsel_w[0];

    /* Masking Block (Used for sub-word load/store) */
    // Mask incoming or outgoing data to only hold desired data length
    // The WISC25 SPEC says we aren't doing unaligned memory accesses, but the gradescope tests test it, so we need
    //      to ensure using aligned address
    // Only consider valid alignment, if bit0 of addr is set a trap will occur
    assign o_dmem_mask_w =  (byte_w &  (i_dmem_addr_w[1:0] == 2'b00))   ? 4'b0001 :    //  4-byte alligned
                            (byte_w &  (i_dmem_addr_w[1:0] == 2'b01))   ? 4'b0010 :    //  Unaligned
                            (byte_w &  (i_dmem_addr_w[1:0] == 2'b10))   ? 4'b0100 :    //  2-byte alligned
                            (byte_w &  (i_dmem_addr_w[1:0] == 2'b11))   ? 4'b1000 :    //  Unaligned
                            (half_word_w & ~i_dmem_addr_w[1])           ? 4'b0011 :    //  4-byte alligned
                            (half_word_w &  i_dmem_addr_w[1])           ? 4'b1100 :    //  2-byte alligned
                                                                          4'b1111;     //  Default full word

    assign o_dmem_mask_r =  (byte_r &  (i_dmem_addr_r[1:0] == 2'b00))   ? 4'b0001 :    //  4-byte alligned
                            (byte_r &  (i_dmem_addr_r[1:0] == 2'b01))   ? 4'b0010 :    //  Unaligned
                            (byte_r &  (i_dmem_addr_r[1:0] == 2'b10))   ? 4'b0100 :    //  2-byte alligned
                            (byte_r &  (i_dmem_addr_r[1:0] == 2'b11))   ? 4'b1000 :    //  Unaligned
                            (half_word_r & ~i_dmem_addr_r[1])           ? 4'b0011 :    //  4-byte alligned
                            (half_word_r &  i_dmem_addr_r[1])           ? 4'b1100 :    //  2-byte alligned
                                                                          4'b1111;     //  Default full word
    
    // Always access data at 4-byte aligned address
    // So we can use mask to read specific part of data word
    // If it is already aligned, this doesn't actually change anything
    // If address is 2-byte aligned we end up at the 4-byte aligned address before it
    //          meaning the mask is reading from the lower part of the word
    assign o_dmem_addr =    {i_dmem_addr_w[31:2], 2'b00};

    // Write register value to memory
    assign o_dmem_wdata =   (o_dmem_mask_w == 4'b1000) ? i_rs2_rdata << 24 :  // Shift so that memory in least significant
                            (o_dmem_mask_w == 4'b0100) ? i_rs2_rdata << 16 :  //      bit of register is aligned with mask
                            (o_dmem_mask_w == 4'b0010) ? i_rs2_rdata << 8  :
                            (o_dmem_mask_w == 4'b1100) ? i_rs2_rdata << 16 :
                                                         i_rs2_rdata;         // No change needed if 4-byte aligned

    // Loading in values from memory, need to sign or zero extend based on mask
    assign o_dmem_rdata =   (~zero_ext & (o_dmem_mask_r == 4'b0001)) ? {{24{i_dmem_rdata[7]}},  i_dmem_rdata[7:0]}    :
                            (~zero_ext & (o_dmem_mask_r == 4'b0010)) ? {{24{i_dmem_rdata[15]}}, i_dmem_rdata[15:8]}   :
                            (~zero_ext & (o_dmem_mask_r == 4'b0100)) ? {{24{i_dmem_rdata[23]}}, i_dmem_rdata[23:16]}  :
                            (~zero_ext & (o_dmem_mask_r == 4'b1000)) ? {{24{i_dmem_rdata[31]}}, i_dmem_rdata[31:24]}  :
                            (~zero_ext & (o_dmem_mask_r == 4'b0011)) ? {{16{i_dmem_rdata[15]}},  i_dmem_rdata[15:0]}  :
                            (~zero_ext & (o_dmem_mask_r == 4'b0110)) ? {{16{i_dmem_rdata[23]}}, i_dmem_rdata[23:8]}   :
                            (~zero_ext & (o_dmem_mask_r == 4'b1100)) ? {{16{i_dmem_rdata[31]}}, i_dmem_rdata[31:16]}  :
                            // Zero Extend
                            (zero_ext & (o_dmem_mask_r == 4'b0001))  ? {{24{1'b0}}, i_dmem_rdata[7:0]}    :
                            (zero_ext & (o_dmem_mask_r == 4'b0010))  ? {{24{1'b0}}, i_dmem_rdata[15:8]}   :
                            (zero_ext & (o_dmem_mask_r == 4'b0100))  ? {{24{1'b0}}, i_dmem_rdata[23:16]}  :
                            (zero_ext & (o_dmem_mask_r == 4'b1000))  ? {{24{1'b0}}, i_dmem_rdata[31:24]}  :
                            (zero_ext & (o_dmem_mask_r == 4'b0011))  ? {{16{1'b0}}, i_dmem_rdata[15:0]}   :
                            (zero_ext & (o_dmem_mask_r == 4'b0110))  ? {{16{1'b0}}, i_dmem_rdata[23:8]}   :
                            (zero_ext & (o_dmem_mask_r == 4'b1100))  ? {{16{1'b0}}, i_dmem_rdata[31:16]}  :
                            // Default full word
                            i_dmem_rdata;
endmodule