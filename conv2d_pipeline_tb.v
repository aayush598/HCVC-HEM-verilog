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

    // Debug: Monitor state transitions
    always @(posedge clk) begin
        if (counting && !rst) begin
            case (uut.state)
                4'b0000: if (start) $display("Time %0t: State = IDLE -> Starting", $time);
                4'b0001: $display("Time %0t: State = INIT_WINDOW, out_pos=(%0d,%0d,%0d,%0d)", 
                        $time, uut.batch_idx, uut.out_ch_idx, uut.out_row, uut.out_col);
                4'b0010: $display("Time %0t: State = READ_BIAS, addr=%0d", $time, bias_addr);
                4'b0011: $display("Time %0t: State = SLIDE_WINDOW, kernel_pos=(%0d,%0d,%0d)", 
                        $time, uut.in_ch_idx, uut.kernel_row, uut.kernel_col);
                4'b0100: $display("Time %0t: State = READ_INPUT, addr=%0d, valid=%b", 
                        $time, input_addr, uut.input_valid);
                4'b0101: $display("Time %0t: State = READ_WEIGHT, addr=%0d", $time, weight_addr);
                4'b0110: $display("Time %0t: State = COMPUTE_CONV, input=%0d, weight=%0d, acc=%0d", 
                        $time, uut.input_val, uut.weight_val, uut.accumulator);
                4'b0111: $display("Time %0t: State = STORE_RESULT, final_acc=%0d", 
                        $time, uut.accumulator);
                4'b1000: $display("Time %0t: State = WRITE_OUTPUT, addr=%0d, data=%0d", 
                        $time, output_addr, output_data);
                4'b1001: $display("Time %0t: State = DONE", $time);
            endcase
        end
    end

    // Test stimulus
    initial begin
        $display("=== Starting Memory-Based Conv2D Test ===");
        $display("Parameters: IN=%dx%dx%dx%d, KERNEL=%dx%d, STRIDE=%d, OUT=%dx%dx%dx%d", 
                BATCH_SIZE, IN_CHANNELS, IN_HEIGHT, IN_WIDTH, 
                KERNEL_SIZE, KERNEL_SIZE, STRIDE, 
                BATCH_SIZE, OUT_CHANNELS, OUT_HEIGHT, OUT_WIDTH);
        $display("Memory Sizes: INPUT=%0d, WEIGHT=%0d, BIAS=%0d, OUTPUT=%0d",
                INPUT_MEM_SIZE, WEIGHT_MEM_SIZE, BIAS_MEM_SIZE, OUTPUT_MEM_SIZE);
        
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
        $display("\n=== Initializing Input Data ===");
        for (i = 0; i < INPUT_MEM_SIZE; i = i + 1) begin
            input_mem[i] = i;
            $display("input_mem[%0d] = %0d", i, i);
        end

        // Initialize weights to 1 (same as PyTorch reference)
        $display("\n=== Initializing Weights ===");
        for (i = 0; i < WEIGHT_MEM_SIZE; i = i + 1) begin
            weight_mem[i] = 32'd1;
            $display("weight_mem[%0d] = 1", i);
        end

        // Initialize bias to 0 (same as PyTorch reference)
        $display("\n=== Initializing Bias ===");
        for (i = 0; i < BIAS_MEM_SIZE; i = i + 1) begin
            bias_mem[i] = 32'd0;
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