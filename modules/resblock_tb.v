`timescale 1ns/1ps

module tb_resblock;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter BATCH_SIZE = 1;
    parameter CHANNELS = 1;
    parameter HEIGHT = 2;
    parameter WIDTH = 2;
    parameter KERNEL_SIZE = 1;
    parameter STRIDE = 1;
    parameter PADDING = 0;
    parameter BOTTLENECK = 0;

    // Internal Parameters
    parameter CONV1_OUT_CHANNELS = (BOTTLENECK ? CHANNELS/2 : CHANNELS);
    parameter CONV2_IN_CHANNELS = (BOTTLENECK ? CHANNELS/2 : CHANNELS);

    // Inputs
    reg clk;
    reg rst;
    reg [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_in;
    reg [CONV1_OUT_CHANNELS*CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights1;
    reg [CONV1_OUT_CHANNELS*DATA_WIDTH-1:0] bias1;
    reg [CHANNELS*CONV2_IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights2;
    reg [CHANNELS*DATA_WIDTH-1:0] bias2;

    // Output
    wire [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_out;

    // Instantiate DUT
    resblock #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNELS(CHANNELS),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .SLOPE_SMALL(1'b0),
        .START_FROM_RELU(1'b0),
        .END_WITH_RELU(1'b0),
        .BOTTLENECK(BOTTLENECK)
    ) dut (
        .clk(clk),
        .rst(rst),
        .x_in(x_in),
        .weights1(weights1),
        .bias1(bias1),
        .weights2(weights2),
        .bias2(bias2),
        .x_out(x_out)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Test Stimulus
    initial begin
        $display("Starting Testbench...");

        // Init
        clk = 0;
        rst = 1;
        x_in = 0;
        weights1 = 0;
        bias1 = 0;
        weights2 = 0;
        bias2 = 0;

        // Reset pulse
        #10 rst = 0;

        // Simple input: x_in = [1, 2, 3, 4] (4 pixels)
        x_in = {
            8'd1, // top-left
            8'd2, // top-right
            8'd3, // bottom-left
            8'd4  // bottom-right
        };

        // weights1 = weights2 = 1, bias = 0
        weights1 = 8'd2;
        bias1 = 8'd0;

        weights2 = 8'd2;
        bias2 = 8'd0;

        // Wait for output
        #100;

        // Display result
        $display("Input      : %d %d %d %d", x_in[31:24], x_in[23:16], x_in[15:8], x_in[7:0]);
        $display("Output     : %d %d %d %d", x_out[31:24], x_out[23:16], x_out[15:8], x_out[7:0]);

        $finish;
    end
endmodule
