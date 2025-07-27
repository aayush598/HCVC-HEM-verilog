`timescale 1ns / 1ps

module tb_relu_binary_clk;

reg clk;
reg reset;
reg [7:0] in_data;
wire [7:0] out_data;

// Instantiate the module
relu_binary_clk uut (
    .clk(clk),
    .reset(reset),
    .in_data(in_data),
    .out_data(out_data)
);

// Clock generation: 10ns period
initial begin
    clk = 1;
    forever #5 clk = ~clk;
end

initial begin
    $monitor("Time = %0t | Reset = %b | Input = %b (%0d) | Output = %b (%0d)", 
             $time, reset, in_data, $signed(in_data), out_data, $signed(out_data));

    // Initialize
    reset = 1;
    in_data = 8'b00000000;


    // Release reset
    reset = 0;

    // Apply negative inputs
    in_data = 8'b10000000; #10;  // -128
    in_data = 8'b11111111; #10;  // -1

    // Zero input
    in_data = 8'b00000000; #10;  // 0

    // Positive inputs
    in_data = 8'b00000001; #10;  // 1
    in_data = 8'b00101010; #10;  // 42
    in_data = 8'b01111111; #10;  // 127

    // Apply reset again
    reset = 1; #10;
    reset = 0;

    in_data = 8'b00000010; #10;  // 2

    $finish;
end

endmodule
