`timescale 1ns/1ps

module tb_conv2d;

    parameter BATCH_SIZE   = 1;
    parameter IN_CHANNELS  = 2;
    parameter OUT_CHANNELS = 1;
    parameter IN_HEIGHT    = 4;
    parameter IN_WIDTH     = 4;
    parameter KERNEL_SIZE  = 2;
    parameter STRIDE       = 2;
    parameter PADDING      = 0;
    parameter DATA_WIDTH   = 32;

    parameter OUT_HEIGHT = (IN_HEIGHT + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    parameter OUT_WIDTH  = (IN_WIDTH  + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    parameter OUT_SIZE   = BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH;

    reg clk, rst, start;
    wire done, valid;

    reg  [BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat;
    reg  [OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_flat;
    reg  [OUT_CHANNELS*DATA_WIDTH-1:0] bias_flat;
    wire [BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH*DATA_WIDTH-1:0] output_tensor_flat;

    integer i;
    integer cycle_count;
    reg counting;
    real execution_time_us;

    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .IN_HEIGHT(IN_HEIGHT),
        .IN_WIDTH(IN_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_tensor_flat(input_tensor_flat),
        .weights_flat(weights_flat),
        .bias_flat(bias_flat),
        .output_tensor_flat(output_tensor_flat),
        .done(done),
        .valid(valid)
    );

    // Clock generation: 100 MHz -> 10 ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Cycle counter
    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else if (counting && !done) begin
            cycle_count <= cycle_count + 1;
        end
    end

    // Test
    initial begin
        rst = 1;
        start = 0;
        counting = 0;
        cycle_count = 0;

        input_tensor_flat = 0;
        weights_flat = 0;
        bias_flat = 0;

        #20;
        rst = 0;
        #10;

        // Initialize input tensor: 0 to 31 (same as PyTorch reference)
        for (i = 0; i < BATCH_SIZE * IN_CHANNELS * IN_HEIGHT * IN_WIDTH; i = i + 1)
            input_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH] = i;

        // Initialize weights to 1 (same as PyTorch reference)
        for (i = 0; i < OUT_CHANNELS * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE; i = i + 1)
            weights_flat[i*DATA_WIDTH +: DATA_WIDTH] = 32'd1;

        // Bias to 0 (same as PyTorch reference)
        for (i = 0; i < OUT_CHANNELS; i = i + 1)
            bias_flat[i*DATA_WIDTH +: DATA_WIDTH] = 32'd0;

        repeat(3) @(posedge clk);

        // Start convolution and begin counting
        start = 1;
        counting = 1;
        @(posedge clk);
        start = 0;

        // Wait until convolution completes
        wait (done);
        counting = 0;
        @(posedge clk);

        // Calculate execution time
        execution_time_us = cycle_count * 10.0 / 1000.0;

        $display("\n=== Verilog Convolution Output Tensor ===");
        $display("tensor([[[[%0d., %0d.],", 
                 output_tensor_flat[0*DATA_WIDTH +: DATA_WIDTH],
                 output_tensor_flat[1*DATA_WIDTH +: DATA_WIDTH]);
        $display("          [%0d., %0d.]]]])", 
                 output_tensor_flat[2*DATA_WIDTH +: DATA_WIDTH],
                 output_tensor_flat[3*DATA_WIDTH +: DATA_WIDTH]);

        $display("Flattened Output: [%0d, %0d, %0d, %0d]",
                 output_tensor_flat[0*DATA_WIDTH +: DATA_WIDTH],
                 output_tensor_flat[1*DATA_WIDTH +: DATA_WIDTH],
                 output_tensor_flat[2*DATA_WIDTH +: DATA_WIDTH],
                 output_tensor_flat[3*DATA_WIDTH +: DATA_WIDTH]);

        $display("Convolution Time Taken in Verilog: %.2f µs", execution_time_us);
        $display("Clock Cycles: %0d", cycle_count);
        $display("Clock Frequency: 100 MHz");

        $finish;
    end

endmodule