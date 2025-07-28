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
    parameter ADDR_WIDTH   = 16;

    parameter OUT_HEIGHT = (IN_HEIGHT + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    parameter OUT_WIDTH  = (IN_WIDTH  + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    
    // Calculate memory sizes
    parameter INPUT_MEM_SIZE = BATCH_SIZE * IN_CHANNELS * IN_HEIGHT * IN_WIDTH;
    parameter WEIGHT_MEM_SIZE = OUT_CHANNELS * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE;
    parameter BIAS_MEM_SIZE = OUT_CHANNELS;
    parameter OUTPUT_MEM_SIZE = BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH;

    reg clk, rst, start;
    wire done, valid;

    // Memory interface signals
    wire [ADDR_WIDTH-1:0] input_addr, weight_addr, bias_addr, output_addr;
    wire [DATA_WIDTH-1:0] input_data, weight_data, bias_data;
    wire [DATA_WIDTH-1:0] output_data;
    wire input_en, weight_en, bias_en, output_en, output_we;

    integer i;
    integer cycle_count;
    reg counting;
    real execution_time_us;

    // Memory arrays
    reg [DATA_WIDTH-1:0] input_mem [0:INPUT_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] weight_mem [0:WEIGHT_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] bias_mem [0:BIAS_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] output_mem [0:OUTPUT_MEM_SIZE-1];

    // Instantiate conv2d module
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .IN_HEIGHT(IN_HEIGHT),
        .IN_WIDTH(IN_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .valid(valid),
        .input_addr(input_addr),
        .input_data(input_data),
        .input_en(input_en),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .weight_en(weight_en),
        .bias_addr(bias_addr),
        .bias_data(bias_data),
        .bias_en(bias_en),
        .output_addr(output_addr),
        .output_data(output_data),
        .output_we(output_we),
        .output_en(output_en)
    );

    // Memory interface implementations
    assign input_data = (input_en && input_addr < INPUT_MEM_SIZE) ? input_mem[input_addr] : 32'h0;
    assign weight_data = (weight_en && weight_addr < WEIGHT_MEM_SIZE) ? weight_mem[weight_addr] : 32'h0;
    assign bias_data = (bias_en && bias_addr < BIAS_MEM_SIZE) ? bias_mem[bias_addr] : 32'h0;
    
    // Output memory write
    always @(posedge clk) begin
        if (output_en && output_we && output_addr < OUTPUT_MEM_SIZE) begin
            output_mem[output_addr] <= output_data;
        end
    end

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


    // Test stimulus
    initial begin
        $display("=== Starting Memory-Based Conv2D Test ===");
        
        rst = 1;
        start = 0;
        counting = 0;
        cycle_count = 0;

        // Initialize memories
        for (i = 0; i < INPUT_MEM_SIZE; i = i + 1)
            input_mem[i] = 32'h0;
        for (i = 0; i < WEIGHT_MEM_SIZE; i = i + 1)
            weight_mem[i] = 32'h0;
        for (i = 0; i < BIAS_MEM_SIZE; i = i + 1)
            bias_mem[i] = 32'h0;
        for (i = 0; i < OUTPUT_MEM_SIZE; i = i + 1)
            output_mem[i] = 32'h0;

        #20;
        rst = 0;
        #10;

        // Initialize input tensor: 0 to 31 (same as PyTorch reference)
        for (i = 0; i < INPUT_MEM_SIZE; i = i + 1) begin
            input_mem[i] = i;
        end

        // Initialize weights to 1 (same as PyTorch reference)
        for (i = 0; i < WEIGHT_MEM_SIZE; i = i + 1) begin
            weight_mem[i] = 32'd1;
        end

        // Initialize bias to 0 (same as PyTorch reference)
        for (i = 0; i < BIAS_MEM_SIZE; i = i + 1) begin
            bias_mem[i] = 32'd0;
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

        $display("\n=== Memory-Based Convolution Output Tensor ===");
        $display("tensor([[[[%0d., %0d.],", 
                 output_mem[0], output_mem[1]);
        $display("          [%0d., %0d.]]]])", 
                 output_mem[2], output_mem[3]);

        $display("Flattened Output: [%0d, %0d, %0d, %0d]",
                 output_mem[0], output_mem[1], output_mem[2], output_mem[3]);

        $display("\n=== Performance Results ===");
        $display("Memory-Based Convolution Time: %.2f µs", execution_time_us);
        $display("Clock Cycles: %0d", cycle_count);
        $display("Clock Frequency: 100 MHz");
        $display("Throughput: %.2f operations/cycle", 
                (BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE * 1.0) / cycle_count);

        $finish;
    end

endmodule