module relu_binary_clk (
    input clk,                   // Clock signal
    input reset,                 // Synchronous reset
    input [7:0] in_data,         // 8-bit signed input
    output reg [7:0] out_data    // 8-bit output
);

always @(posedge clk) begin
    if (reset)
        out_data <= 8'b00000000;
    else if (in_data[7] == 1'b0)
        out_data <= in_data;    // Pass through positive
    else
        out_data <= 8'b00000000; // Set zero for negative
end

endmodule
