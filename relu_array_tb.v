`timescale 1ns / 1ps

module testbench_relu_binary_clk_array;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter BATCH_SIZE = 1;
    parameter CHANNELS = 1;
    parameter HEIGHT = 2;
    parameter WIDTH = 2;

    localparam TENSOR_SIZE = BATCH_SIZE * CHANNELS * HEIGHT * WIDTH;
    localparam TOTAL_WIDTH = TENSOR_SIZE * DATA_WIDTH;

    // Inputs
    reg clk;
    reg reset;
    reg [TOTAL_WIDTH-1:0] in_tensor;

    // Outputs
    wire [TOTAL_WIDTH-1:0] out_tensor;

    // Instantiate the module under test
    relu_binary_clk_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNELS(CHANNELS),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .in_tensor(in_tensor),
        .out_tensor(out_tensor)
    );

    // Clock generation
    always #5 clk = ~clk;

    integer i;

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        in_tensor = 0;

        // Wait 2 clock cycles
        #10;
        reset = 0;

        // Apply test input values
        // Let's test 4 elements (since HEIGHT=2, WIDTH=2)
        // Format: MSB is sign bit. 0xFF = -1 (should output 0), 0x01 = 1 (should pass)
        // Values: [0xFF, 0x7F, 0x01, 0x80] => [-1, 127, 1, -128]
        in_tensor[7:0]    = 8'hFF;  // -1
        in_tensor[15:8]   = 8'h7F;  // 127
        in_tensor[23:16]  = 8'h01;  // 1
        in_tensor[31:24]  = 8'h80;  // -128

        // Wait for a few clock cycles to observe output
        #50;

        // Display input and output
        $display("Time = %0t", $time);
        $display("Input Tensor:  %h", in_tensor);
        $display("Output Tensor: %h", out_tensor);

        // End simulation
        $finish;
    end

endmodule
