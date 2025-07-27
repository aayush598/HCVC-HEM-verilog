module sigmoid (
    input wire [7:0] in,       // 8-bit unsigned address for LUT
    output reg [15:0] out      // 16-bit fixed-point output
);

    reg [15:0] lut [0:255];    // LUT with 256 entries

    initial begin
        $readmemh("sigmoid_lut.mem", lut); // Read LUT from hex memory file
    end

    always @(*) begin
        out = lut[in];
    end

endmodule
