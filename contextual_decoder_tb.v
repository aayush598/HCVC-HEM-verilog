
`timescale 1ns / 1ps

module tb_contextual_decoder();

    // Parameters matching Python test
    parameter DATA_WIDTH = 32;
    parameter BATCH_SIZE = 1;
    parameter HEIGHT = 2;
    parameter WIDTH = 2;
    parameter CHANNEL_N = 4;  // Reduced for testing
    parameter CHANNEL_M = 6;  // Reduced for testing
    
    // Clock and reset
    reg clk;
    reg rst;
    reg start;
    
    // Input signals
    reg [BATCH_SIZE*CHANNEL_M*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_in;
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT*8*WIDTH*8*DATA_WIDTH-1:0] context2;  // 16x16 = HEIGHT*8 x WIDTH*8
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT*4*WIDTH*4*DATA_WIDTH-1:0] context3;  // 8x8 = HEIGHT*4 x WIDTH*4
    
    // Weight and bias inputs (simplified for testing)
    reg [CHANNEL_N*4*CHANNEL_M*3*3*DATA_WIDTH-1:0] up1_weights;
    reg [CHANNEL_N*4*DATA_WIDTH-1:0] up1_bias;
    reg [CHANNEL_N*4*CHANNEL_N*3*3*DATA_WIDTH-1:0] up2_weights;
    reg [CHANNEL_N*4*DATA_WIDTH-1:0] up2_bias;
    reg [CHANNEL_N*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] res1_weights1;
    reg [CHANNEL_N*DATA_WIDTH-1:0] res1_bias1;
    reg [CHANNEL_N*2*CHANNEL_N*3*3*DATA_WIDTH-1:0] res1_weights2;
    reg [CHANNEL_N*2*DATA_WIDTH-1:0] res1_bias2;
    reg [CHANNEL_N*4*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] up3_weights;
    reg [CHANNEL_N*4*DATA_WIDTH-1:0] up3_bias;
    reg [CHANNEL_N*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] res2_weights1;
    reg [CHANNEL_N*DATA_WIDTH-1:0] res2_bias1;
    reg [CHANNEL_N*2*CHANNEL_N*3*3*DATA_WIDTH-1:0] res2_weights2;
    reg [CHANNEL_N*2*DATA_WIDTH-1:0] res2_bias2;
    reg [128*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] up4_weights;
    reg [128*DATA_WIDTH-1:0] up4_bias;
    
    // Output signals
    wire done;
    wire [BATCH_SIZE*32*HEIGHT*WIDTH*16*DATA_WIDTH-1:0] feature_out;
    
    // Instantiate the DUT (Device Under Test)
    contextual_decoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH),
        .CHANNEL_N(CHANNEL_N),
        .CHANNEL_M(CHANNEL_M)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .x_in(x_in),
        .context2(context2),
        .context3(context3),
        .up1_weights(up1_weights),
        .up1_bias(up1_bias),
        .up2_weights(up2_weights),
        .up2_bias(up2_bias),
        .res1_weights1(res1_weights1),
        .res1_bias1(res1_bias1),
        .res1_weights2(res1_weights2),
        .res1_bias2(res1_bias2),
        .up3_weights(up3_weights),
        .up3_bias(up3_bias),
        .res2_weights1(res2_weights1),
        .res2_bias1(res2_bias1),
        .res2_weights2(res2_weights2),
        .res2_bias2(res2_bias2),
        .up4_weights(up4_weights),
        .up4_bias(up4_bias),
        .done(done),
        .feature_out(feature_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Convert real to 32-bit fixed point (16.16 format)
    function [31:0] real_to_fixed;
        input real value;
        begin
            real_to_fixed = $rtoi(value * 65536.0); // 2^16 for 16 fractional bits
        end
    endfunction
    
    // Convert 32-bit fixed point to real for display
    function real fixed_to_real;
        input [31:0] value;
        begin
            fixed_to_real = $itor($signed(value)) / 65536.0;
        end
    endfunction
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst = 1;
        start = 0;
        x_in = 0;
        context2 = 0;
        context3 = 0;
        
        // Initialize all weights to 0.1 (same as Python test)
        up1_weights = {(CHANNEL_N*4*CHANNEL_M*3*3){real_to_fixed(0.1)}};
        up1_bias = {(CHANNEL_N*4){real_to_fixed(0.01)}};
        up2_weights = {(CHANNEL_N*4*CHANNEL_N*3*3){real_to_fixed(0.1)}};
        up2_bias = {(CHANNEL_N*4){real_to_fixed(0.01)}};
        res1_weights1 = {(CHANNEL_N*CHANNEL_N*2*3*3){real_to_fixed(0.1)}};
        res1_bias1 = {(CHANNEL_N){real_to_fixed(0.01)}};
        res1_weights2 = {(CHANNEL_N*2*CHANNEL_N*3*3){real_to_fixed(0.1)}};
        res1_bias2 = {(CHANNEL_N*2){real_to_fixed(0.01)}};
        up3_weights = {(CHANNEL_N*4*CHANNEL_N*2*3*3){real_to_fixed(0.1)}};
        up3_bias = {(CHANNEL_N*4){real_to_fixed(0.01)}};
        res2_weights1 = {(CHANNEL_N*CHANNEL_N*2*3*3){real_to_fixed(0.1)}};
        res2_bias1 = {(CHANNEL_N){real_to_fixed(0.01)}};
        res2_weights2 = {(CHANNEL_N*2*CHANNEL_N*3*3){real_to_fixed(0.1)}};
        res2_bias2 = {(CHANNEL_N*2){real_to_fixed(0.01)}};
        up4_weights = {(128*CHANNEL_N*2*3*3){real_to_fixed(0.1)}};
        up4_bias = {(128){real_to_fixed(0.01)}};
        
        $display("Starting Contextual Decoder Test");
        $display("Parameters: BATCH_SIZE=%0d, HEIGHT=%0d, WIDTH=%0d", BATCH_SIZE, HEIGHT, WIDTH);
        $display("CHANNEL_N=%0d, CHANNEL_M=%0d", CHANNEL_N, CHANNEL_M);
        
        // Wait for a few clock cycles
        #20;
        rst = 0;
        #10;
        
        // Set up input data (matching Python test)
        // x_in: all values = 2.0
        x_in = {(BATCH_SIZE*CHANNEL_M*HEIGHT*WIDTH){real_to_fixed(2.0)}};
        
        // context2: all values = 1.5 (16x16 = HEIGHT*8 x WIDTH*8)
        context2 = {(BATCH_SIZE*CHANNEL_N*HEIGHT*8*WIDTH*8){real_to_fixed(1.5)}};
        
        // context3: all values = 1.0 (8x8 = HEIGHT*4 x WIDTH*4)
        context3 = {(BATCH_SIZE*CHANNEL_N*HEIGHT*4*WIDTH*4){real_to_fixed(1.0)}};
        
        $display("Input Data Set:");
        $display("x_in[0] = %f", fixed_to_real(x_in[31:0]));
        $display("context2[0] = %f", fixed_to_real(context2[31:0]));
        $display("context3[0] = %f", fixed_to_real(context3[31:0]));
        
        // Start processing
        start = 1;
        #10;
        start = 0;
        
        // Wait for completion
        wait(done);
        #10;
        
        $display("Processing Complete!");
        $display("Output feature_out[0] = %f", fixed_to_real(feature_out[31:0]));
        $display("Output feature_out[1] = %f", fixed_to_real(feature_out[63:32]));
        $display("Output feature_out[2] = %f", fixed_to_real(feature_out[95:64]));
        $display("Output feature_out[3] = %f", fixed_to_real(feature_out[127:96]));
        
        // Display some statistics
        $display("Test completed successfully!");
        
        #100;
        $finish;
    end
    
    // Monitor important signals
    initial begin
        $monitor("Time=%0t, rst=%b, start=%b, done=%b", $time, rst, start, done);
    end
    
    // Timeout protection
    initial begin
        #10000; // 10us timeout
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule