`default_nettype none

module cache (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // External memory interface. See hart interface for details. This
    // interface is nearly identical to the phase 5 memory interface, with the
    // exception that the byte mask (`o_mem_mask`) has been removed. This is
    // no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    // Interface to CPU hart. This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache
    // miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire        o_busy,
    // 32-bit read/write address to access from the cache. This should be
    // 32-bit aligned (i.e. the two LSBs should be zero). See `i_req_mask` for
    // how to perform half-word and byte accesses to unaligned addresses.
    input  wire [31:0] i_req_addr,
    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input  wire        i_req_ren,
    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input  wire        i_req_wen,
    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input  wire [ 3:0] i_req_mask,
    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input  wire [31:0] i_req_wdata,
    // The 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
    // These parameters are equivalent to those provided in the project
    // 6 specification. Feel free to use them, but hardcoding these numbers
    // rather than using the localparams is also permitted, as long as the
    // same values are used (and consistent with the project specification).
    //
    // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 2 ** S;   // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 32 - O - S;   // 23 bit tag
    localparam D = 2 ** O / 4;   // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0];
    reg       lru   [DEPTH - 1:0];

    // Isolate tag, set, and offset bits from address
    wire [31:0]     aligned_addr = {i_req_addr[31:2], 2'b00};
    wire [T-1:0]    tag     = aligned_addr[31     : 32-T];
    wire [S-1:0]    set     = aligned_addr[31-T   : 32-T-S];
    wire [O-1:0]    offset  = aligned_addr[31-T-S : 0];

    // Define Cache States
    localparam COMPARE  = 1'b0;
    localparam ALLOCATE = 1'b1;
    reg  state;
    reg  nxt_state;

    // Using behavioral verliog here to simply readability
    reg l_busy;
    reg l_valid;
    reg l_valid_ff;
    reg l_ready;
    reg [$clog2(D)-1:0] l_w_line;
    reg [$clog2(D)-1:0] l_r_cnt;
    reg l_set_i;
    reg set_i_ff;
    reg l_store;
    reg l_load;
    reg [31:0] l_rdata;
    reg [31:0] rdata_ff;
    reg l_mem_ren;
    reg l_mem_wen;
    reg [31:0] l_alloc_addr;

    always @(*) begin
        // Set defaults to avoid latching
        nxt_state   = COMPARE;
        l_busy      = 1'b0;
        l_valid     = 1'b0;
        l_ready     = 1'b0;
        l_set_i     = 1'b0;
        l_rdata     = 32'd0;
        l_mem_ren   = 1'b0;
        l_mem_wen   = 1'b0;

        case(state)
            COMPARE : begin
                if (i_req_wen | i_req_ren) begin
                    // check if data is valid
                    // Assuming from main memory piepline that memory always ready if in COMPARE state
                    if (!valid[set][0]) begin
                        // cache miss, grab data from main memory
                        nxt_state = ALLOCATE;
                        l_busy = 1'b1;
                        l_mem_ren = 1'b1;
                        l_set_i = 1'b0;
                    end
                    // way 1 should never be valid if way 0 is invalid
                    else if (!valid[set][1] & (valid[set][0] & (tags0[set] != tag))) begin
                        nxt_state = ALLOCATE;
                        l_busy = 1'b1;
                        l_mem_ren = 1'b1;
                        l_set_i = 1'b1;
                    end
                    // check if tag matches
                    else if (tags0[set] == tag) begin
                        if (i_req_wen) begin
                            l_ready = 1'b1;
                            l_mem_wen = 1'b1;
                        end
                        l_rdata = datas0[set][(offset >> 2)];
                        nxt_state = COMPARE;
                        l_set_i = 1'b0;
                    end
                    else if (tags1[set] == tag) begin
                        if (i_req_wen) begin
                            l_ready = 1'b1;
                            l_mem_wen = 1'b1;
                        end
                        l_rdata = datas1[set][(offset >> 2)];
                        nxt_state = COMPARE;
                        l_set_i = 1'b1;
                    end
                    // tags didn't match with valid data, need to eject from set
                    else begin
                        // cache miss, grab data from main memory
                        nxt_state = ALLOCATE;
                        l_busy = 1'b1;
                        l_mem_ren = 1'b1;
                        l_set_i = !lru[set]; // want the set the was not most recently used
                    end
                end
            end
            ALLOCATE : begin
                //cache has missed, need to load whole block from memory
                if ((l_w_line == {($clog2(D)){1'b1}}) & i_mem_ready & l_valid_ff) begin
                    if (l_store) begin
                        l_mem_wen = 1'b1;
                        l_ready = 1'b1;
                    end
                    else begin
                        l_rdata = (l_set_i) ? datas1[set][(offset >> 2)] : datas0[set][(offset >> 2)];
                    end
                    l_busy = 1'b1;  //keep busy asserted to avoid queing next write until back in compare state
                    nxt_state = COMPARE;
                end
                // if not fully read block, stay in allocate
                else begin
                    nxt_state = ALLOCATE;
                    l_ready = (l_r_cnt == {($clog2(D)){1'b1}}) ? 1'b0 : i_mem_ready;
                    l_valid = i_mem_valid;
                    l_mem_ren = l_ready;
                    l_busy = 1'b1;
                end
            end
            // don't need default since only 2 states
            
            // Don't need default here since all possible values covered
        endcase
    end

    integer i;
    always @(posedge i_clk) begin
        // if in reset ensure that flush cache (only need to set valid bits to 0)
        if (i_rst) begin
            for (i = 0; i < DEPTH; i=i+1) begin
                valid[i] <= 2'b00;
            end
            state <= COMPARE;
            // Don't need to reset other signals since they are set on state transition and not used otherwise
        end
        // when accessing cache need to store if we are reading or writing to memory
        if (nxt_state == COMPARE) begin
            lru[set]        <= set_i_ff;
        end
        if (state != ALLOCATE & nxt_state == ALLOCATE) begin
            l_w_line        <= {($clog2(D)){1'b0}};
            l_r_cnt         <= {($clog2(D)){1'b0}};
            l_alloc_addr    <= {aligned_addr[31:32-T-S], {O{1'b0}}};
        end
        if (state == COMPARE) begin
            set_i_ff        <= l_set_i;
            l_load          <= i_req_ren;
            l_store         <= i_req_wen;
        end
        // data is ready from main memory
        if (l_valid_ff) begin
            if (!set_i_ff) begin // first way of set
                datas0[set][l_w_line]   <= i_mem_rdata;
                tags0[set]              <= tag;
                valid[set][0]           <= 1'b1;
                lru[set]                <= 1'b0;    // we set lru to 0 to indicate first way of set was picked
            end
            else begin
                datas1[set][l_w_line]   <= i_mem_rdata;
                tags1[set]              <= tag;
                valid[set][1]           <= 1'b1;
                lru[set]                <= 1'b1;    // lru to 1 to indicate second way of set picked
            end
            l_w_line                    <= l_w_line + 1'b1;
        end
        // main memory ready for another request
        if (l_ready) begin
            l_alloc_addr    <= l_alloc_addr + 3'd4;
            l_r_cnt         <= l_r_cnt + 1'b1;
            // If we are in write state, then ensure new data is written to cache as well
            if (state == ALLOCATE & nxt_state == COMPARE) begin
                if (!set_i_ff) begin
                    datas0[set][(offset >> 2)] <= o_mem_wdata;
                end
                else begin
                    datas1[set][(offset >> 2)] <= o_mem_wdata;
                end
            end
            else if (nxt_state == COMPARE) begin
                if (!l_set_i) begin
                    datas0[set][(offset >> 2)] <= o_mem_wdata;
                end
                else begin
                    datas1[set][(offset >> 2)] <= o_mem_wdata;
                end
            end
        end
        
        // Always moving to next state
        state       <= nxt_state;
        l_valid_ff  <= l_valid;
        rdata_ff   <= l_rdata;
    end

    // masking logic for partial-word accesses
    // Write register value to memory
    assign o_mem_wdata  =   (state == COMPARE & i_req_mask == 4'b1000) ? {i_req_wdata[31:24], l_rdata[23:0]} :
                            (state == COMPARE & i_req_mask == 4'b0100) ? {l_rdata[31:24], i_req_wdata[23:16], l_rdata[15:0]} :
                            (state == COMPARE & i_req_mask == 4'b0010) ? {l_rdata[31:16], i_req_wdata[15:8], l_rdata[7:0]}  :
                            (state == COMPARE & i_req_mask == 4'b0001) ? {l_rdata[31:8], i_req_wdata[7:0]} :
                            (state == COMPARE & i_req_mask == 4'b1100) ? {i_req_wdata[31:16], l_rdata[15:0]} :
                            (state == COMPARE & i_req_mask == 4'b0011) ? {l_rdata[31:16], i_req_wdata[15:0]} :
                            (i_req_mask == 4'b1000) ? {i_req_wdata[31:24], rdata_ff[23:0]} :
                            (i_req_mask == 4'b0100) ? {rdata_ff[31:24], i_req_wdata[23:16], rdata_ff[15:0]} :
                            (i_req_mask == 4'b0010) ? {rdata_ff[31:16], i_req_wdata[15:8], rdata_ff[7:0]}  :
                            (i_req_mask == 4'b0001) ? {rdata_ff[31:8], i_req_wdata[7:0]} :
                            (i_req_mask == 4'b1100) ? {i_req_wdata[31:16], rdata_ff[15:0]} :
                            (i_req_mask == 4'b0011) ? {rdata_ff[31:16], i_req_wdata[15:0]} :
                                                      i_req_wdata;         

    // Assign behavioral logic to output wires
    assign o_busy       = l_busy;
    assign o_mem_ren    = l_mem_ren;
    assign o_mem_wen    = l_mem_wen;
    assign o_mem_addr   = (nxt_state == COMPARE) ? aligned_addr : l_alloc_addr;
    assign o_res_rdata  = rdata_ff;
endmodule

`default_nettype wire
