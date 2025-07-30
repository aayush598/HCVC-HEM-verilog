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
    parameter OUTPUT_MEM_SIZE = BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH;

    reg clk, rst, start;
    wire done, valid;

    // Memory interface signals
    wire [ADDR_WIDTH-1:0] input_addr, output_addr;
    wire [DATA_WIDTH-1:0] input_data;
    wire [DATA_WIDTH-1:0] output_data;
    wire input_en, output_en, output_we;

    integer i;
    integer cycle_count;
    reg counting;
    real execution_time_us;

    // Memory arrays
    reg [DATA_WIDTH-1:0] input_mem [0:INPUT_MEM_SIZE-1];
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
        .output_addr(output_addr),
        .output_data(output_data),
        .output_we(output_we),
        .output_en(output_en)
    );

    // Memory interface implementations
    assign input_data = (input_en && input_addr < INPUT_MEM_SIZE) ? input_mem[input_addr] : 32'h0;
    
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
        $display("=== Starting Parameterized Conv2D Test ===");
        $display("Configuration:");
        $display("  Batch Size: %0d", BATCH_SIZE);
        $display("  Input Channels: %0d", IN_CHANNELS);
        $display("  Output Channels: %0d", OUT_CHANNELS);
        $display("  Input Size: %0dx%0d", IN_HEIGHT, IN_WIDTH);
        $display("  Kernel Size: %0d", KERNEL_SIZE);
        $display("  Stride: %0d", STRIDE);
        $display("  Padding: %0d", PADDING);
        $display("  Output Size: %0dx%0d", OUT_HEIGHT, OUT_WIDTH);
        
        rst = 1;
        start = 0;
        counting = 0;
        cycle_count = 0;

        // Initialize memories
        for (i = 0; i < INPUT_MEM_SIZE; i = i + 1)
            input_mem[i] = 32'h0;
        for (i = 0; i < OUTPUT_MEM_SIZE; i = i + 1)
            output_mem[i] = 32'h0;

        #20;
        rst = 0;
        #10;

        // Initialize input tensor: 0 to 31 (sequential values for testing)
        $display("\n=== Initializing Input Data ===");
        for (i = 0; i < INPUT_MEM_SIZE; i = i + 1) begin
            input_mem[i] = i;
        end
        
        // Display input tensor structure
        $display("Input Tensor (Channel 0):");
        $display("  [%2d, %2d, %2d, %2d]", input_mem[0], input_mem[1], input_mem[2], input_mem[3]);
        $display("  [%2d, %2d, %2d, %2d]", input_mem[4], input_mem[5], input_mem[6], input_mem[7]);
        $display("  [%2d, %2d, %2d, %2d]", input_mem[8], input_mem[9], input_mem[10], input_mem[11]);
        $display("  [%2d, %2d, %2d, %2d]", input_mem[12], input_mem[13], input_mem[14], input_mem[15]);
        
        $display("Input Tensor (Channel 1):");
        $display("  [%2d, %2d, %2d, %2d]", input_mem[16], input_mem[17], input_mem[18], input_mem[19]);
        $display("  [%2d, %2d, %2d, %2d]", input_mem[20], input_mem[21], input_mem[22], input_mem[23]);
        $display("  [%2d, %2d, %2d, %2d]", input_mem[24], input_mem[25], input_mem[26], input_mem[27]);
        $display("  [%2d, %2d, %2d, %2d]", input_mem[28], input_mem[29], input_mem[30], input_mem[31]);

        // Display weights and bias (hardcoded in module)
        $display("\n=== Weights and Bias (Hardcoded) ===");
        $display("All weights initialized to: 1");
        $display("All bias initialized to: 0");

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

        $display("\n=== Convolution Output Results ===");
        $display("Output Tensor:");
        $display("  [[[[%0d, %0d],", output_mem[0], output_mem[1]);
        $display("      [%0d, %0d]]]]", output_mem[2], output_mem[3]);
        
        $display("\nFlattened Output: [%0d, %0d, %0d, %0d]",
                 output_mem[0], output_mem[1], output_mem[2], output_mem[3]);

        // Verify expected results (manual calculation)
        $display("\n=== Expected vs Actual Results ===");
        $display("Expected results (with all weights=1, bias=0):");
        $display("  Position [0,0]: (0+1+4+5) + (16+17+20+21) = 84");
        $display("  Position [0,1]: (2+3+6+7) + (18+19+22+23) = 100");
        $display("  Position [1,0]: (8+9+12+13) + (24+25+28+29) = 148");
        $display("  Position [1,1]: (10+11+14+15) + (26+27+30+31) = 164");
        
        $display("Actual results:");
        $display("  Position [0,0]: %0d", output_mem[0]);
        $display("  Position [0,1]: %0d", output_mem[1]);
        $display("  Position [1,0]: %0d", output_mem[2]);
        $display("  Position [1,1]: %0d", output_mem[3]);
        
        // Check if results match expected values
        if (output_mem[0] == 84 && output_mem[1] == 100 && 
            output_mem[2] == 148 && output_mem[3] == 164) begin
            $display("✓ TEST PASSED: All results match expected values!");
        end else begin
            $display("✗ TEST FAILED: Results do not match expected values!");
        end

        $display("\n=== Performance Metrics ===");
        $display("Execution Time: %.2f µs", execution_time_us);
        $display("Clock Cycles: %0d", cycle_count);
        $display("Clock Frequency: 100 MHz");
        $display("Operations per cycle: %.2f", 
                (BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE * 1.0) / cycle_count);
        $display("Total MAC operations: %0d", 
                BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE);

        $display("\n=== Test Complete ===");
        $finish;
    end

    // Optional: Add timeout to prevent infinite simulation
    initial begin
        #100000; // 100µs timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule