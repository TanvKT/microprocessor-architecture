`default_nettype none

/* Control Logic Block */
module ctrl (
    // instruction input
    input wire              i_rst,
    input wire [31:0]       i_nxt_pc,
    input wire [31:0]       i_dmem_addr,
    input wire [31:0]       i_imem_rdata,
    input wire [31:0]       i_immediate,

    /* Output Signals */
    // General Control
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

    // Register Control
    output wire [ 4:0]      o_rs1_raddr,    // RS1 address (inst[19:15])
    output wire [ 4:0]      o_rs2_raddr,    // RS2 address (inst[24:20])
    output wire [ 4:0]      o_rd_waddr,     // RD address (inst[11:7])
    output wire             o_rd_wen,       // Asserted when writing to register file

    // Immediate Control
    output wire [5:0]       o_format        // One hot encoding for immediate formatting
);
// Initial Parse of Instruction
wire [6:0] opcode   = i_imem_rdata[6:0];
wire [2:0] funct3   = i_imem_rdata[14:12];
wire [6:0] funct7   = i_imem_rdata[31:25];

// Need to determine what instructions we are doing based on opcode
wire is_r_type    = (opcode == 7'b0110011); // register-reg ALU
wire is_itype_alu = (opcode == 7'b0010011); // immediate ALU
wire is_load      = (opcode == 7'b0000011); // loads
wire is_store     = (opcode == 7'b0100011); // stores
wire is_branch    = (opcode == 7'b1100011); // branches
wire is_lui       = (opcode == 7'b0110111); // LUI
wire is_auipc     = (opcode == 7'b0010111); // AUIPC
wire is_jal       = (opcode == 7'b1101111); // JAL
wire is_jalr      = (opcode == 7'b1100111); // JALR
wire is_system    = (opcode == 7'b1110011); // SYSTEM (ECALL/EBREAK/CSR)

// Checks to be used to determine if instruction valid
// This looks a bit messy since we can't use case statements, but it basically
//      just ensures that the opcode is a valid RV32I instruction
wire opcode_allowed     = is_r_type | is_itype_alu | is_load | is_store | is_branch
                            | is_lui | is_auipc | is_jal | is_jalr | is_system;

// PC always has to be 4-byte aligned
wire pc_misaligned      = i_nxt_pc[1:0] != 2'b00;

// Memory Accesses can be unaligned or 2-byte aligned for byte and half-word respectively
wire byte               = funct3[1:0] == 2'b00;
wire half_word          = funct3[0];
wire dmem_misaligned    = o_mem & ((i_dmem_addr[0] & ~byte) | (i_dmem_addr[1] & ~half_word));

// Determine if instruction fields are valid
// This logic is checking each possible instruction field combination to ensure correct encoding
// It is hard to read, but we are just checking to see if it matches any valid combination
wire invalid_r_type     = is_r_type & ((((funct3 == 3'b000) | (funct3 == 3'b101)) & ((funct7 != 7'b010_0000) & (funct7 != 7'd0))) 
                                    | ((funct3 != 3'b000) & (funct3 != 3'b101) & (funct7 != 7'd0)));
wire invalid_i_type     = is_itype_alu & ((funct3 == 3'b101 & ((funct7 != 7'b010_0000) & (funct7 != 7'd0)))
                                    | (funct3 == 3'b001 & funct7 != 7'd0));
wire invalid_l_type     = is_load & (funct3 != 3'b000) & (funct3 != 3'b001) & (funct3 != 3'b010) & (funct3 != 3'b100) & (funct3 != 3'b101);
wire invalid_s_type     = is_store & (funct3 != 3'b000) & (funct3 != 3'b001) & (funct3 != 3'b010);
wire invalid_b_type     = is_branch & (funct3 != 3'b000) & (funct3 != 3'b001) & (funct3 != 3'b100) & (funct3 != 3'b101) & (funct3 != 3'b110) & (funct3 != 3'b111);

// Parse instruction further into sub-parts to ease readability
assign o_sub        = is_r_type & funct7[5];                    //funct7 always determines if sub (only R-Type)
assign o_arith      = funct7[5];                                //funct7 is also used to determine if using arithmetic shift
assign o_opsel      = funct3;                                   //funct3 determines opsel within alu
assign o_unsigned   = o_opsel[0];                               //funct3[0] also determines if we take unsigned path
assign o_rs1_raddr  = i_imem_rdata[19:15];                      //RS1
assign o_rs2_raddr  = i_imem_rdata[24:20];                      //RS2
assign o_rd_waddr   = (o_rd_wen) ? i_imem_rdata[11:7] : 5'd0;   //RD (need to tie low for test bench purposes)

// B-Type
assign o_branch     = is_branch;

// I-Type Load value from mem to reg
assign o_mem_read   = is_load; 
assign o_mem_reg    = is_load;

// S-Type
assign o_mem_write  = is_store;

// If load or store instruction, indicate memory function
assign o_mem        = is_load | is_store;

// Indicate that immediate needs to be loaded into RS2
assign o_imm        = is_itype_alu | is_lui | is_auipc | is_load | is_store;

// Indicate PC needs to be loaded into RS1
assign o_auipc      = is_auipc | is_jal | is_jalr;

// System Call EBREAK Instruction (Assuming any system call instruction is valid)
assign o_break      = ~i_rst & is_system;

// Trigger on any invalid instruction or on misaligned PC or mem access
assign o_trap       = ~i_rst & (~opcode_allowed | pc_misaligned |  dmem_misaligned | 
                                invalid_r_type | invalid_i_type | invalid_l_type | invalid_s_type | invalid_b_type);

// Indicate that we need to pass immediate through ALU
assign o_pass       = is_lui;

// Indicate specific jump instructions (These signals affect which operands are loaded to RS1 and RS2)
assign o_jal        = is_jal;
assign o_jalr       = is_jalr;

// All instructions that have rd field
assign o_rd_wen     = is_r_type | is_itype_alu | is_lui | is_auipc | is_load | is_jal | is_jalr;

// Format Encoding
assign o_format     = {
        is_jal,                             // format[5] = J
        (is_lui | is_auipc),                // format[4] = U
        is_branch,                          // format[3] = B
        is_store,                           // format[2] = S
        (is_itype_alu | is_load | is_jalr), // format[1] = I
        1'b0                                // format[0] = R  
    };
endmodule
