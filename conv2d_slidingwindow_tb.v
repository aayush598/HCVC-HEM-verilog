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

    // Debug: Monitor state transitions
    always @(posedge clk) begin
        if (counting && !rst) begin
            case (uut.state)
                3'b000: $display("Time %0t: State = IDLE", $time);
                3'b001: $display("Time %0t: State = INIT_WINDOW, out_pos=(%0d,%0d,%0d,%0d)", 
                        $time, uut.batch_idx, uut.out_ch_idx, uut.out_row, uut.out_col);
                3'b010: $display("Time %0t: State = SLIDE_WINDOW, kernel_pos=(%0d,%0d,%0d)", 
                        $time, uut.in_ch_idx, uut.kernel_row, uut.kernel_col);
                3'b011: $display("Time %0t: State = COMPUTE_CONV, input_val=%0d, weight_val=%0d, acc=%0d", 
                        $time, uut.input_val, uut.weight_val, uut.accumulator);
                3'b100: $display("Time %0t: State = STORE_RESULT, final_acc=%0d", 
                        $time, uut.accumulator);
                3'b101: $display("Time %0t: State = DONE", $time);
            endcase
        end
    end

    // Test
    initial begin
        $display("=== Starting Sliding Window Conv2D Test ===");
        $display("Parameters: IN=%dx%dx%dx%d, KERNEL=%dx%d, STRIDE=%d, OUT=%dx%dx%dx%d", 
                BATCH_SIZE, IN_CHANNELS, IN_HEIGHT, IN_WIDTH, 
                KERNEL_SIZE, KERNEL_SIZE, STRIDE, 
                BATCH_SIZE, OUT_CHANNELS, OUT_HEIGHT, OUT_WIDTH);
        
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
        $display("\n=== Initializing Input Data ===");
        for (i = 0; i < BATCH_SIZE * IN_CHANNELS * IN_HEIGHT * IN_WIDTH; i = i + 1) begin
            input_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH] = i;
            $display("input_mem[%0d] = %0d", i, i);
        end

        // Initialize weights to 1 (same as PyTorch reference)
        $display("\n=== Initializing Weights ===");
        for (i = 0; i < OUT_CHANNELS * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE; i = i + 1) begin
            weights_flat[i*DATA_WIDTH +: DATA_WIDTH] = 32'd1;
            $display("weight_mem[%0d] = 1", i);
        end

        // Bias to 0 (same as PyTorch reference)
        $display("\n=== Initializing Bias ===");
        for (i = 0; i < OUT_CHANNELS; i = i + 1) begin
            bias_flat[i*DATA_WIDTH +: DATA_WIDTH] = 32'd0;
            $display("bias_mem[%0d] = 0", i);
        end

        repeat(3) @(posedge clk);

        $display("\n=== Starting Convolution Computation ===");
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

        $display("\n=== Sliding Window Convolution Output Tensor ===");
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

        $display("\n=== Performance Results ===");
        $display("Sliding Window Convolution Time: %.2f µs", execution_time_us);
        $display("Clock Cycles: %0d", cycle_count);
        $display("Clock Frequency: 100 MHz");
        $display("Throughput: %.2f operations/cycle", 
                (BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE * 1.0) / cycle_count);

        $finish;
    end

endmodule