module identity #(
    parameter WIDTH = 8  // You can change width as needed
)(
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    assign out = in;  // Simple identity mapping
endmodule
