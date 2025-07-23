`timescale 1ns / 1ps

module tb_subpel_conv1x1_top;

    // Parameters
    parameter IN_CHANNELS = 1;
    parameter OUT_CHANNELS = 1;
    parameter UPSCALE = 2;
    parameter H = 2;
    parameter W = 2;
    parameter DATA_WIDTH = 8;

    // Derived parameters
    parameter INPUT_SIZE  = IN_CHANNELS*H*W;
    parameter WEIGHT_SIZE = OUT_CHANNELS*IN_CHANNELS*UPSCALE*UPSCALE;
    parameter BIAS_SIZE   = OUT_CHANNELS*UPSCALE*UPSCALE;
    parameter CONV_OUT_SIZE = WEIGHT_SIZE*H*W;
    parameter OUT_SIZE = OUT_CHANNELS*(H*UPSCALE)*(W*UPSCALE);

    // Inputs
    reg clk;
    reg rst;
    reg start;
    reg [INPUT_SIZE*DATA_WIDTH-1:0] input_tensor_flat;
    reg [WEIGHT_SIZE*DATA_WIDTH-1:0] weights_flat;
    reg [BIAS_SIZE*DATA_WIDTH-1:0] bias_flat;

    // Output
    wire done;
    wire [OUT_SIZE*DATA_WIDTH-1:0] output_tensor_flat;

    // Instantiate the module
    subpel_conv1x1_top #(
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .UPSCALE(UPSCALE),
        .H(H),
        .W(W),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_tensor_flat(input_tensor_flat),
        .weights_flat(weights_flat),
        .bias_flat(bias_flat),
        .done(done),
        .output_tensor_flat(output_tensor_flat)
    );

    // Clock generator
    always #5 clk = ~clk;

    integer i;

    initial begin
        $display("Starting subpel_conv1x1 test...");
        clk = 0;
        rst = 1;
        start = 0;

        // Wait for reset
        #20;
        rst = 0;

        // Assign input tensor: [1, 2, 3, 4]
        input_tensor_flat = {8'd4, 8'd3, 8'd2, 8'd1}; // MSB to LSB order

        // Assign weights: [1, 2, 3, 4]
        weights_flat = {8'd4, 8'd3, 8'd2, 8'd1};

        // Assign bias: [0, 0, 0, 0]
        bias_flat = 0;

        // Start the process
        #10;
        start = 1;

        // Wait for done
        wait (done == 1);
        #10;

        // Display output
        $display("Output Tensor (flattened):");
        for (i = 0; i < OUT_SIZE; i = i + 1) begin
            $display("out[%0d] = %0d", i, output_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH]);
        end

        $finish;
    end

endmodule
