`default_nettype none

// The register file is effectively a single cycle memory with 32-bit words
// and depth 32. It has two asynchronous read ports, allowing two independent
// registers to be read at the same time combinationally, and one synchronous
// write port, allowing a register to be written to on the next clock edge.
//
// The register `x0` is hardwired to zero.
// NOTE: This can be implemented either by silently discarding writesto
// address 5'd0, or by muxing the output to zero when reading from that
// address.
module rf #(
    // When this parameter is set to 1, "RF bypass" mode is enabled. This
    // allows data at the write port to be observed at the read ports
    // immediately without having to wait for the next clock edge. This is
    // a common forwarding optimization in a pipelined core (phase 5), but will
    // cause a single-cycle processor to behave incorrectly. You are required
    // to implement and test both modes. In phase 4, you will disable this
    // parameter, before enabling it in phase 6.
    parameter BYPASS_EN = 0
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Both read register ports are asynchronous (zero-cycle). That is, read
    // data is visible combinationally without having to wait for a clock.
    //
    // The read ports are *independent* and can read two different registers
    // (but of course, also the same register if needed).
    //
    // Register `x0` is hardwired to zero, so reading from address 5'd0
    // should always return 32'd0 on either port regardless of any writes.
    //
    // Register read port 1, with input address [0, 31] and output data.
    input  wire [ 4:0] i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    // Register read port 2, with input address [0, 31] and output data.
    input  wire [ 4:0] i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    // The register write port is synchronous. When write is enabled, the
    // data at the write port will be written to the specified register
    // at the next clock edge. When the writen enable is low, the register
    // file should remain unchanged at the clock edge.
    //
    // Write register enable, address [0, 31] and input data.
    input  wire        i_rd_wen,
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);
    
    // Internal Signals
    wire        [31:0] ff_en;               //32-bit vector of enable signals to flip flops
    wire        [31:0] ff_wr_data;          //32-bit width wires to connect write inputs to flip flops
    wire        [31:0] mem[31:0];           //length 32 array of 32-bit width wires to connect read outputs to flip flops

    // Generate instantiation of Flip Flops
    genvar i;
    generate
        for (i = 1; i < 32; i=i+1) begin : gen_en_ffs
            en_ff u_en_ff (.i_clk(i_clk), .i_rst(i_rst), .i_en(ff_en[i]), .i_wr_data(ff_wr_data), .o_rd_data(mem[i]));
            // Logic for address to enable signals
            assign ff_en[i] = (i_rd_wen && (i == i_rd_waddr)) ? 1'b1 : 1'b0;  //Note ff_en[0] has no real function, but we don't save any bits by getting rid of it
        end
    endgenerate

    // Hard Coding logic for x0 register
    assign mem[0] = 32'b0;

    // Assign write input to addressing logic
    assign ff_wr_data = i_rd_wdata;

    // The following logic allows different instantiations based on if parameter BYPASS_EN is enabled
    generate
        if (BYPASS_EN) begin
            assign o_rs1_rdata = ((i_rd_wen) && (i_rs1_raddr == i_rd_waddr) && (i_rs1_raddr != 5'd0)) ? i_rd_wdata : mem[i_rs1_raddr];
            assign o_rs2_rdata = ((i_rd_wen) && (i_rs2_raddr == i_rd_waddr) && (i_rs2_raddr != 5'd0)) ? i_rd_wdata : mem[i_rs2_raddr];
        end
        else begin
            assign o_rs1_rdata = mem[i_rs1_raddr];
            assign o_rs2_rdata = mem[i_rs2_raddr];
        end
    endgenerate
endmodule

// Enable gated Flip Flop for register data storage
module en_ff
(
    input wire          i_clk,      // Global clock
    input wire          i_rst,      // Synchronous active-high reset
    input wire          i_en,       // Write enable
    input wire  [31:0]  i_wr_data,  // Write data
    output wire [31:0]  o_rd_data   // Read data
);
    //Internal signals
    reg         [31:0]  d_ff;       // Flip Flop for data storage

    // Sequential Logic Block
    always @(posedge i_clk) begin
        if (i_rst) begin
            d_ff <= 32'b0;
        end
        else if (i_en) begin
            d_ff <= i_wr_data;
        end
        // Implied Else
    end

    // Assign output wire to flip flop Q
    assign o_rd_data = d_ff;

endmodule

`default_nettype wire
