module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available synchronously after
    // the next clock edge.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the instruction memory read is
    // now synchronous.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // after the next clock edge, this will reflect the contents of memory
    // at the specified address, for the bytes enabled by the mask. When
    // read enable is not asserted, or for bytes not set in the mask, the
    // value is undefined.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the data memory read is
    // now synchronous.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The following data memory retire interface is used to record the
    // memory transactions completed by the instruction being retired.
    // As such, it mirrors the transactions happening on the main data
    // memory interface (o_dmem_* and i_dmem_*) but is delayed to match
    // the retirement of the instruction. You can hook this up by just
    // registering the main dmem interface signals into the writeback
    // stage of your pipeline.
    //
    // All these fields are don't-care for instructions that do not
    // access data memory (o_retire_dmem_ren and o_retire_dmem_wen
    // not asserted).
    // NOTE: This interface is new for phase 5 in order to account for
    // the delay between data memory accesses and instruction retire.
    //
    // The 32-bit data memory address accessed by the instruction.
    output wire [31:0] o_retire_dmem_addr,
    // The byte masked used for the data memory access.
    output wire [ 3:0] o_retire_dmem_mask,
    // Asserted if the instruction performed a read (load) from data memory.
    output wire        o_retire_dmem_ren,
    // Asserted if the instruction performed a write (store) to data memory.
    output wire        o_retire_dmem_wen,
    // The 32-bit data read from memory by a load instruction.
    output wire [31:0] o_retire_dmem_rdata,
    // The 32-bit data written to memory by a store instruction.
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

    // For specifics on what each signal means look at control unit
    // Fetch
    wire [31:0]             fe_inst;
    wire [31:0]             fe_nxt_pc;
    wire                    fe_vld;
    wire [31:0]             fe_pc;

    // Decode
    wire                    de_mem_read;
    wire                    de_mem_reg;
    wire                    de_mem_write;
    wire                    de_imm;
    wire                    de_auipc;
    wire                    de_break;
    wire                    de_trap;
    wire                    de_branch;
    wire [2:0]              de_opsel;
    wire                    de_sub;
    wire                    de_unsigned;
    wire                    de_arith;
    wire                    de_pass;
    wire                    de_mem;
    wire                    de_jal;
    wire                    de_jalr;
    wire [31:0]             de_immediate;
    wire [4:0]              de_rd_waddr;
    wire                    de_rd_wen;
    wire [31:0]             de_rs1_rdata;
    wire [31:0]             de_rs2_rdata;
    wire                    de_vld;
    wire                    de_hold;
    wire [31:0]             de_inst;
    wire [4:0]              de_rs1_raddr;
    wire [4:0]              de_rs2_raddr;
    wire [31:0]             de_pc;
    wire [31:0]             de_nxt_pc;

    // Execute
    wire                    ex_slt;
    wire                    ex_eq;
    wire [31:0]             ex_res;
    wire                    ex_mem_reg;
    wire                    ex_mem_read;
    wire                    ex_mem_write;
    wire [2:0]              ex_opsel;
    wire [4:0]              ex_rd_waddr;
    wire                    ex_rd_wen;
    wire                    ex_branch;
    wire [31:0]             ex_dmem_addr;
    wire [31:0]             ex_dmem_wdata;
    wire                    ex_vld;
    wire [31:0]             ex_inst;
    wire [4:0]              ex_rs1_raddr;
    wire [4:0]              ex_rs2_raddr;
    wire [31:0]             ex_rs1_rdata;
    wire [31:0]             ex_rs2_rdata;
    wire [31:0]             ex_pc;
    wire [31:0]             ex_nxt_pc;

    // Memory
    wire                    mem_mem_reg;
    wire [31:0]             mem_res;
    wire [31:0]             mem_dmem_rdata;
    wire [4:0]              mem_rd_waddr;
    wire                    mem_rd_wen;
    wire                    mem_vld;
    wire [31:0]             mem_inst;
    wire [4:0]              mem_rs1_raddr;
    wire [4:0]              mem_rs2_raddr;
    wire [31:0]             mem_rs1_rdata;
    wire [31:0]             mem_rs2_rdata;
    wire [31:0]             mem_rd_wdata;
    wire [31:0]             mem_dmem_addr;
    wire [3:0]              mem_dmem_mask;
    wire                    mem_dmem_ren;
    wire                    mem_dmem_wen;
    wire [31:0]             mem_dmem_wdata;
    wire [31:0]             mem_pc;
    wire [31:0]             mem_nxt_pc;

    // Write-Back
    wire [31:0]             wb_res;
    wire [4:0]              wb_rd_waddr;
    wire                    wb_rd_wen;
    wire                    wb_vld;
    wire [31:0]             wb_inst;
    wire [4:0]              wb_rs1_raddr;
    wire [4:0]              wb_rs2_raddr;
    wire [31:0]             wb_rs1_rdata;
    wire [31:0]             wb_rs2_rdata;
    wire [31:0]             wb_rd_wdata;
    wire [31:0]             wb_dmem_addr;
    wire [3:0]              wb_dmem_mask;
    wire                    wb_dmem_ren;
    wire                    wb_dmem_wen;
    wire [31:0]             wb_dmem_rdata;
    wire [31:0]             wb_dmem_wdata;
    wire [31:0]             wb_pc;
    wire [31:0]             wb_nxt_pc;

    /* Instantiate Sub Modules */
    // Fetch stage
    fet u_fet(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_eq(ex_eq),
        .i_slt(ex_slt),
        .i_opsel(ex_opsel),
        .i_branch(ex_branch),
        .i_jal(de_jal),
        .i_jalr(de_jalr),
        .i_halt(de_break),
        .i_hold(de_hold),
        .i_immediate(de_immediate),
        .i_rs1(de_rs1_rdata),
        .o_imem_raddr(o_imem_raddr),
        .i_imem_rdata(i_imem_rdata),
        .o_inst(fe_inst),
        .o_nxt_pc(fe_nxt_pc),
        .o_pc(fe_pc),
        .o_vld(fe_vld)
    );

    // Decode stage
    dec u_dec(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_nxt_pc(fe_nxt_pc),
        .i_vld(fe_vld),
        .i_pc(fe_pc),
        .i_inst(fe_inst),
        .i_dmem_addr(ex_dmem_addr),
        .i_rd_waddr(wb_rd_waddr),
        .i_rd_wen(wb_rd_wen),
        .i_rd_wdata(wb_res),
        .i_ex_alu_res(ex_res),
        .i_mem_alu_res(mem_res),
        .i_mem_res(mem_dmem_rdata),
        .o_mem_read(de_mem_read),
        .o_mem_reg(de_mem_reg),
        .o_mem_write(de_mem_write),
        .o_imm(de_imm),
        .o_auipc(de_auipc),
        .o_break(de_break),
        .o_trap(de_trap),
        .o_branch(de_branch),
        .o_opsel(de_opsel),
        .o_sub(de_sub),
        .o_unsigned(de_unsigned),
        .o_arith(de_arith),
        .o_pass(de_pass),
        .o_mem(de_mem),
        .o_jal(de_jal),
        .o_jalr(de_jalr),
        .o_immediate(de_immediate),
        .o_rd_waddr(de_rd_waddr),
        .o_rd_wen(de_rd_wen),
        .o_rs1_rdata(de_rs1_rdata),
        .o_rs2_rdata(de_rs2_rdata),
        .o_vld(de_vld),
        .o_hold(de_hold),
        .o_inst(de_inst),
        .o_rs1_raddr(de_rs1_raddr),
        .o_rs2_raddr(de_rs2_raddr),
        .o_pc(de_pc),
        .o_nxt_pc(de_nxt_pc)
    );

    // Execute stage
    ex u_ex(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_vld(de_vld),
        .i_auipc(de_auipc),
        .i_imm(de_imm),
        .i_jalr(de_jalr),
        .i_jal(de_jal),
        .i_mem_reg(de_mem_reg),
        .i_mem_read(de_mem_read),
        .i_mem_write(de_mem_write),
        .i_pc(de_pc),
        .i_nxt_pc(de_nxt_pc),
        .i_inst(de_inst),
        .i_rs1_rdata(de_rs1_rdata),
        .i_rs2_rdata(de_rs2_rdata),
        .i_rs1_raddr(de_rs1_raddr),
        .i_rs2_raddr(de_rs2_raddr),
        .i_immediate(de_immediate),
        .i_opsel(de_opsel),
        .i_rd_waddr(de_rd_waddr),
        .i_rd_wen(de_rd_wen),
        .i_branch(de_branch),
        .i_sub(de_sub),
        .i_unsigned(de_unsigned),
        .i_pass(de_pass),
        .i_mem(de_mem),
        .o_slt(ex_slt),
        .o_eq(ex_eq),
        .o_res(ex_res),
        .o_mem_reg(ex_mem_reg),
        .o_mem_read(ex_mem_read),
        .o_mem_write(ex_mem_write),
        .o_opsel(ex_opsel),
        .o_rd_waddr(ex_rd_waddr),
        .o_rd_wen(ex_rd_wen),
        .o_branch(ex_branch),
        .o_dmem_addr(ex_dmem_addr),
        .o_dmem_wdata(ex_dmem_wdata),
        .o_vld(ex_vld),
        .o_inst(ex_inst),
        .o_rs1_raddr(ex_rs1_raddr),
        .o_rs2_raddr(ex_rs2_raddr),
        .o_rs1_rdata(ex_rs1_rdata),
        .o_rs2_rdata(ex_rs2_rdata),
        .o_pc(ex_pc),
        .o_nxt_pc(ex_nxt_pc)
    );

    // Memory stage
    mem u_mem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_vld(ex_vld),
        .i_inst(ex_inst),
        .i_rs1_raddr(ex_rs1_raddr),
        .i_rs2_raddr(ex_rs2_raddr),
        .i_rs1_rdata(ex_rs1_rdata),
        .i_rs2_rdata(ex_rs2_rdata),
        .i_pc(ex_pc),
        .i_nxt_pc(ex_nxt_pc),
        .i_opsel(ex_opsel),
        .i_rd_waddr(ex_rd_waddr),
        .i_rd_wen(ex_rd_wen),
        .i_dmem_addr(ex_dmem_addr),
        .i_dmem_wdata(ex_dmem_wdata),
        .i_dmem_rdata(i_dmem_rdata),
        .i_dmem_ren(ex_mem_read),
        .i_dmem_wen(ex_mem_write),
        .i_mem_reg(ex_mem_reg),
        .i_res(ex_res),
        .o_mem_reg(mem_mem_reg),
        .o_res(mem_res),
        .o_rd_waddr(mem_rd_waddr),
        .o_rd_wen(mem_rd_wen),
        .o_dmem_rdata(mem_dmem_rdata),
        .o_dmem_addr(o_dmem_addr),
        .o_dmem_wdata(o_dmem_wdata),
        .o_dmem_mask(o_dmem_mask),
        .o_dmem_wen(o_dmem_wen),
        .o_dmem_ren(o_dmem_ren),
        .o_vld(mem_vld),
        .o_inst(mem_inst),
        .o_rs1_raddr(mem_rs1_raddr),
        .o_rs2_raddr(mem_rs2_raddr),
        .o_rs1_rdata(mem_rs1_rdata),
        .o_rs2_rdata(mem_rs2_rdata),
        .o_dmem_addr_ff(mem_dmem_addr),
        .o_dmem_mask_ff(mem_dmem_mask),
        .o_dmem_ren_ff(mem_dmem_ren),
        .o_dmem_wen_ff(mem_dmem_wen),
        .o_dmem_wdata_ff(mem_dmem_wdata),
        .o_pc(mem_pc),
        .o_nxt_pc(mem_nxt_pc)
    );

    // Write-back stage
    wb u_wb(
        .i_rst(i_rst),
        .i_mem_reg(mem_mem_reg),
        .i_dmem_rdata(mem_dmem_rdata),
        .i_res(mem_res),
        .i_rd_waddr(mem_rd_waddr),
        .i_rd_wen(mem_rd_wen),
        .i_vld(mem_vld),
        .i_inst(mem_inst),
        .i_rs1_raddr(mem_rs1_raddr),
        .i_rs2_raddr(mem_rs2_raddr),
        .i_rs1_rdata(mem_rs1_rdata),
        .i_rs2_rdata(mem_rs2_rdata),
        .i_dmem_addr(mem_dmem_addr),
        .i_dmem_mask(mem_dmem_mask),
        .i_dmem_ren(mem_dmem_ren),
        .i_dmem_wen(mem_dmem_wen),
        .i_dmem_wdata(mem_dmem_wdata),
        .i_pc(mem_pc),
        .i_nxt_pc(mem_nxt_pc),
        .o_res(wb_res),
        .o_rd_waddr(wb_rd_waddr),
        .o_rd_wen(wb_rd_wen),
        .o_vld(wb_vld),
        .o_inst(wb_inst),
        .o_rs1_raddr(wb_rs1_raddr),
        .o_rs2_raddr(wb_rs2_raddr),
        .o_rs1_rdata(wb_rs1_rdata),
        .o_rs2_rdata(wb_rs2_rdata),
        .o_dmem_addr(wb_dmem_addr),
        .o_dmem_mask(wb_dmem_mask),
        .o_dmem_ren(wb_dmem_ren),
        .o_dmem_wen(wb_dmem_wen),
        .o_dmem_wdata(wb_dmem_wdata),
        .o_dmem_rdata(wb_dmem_rdata),
        .o_pc(wb_pc),
        .o_nxt_pc(wb_nxt_pc)
    );

    // Assign HART Output Signals
    assign o_retire_valid       = wb_vld;
    assign o_retire_inst        = wb_inst;
    assign o_retire_halt        = de_break;
    assign o_retire_rs1_raddr   = wb_rs1_raddr;
    assign o_retire_rs2_raddr   = wb_rs2_raddr;
    assign o_retire_rs1_rdata   = wb_rs1_rdata;
    assign o_retire_rs2_rdata   = wb_rs2_rdata;
    assign o_retire_rd_waddr    = wb_rd_waddr;
    assign o_retire_rd_wdata    = wb_rd_wdata;
    assign o_retire_dmem_addr   = wb_dmem_addr;
    assign o_retire_dmem_mask   = wb_dmem_mask;
    assign o_retire_dmem_ren    = wb_dmem_ren;
    assign o_retire_dmem_wen    = wb_dmem_wen;
    assign o_retire_dmem_rdata  = wb_dmem_rdata;
    assign o_retire_dmem_wdata  = wb_dmem_wdata;
    assign o_retire_pc          = wb_pc;
    assign o_retire_next_pc     = wb_nxt_pc;
endmodule

`default_nettype wire
