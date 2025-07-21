`timescale 1ns/1ps

module tb_leaky_relu_array;

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter BATCH_SIZE = 1;
    parameter CHANNELS   = 1;
    parameter HEIGHT     = 2;
    parameter WIDTH      = 2;
    parameter TOTAL_ELEMS = BATCH_SIZE * CHANNELS * HEIGHT * WIDTH;

    // Signals
    reg clk;
    reg rst;
    reg  [TOTAL_ELEMS*DATA_WIDTH-1:0] in_tensor;
    wire [TOTAL_ELEMS*DATA_WIDTH-1:0] out_tensor;

    integer i;
    reg signed [DATA_WIDTH-1:0] input_data    [0:TOTAL_ELEMS-1];
    reg signed [DATA_WIDTH-1:0] expected_data [0:TOTAL_ELEMS-1];
    reg signed [DATA_WIDTH-1:0] actual;

    // DUT
    leaky_relu_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNELS(CHANNELS),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .in_tensor(in_tensor),
        .out_tensor(out_tensor)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $display("Starting testbench for leaky_relu_array");

        clk = 0;
        rst = 1;

        // Wait a bit and release reset
        #10 rst = 0;

        // Initialize input data (fixed-point signed integers)
        // Values: [-64, -32, 0, 32]
        input_data[0] = -64;  // expected: -64 >> 7 = -1
        input_data[1] = -32;  // expected: -32 >> 7 = -1
        input_data[2] = 0;    // expected: 0
        input_data[3] = 32;   // expected: 32

        expected_data[0] = -1;
        expected_data[1] = -1;
        expected_data[2] = 0;
        expected_data[3] = 32;

        // Pack into flat input
        for (i = 0; i < TOTAL_ELEMS; i = i + 1)
            in_tensor[i*DATA_WIDTH +: DATA_WIDTH] = input_data[i];

        // Wait for processing
        #20;

        // Display and verify outputs
        $display("---- Output ----");
        for (i = 0; i < TOTAL_ELEMS; i = i + 1) begin
            actual = out_tensor[i*DATA_WIDTH +: DATA_WIDTH];
            $display("Input[%0d] = %d, Output = %d, Expected = %d", i, input_data[i], actual, expected_data[i]);
            if (actual !== expected_data[i]) begin
                $display("❌ Mismatch at index %0d!", i);
                $stop;
            end
        end

        $display("✅ All outputs matched expected values.");
        $finish;
    end

endmodule
