module DFF #(
    parameter N = 4
)(
    input clk,
    input rst_n, // synchronous active-low reset
    input [N-1:0] d,
    output reg [N-1:0] q
);
    always @(posedge clk) begin
        if (!rst_n) begin
            q <= {N{1'b0}};
        end else begin
            q <= d;
        end
    end
endmodule