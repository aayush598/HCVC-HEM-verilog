`timescale 1ns/1ps

module tb_contextual_encoder;

    // Parameters - Keep these small for easier verification
    parameter DATA_WIDTH = 8;
    parameter BATCH_SIZE = 1;
    parameter CHANNEL_N = 1;
    parameter CHANNEL_M = 1;
    parameter HEIGHT = 16;
    parameter WIDTH = 16;
    parameter KERNEL_SIZE = 3;
    parameter STRIDE = 2;
    parameter PADDING = 1;

    // Local parameters
    localparam HEIGHT_2 = HEIGHT/2;    // 8
    localparam WIDTH_2 = WIDTH/2;      // 8
    localparam HEIGHT_4 = HEIGHT/4;    // 4
    localparam WIDTH_4 = WIDTH/4;      // 4
    localparam HEIGHT_8 = HEIGHT/8;    // 2
    localparam WIDTH_8 = WIDTH/8;      // 2
    localparam HEIGHT_16 = HEIGHT/16;  // 1
    localparam WIDTH_16 = WIDTH/16;    // 1

    // Clock and reset
    reg clk = 0;
    reg rst = 0;

    // Input tensor sizes
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*DATA_WIDTH-1:0] x;                    
    reg [BATCH_SIZE*3*HEIGHT*WIDTH*DATA_WIDTH-1:0] context1;                     
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT_2*WIDTH_2*DATA_WIDTH-1:0] context2;        
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT_4*WIDTH_4*DATA_WIDTH-1:0] context3;        

    // Weight and bias sizes
    reg [CHANNEL_N*(CHANNEL_N+3)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv1_weights;  
    reg [CHANNEL_N*DATA_WIDTH-1:0] conv1_bias;                                            

    reg [(CHANNEL_N*2)*CHANNEL_N*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv2_weights;  
    reg [CHANNEL_N*DATA_WIDTH-1:0] conv2_bias;                                            

    reg [CHANNEL_N*(CHANNEL_N*2)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv3_weights;  
    reg [CHANNEL_N*DATA_WIDTH-1:0] conv3_bias;                                            

    reg [CHANNEL_M*CHANNEL_N*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv4_weights;      
    reg [CHANNEL_M*DATA_WIDTH-1:0] conv4_bias;                                            

    // ResBlock weights - corrected for bottleneck architecture
    reg [(CHANNEL_N)*CHANNEL_N*2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res1_weights1;  // 1 output * 2 input * 3*3 * 8 = 144
    reg [(CHANNEL_N)*DATA_WIDTH-1:0] res1_bias1;                                          // 1 * 8 = 8
    reg [CHANNEL_N*2*(CHANNEL_N)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res1_weights2;  // 2 output * 1 input * 3*3 * 8 = 144  
    reg [CHANNEL_N*2*DATA_WIDTH-1:0] res1_bias2;                                          // 2 * 8 = 16

    reg [(CHANNEL_N)*CHANNEL_N*2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res2_weights1;  
    reg [(CHANNEL_N)*DATA_WIDTH-1:0] res2_bias1;                                          
    reg [CHANNEL_N*2*(CHANNEL_N)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res2_weights2;  
    reg [CHANNEL_N*2*DATA_WIDTH-1:0] res2_bias2;                                          

    // Output
    wire [BATCH_SIZE*CHANNEL_M*HEIGHT_16*WIDTH_16*DATA_WIDTH-1:0] feature_out;           

    // Instantiate DUT
    contextual_encoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNEL_N(CHANNEL_N),
        .CHANNEL_M(CHANNEL_M),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING)
    ) dut (
        .clk(clk),
        .rst(rst),
        .x(x),
        .context1(context1),
        .context2(context2),
        .context3(context3),
        .conv1_weights(conv1_weights),
        .conv1_bias(conv1_bias),
        .conv2_weights(conv2_weights),
        .conv2_bias(conv2_bias),
        .conv3_weights(conv3_weights),
        .conv3_bias(conv3_bias),
        .conv4_weights(conv4_weights),
        .conv4_bias(conv4_bias),
        .res1_weights1(res1_weights1),
        .res1_bias1(res1_bias1),
        .res1_weights2(res1_weights2),
        .res1_bias2(res1_bias2),
        .res2_weights1(res2_weights1),
        .res2_bias1(res2_bias1),
        .res2_weights2(res2_weights2),
        .res2_bias2(res2_bias2),
        .feature_out(feature_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Debug: Monitor internal signals
    initial begin
        #600;
        $display("\n=== DEBUG: Internal Signal Analysis ===");
        if (dut.concat1_out !== {(BATCH_SIZE*(CHANNEL_N+3)*HEIGHT*WIDTH*DATA_WIDTH){1'bx}}) begin
            $display("concat1_out first few bytes: %h", dut.concat1_out[DATA_WIDTH*4-1:0]);
        end
        if (dut.conv1_out !== {(BATCH_SIZE*CHANNEL_N*HEIGHT_2*WIDTH_2*DATA_WIDTH){1'bx}}) begin
            $display("conv1_out first few bytes: %h", dut.conv1_out[DATA_WIDTH*4-1:0]);
        end
    end

    // Stimulus
    initial begin
        $display("=== Starting Contextual Encoder Testbench ===");
        $display("Parameters: DATA_WIDTH=%0d, CHANNEL_N=%0d, CHANNEL_M=%0d", 
                 DATA_WIDTH, CHANNEL_N, CHANNEL_M);
        $display("Input dimensions: HEIGHT=%0d, WIDTH=%0d", HEIGHT, WIDTH);

        // Enable waveform dump
        $dumpfile("contextual_encoder.vcd");
        $dumpvars(0, tb_contextual_encoder);

        // Reset sequence
        rst = 1;
        #20;
        rst = 0;
        #10;

        $display("\n=== Initializing Test Data ===");
        
        // Initialize inputs - exact same values as Python
        x = {256{8'h01}};               // 256 = 1*1*16*16, all 1s
        context1 = {768{8'h02}};        // 768 = 1*3*16*16, all 2s  
        context2 = {64{8'h03}};         // 64 = 1*1*8*8, all 3s
        context3 = {16{8'h04}};         // 16 = 1*1*4*4, all 4s

        // Initialize weights - all 1s, biases all 0s
        conv1_weights = {36{8'h01}};    // 36 = 1*4*3*3
        conv1_bias = 8'h00;

        conv2_weights = {18{8'h01}};    // 18 = 2*1*3*3  
        conv2_bias = 8'h00;

        conv3_weights = {18{8'h01}};    // 18 = 1*2*3*3
        conv3_bias = 8'h00;

        conv4_weights = {9{8'h01}};     // 9 = 1*1*3*3
        conv4_bias = 8'h00;

        // ResBlock weights - bottleneck: 2->1->2 channels
        res1_weights1 = {18{8'h01}};    // 18 = 1*2*3*3 (2 inputs, 1 output)
        res1_bias1 = 8'h00;
        res1_weights2 = {18{8'h01}};    // 18 = 2*1*3*3 (1 input, 2 outputs)
        res1_bias2 = {2{8'h00}};

        res2_weights1 = {18{8'h01}};    // Same as res1
        res2_bias1 = 8'h00;
        res2_weights2 = {18{8'h01}};
        res2_bias2 = {2{8'h00}};

        $display("Input values: x=0x01, context1=0x02, context2=0x03, context3=0x04");
        $display("All weights=0x01, all biases=0x00");

        // Wait for computation
        $display("\n=== Running Computation ===");
        #500;

        // Display final results
        $display("\n=== FINAL RESULTS ===");
        $display("Output feature_out = 0x%02h", feature_out);
        $display("Output feature_out (decimal) = %0d", feature_out);
        
        // Check if output is within expected range
        if (feature_out >= 8'h00 && feature_out <= 8'hff) begin
            $display("✓ Output is valid 8-bit value");
        end else begin
            $display("✗ Output is out of range!");
        end

        $display("\n=== Verification Info ===");
        $display("Expected Python output should match this value");
        $display("If they don't match, check ResBlock implementation");

        #100;
        $display("\nSimulation completed at time %0t", $time);
        $finish;
    end

    // Continuous monitoring
    always @(posedge clk) begin
        if (!rst && $time > 100000) begin
            if (feature_out !== 8'hxx) begin
                // Only display when output changes and is not unknown
                $display("Time %0t: feature_out = 0x%02h (%0d)", $time, feature_out, feature_out);
            end
        end
    end

    // Timeout protection
    initial begin
        #10000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule