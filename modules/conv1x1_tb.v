`timescale 1ns/1ps

module tb_conv1x1;

    parameter DATA_WIDTH   = 32;
    parameter BATCH_SIZE   = 1;
    parameter IN_CHANNELS  = 1;
    parameter IN_HEIGHT    = 4;
    parameter IN_WIDTH     = 4;
    parameter OUT_CHANNELS = 1;
    parameter OUT_HEIGHT   = 4; // No padding, kernel=1, stride=1 → same size
    parameter OUT_WIDTH    = 4;

    reg clk, rst;
    reg [BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat;
    reg [OUT_CHANNELS*IN_CHANNELS*1*1*DATA_WIDTH-1:0] weights_flat;
    reg [OUT_CHANNELS*DATA_WIDTH-1:0] bias_flat;
    wire [BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH*DATA_WIDTH-1:0] output_tensor_flat;

    conv1x1 #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .IN_HEIGHT(IN_HEIGHT),
        .IN_WIDTH(IN_WIDTH),
        .STRIDE(1),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(input_tensor_flat),
        .weights_flat(weights_flat),
        .bias_flat(bias_flat),
        .output_tensor_flat(output_tensor_flat)
    );

    integer i;
    reg [DATA_WIDTH-1:0] input_tensor   [0:IN_CHANNELS*IN_HEIGHT*IN_WIDTH-1];
    reg [DATA_WIDTH-1:0] weights_tensor [0:OUT_CHANNELS*IN_CHANNELS-1];
    reg [DATA_WIDTH-1:0] bias_tensor    [0:OUT_CHANNELS-1];

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;

        // Initialize test input: 0,1,2,...15
        for (i = 0; i < IN_CHANNELS*IN_HEIGHT*IN_WIDTH; i = i + 1)
            input_tensor[i] = i;

        // Weight = 2 for all filters, bias = 1
        for (i = 0; i < OUT_CHANNELS*IN_CHANNELS; i = i + 1)
            weights_tensor[i] = 2;
        bias_tensor[0] = 1;

        // Flatten arrays
        for (i = 0; i < IN_CHANNELS*IN_HEIGHT*IN_WIDTH; i = i + 1)
            input_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH] = input_tensor[i];
        for (i = 0; i < OUT_CHANNELS*IN_CHANNELS; i = i + 1)
            weights_flat[i*DATA_WIDTH +: DATA_WIDTH] = weights_tensor[i];
        for (i = 0; i < OUT_CHANNELS; i = i + 1)
            bias_flat[i*DATA_WIDTH +: DATA_WIDTH] = bias_tensor[i];

        #20 rst = 0;
        #1000;

        $display("---- Output ----");
        for (i = 0; i < BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH; i = i + 1)
            $display("Output[%0d] = %d", i, output_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH]);

        $finish;
    end

endmodule
