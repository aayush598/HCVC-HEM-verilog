`timescale 1ns / 1ps

module tb_subpel_conv3x3();

    // Parameters - using small values for manual calculation
    parameter IN_CHANNELS  = 1;
    parameter OUT_CHANNELS = 1; 
    parameter IN_HEIGHT    = 2;
    parameter IN_WIDTH     = 2;
    parameter R            = 2;        // Upscale factor
    parameter DATA_WIDTH   = 16;
    
    // Derived parameters
    parameter CONV_OUT_CHANNELS = OUT_CHANNELS * R * R; // = 4
    parameter FINAL_OUT_HEIGHT = IN_HEIGHT * R;         // = 4
    parameter FINAL_OUT_WIDTH = IN_WIDTH * R;           // = 4
    
    // Test signals
    reg clk;
    reg rst;
    reg start;
    
    // Input data: 2x2 input with 1 channel
    reg [IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat;
    
    // Conv weights: [4 output channels][1 input channel][3x3 kernel]
    reg [CONV_OUT_CHANNELS*IN_CHANNELS*3*3*DATA_WIDTH-1:0] conv_weights_flat;
    
    // Conv bias: [4 output channels] 
    reg [CONV_OUT_CHANNELS*DATA_WIDTH-1:0] conv_bias_flat;
    
    wire done;
    wire [OUT_CHANNELS*FINAL_OUT_HEIGHT*FINAL_OUT_WIDTH*DATA_WIDTH-1:0] output_tensor_flat;
    
    // Clock generation
    always #5 clk = ~clk;
    
    // DUT instantiation
    subpel_conv3x3 #(
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .IN_HEIGHT(IN_HEIGHT),
        .IN_WIDTH(IN_WIDTH),
        .R(R),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_tensor_flat(input_tensor_flat),
        .conv_weights_flat(conv_weights_flat),
        .conv_bias_flat(conv_bias_flat),
        .done(done),
        .output_tensor_flat(output_tensor_flat)
    );
    
    // Helper task to set input data
    task set_input_data;
        input [15:0] val00, val01, val10, val11;
        begin
            // Input tensor: [1][2][2] = 4 elements
            // Format: input[channel][height][width]
            input_tensor_flat[0*DATA_WIDTH +: DATA_WIDTH]  = val00; // [0][0][0]
            input_tensor_flat[1*DATA_WIDTH +: DATA_WIDTH]  = val01; // [0][0][1] 
            input_tensor_flat[2*DATA_WIDTH +: DATA_WIDTH]  = val10; // [0][1][0]
            input_tensor_flat[3*DATA_WIDTH +: DATA_WIDTH]  = val11; // [0][1][1]
        end
    endtask
    
    // Helper task to set simple weights (identity-like for easy calculation)
    task set_simple_weights;
        integer i;
        begin
            // Initialize all weights to 0
            for (i = 0; i < CONV_OUT_CHANNELS*IN_CHANNELS*9; i = i + 1) begin
                conv_weights_flat[i*DATA_WIDTH +: DATA_WIDTH] = 0;
            end
            
            // Set center weights to 1 for each output channel 
            // This makes each output channel copy the input value
            // Weight indexing: [out_ch][in_ch][k_h][k_w]
            // Center position is k_h=1, k_w=1 (index 4 in 3x3 kernel)
            
            // Output channel 0: center weight = 1
            conv_weights_flat[(0*IN_CHANNELS*9 + 0*9 + 4)*DATA_WIDTH +: DATA_WIDTH] = 16'd1;
            
            // Output channel 1: center weight = 2  
            conv_weights_flat[(1*IN_CHANNELS*9 + 0*9 + 4)*DATA_WIDTH +: DATA_WIDTH] = 16'd2;
            
            // Output channel 2: center weight = 3
            conv_weights_flat[(2*IN_CHANNELS*9 + 0*9 + 4)*DATA_WIDTH +: DATA_WIDTH] = 16'd3;
            
            // Output channel 3: center weight = 4
            conv_weights_flat[(3*IN_CHANNELS*9 + 0*9 + 4)*DATA_WIDTH +: DATA_WIDTH] = 16'd4;
        end
    endtask
    
    // Helper task to set biases
    task set_biases;
        begin
            conv_bias_flat[0*DATA_WIDTH +: DATA_WIDTH] = 16'd0;  // bias for output channel 0
            conv_bias_flat[1*DATA_WIDTH +: DATA_WIDTH] = 16'd0;  // bias for output channel 1  
            conv_bias_flat[2*DATA_WIDTH +: DATA_WIDTH] = 16'd0;  // bias for output channel 2
            conv_bias_flat[3*DATA_WIDTH +: DATA_WIDTH] = 16'd0;  // bias for output channel 3
        end
    endtask
    
    // Helper task to display output
    task display_output;
        integer i, h, w;
        reg [DATA_WIDTH-1:0] pixel_val;
        begin
            $display("\n=== Final Output (4x4) ===");
            for (h = 0; h < FINAL_OUT_HEIGHT; h = h + 1) begin
                $write("Row %0d: ", h);
                for (w = 0; w < FINAL_OUT_WIDTH; w = w + 1) begin
                    i = h * FINAL_OUT_WIDTH + w;
                    pixel_val = output_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH];
                    $write("%0d ", pixel_val);
                end
                $display("");
            end
            $display("========================\n");
        end
    endtask
    
    // Test sequence
    initial begin
        $display("Starting Subpel Conv3x3 Testbench");
        $display("Input size: %0dx%0d, Output size: %0dx%0d", IN_HEIGHT, IN_WIDTH, FINAL_OUT_HEIGHT, FINAL_OUT_WIDTH);
        
        // Initialize
        clk = 0;
        rst = 1;
        start = 0;
        
        // Set test data
        set_input_data(16'd1, 16'd2, 16'd3, 16'd4);  // Simple 2x2 input
        set_simple_weights();
        set_biases();
        
        $display("\n=== Input Data (2x2) ===");
        $display("1  2");
        $display("3  4");
        
        $display("\n=== Conv Weights (center weights only) ===");
        $display("Channel 0: weight=1, Channel 1: weight=2");
        $display("Channel 2: weight=3, Channel 3: weight=4");
        
        // Reset sequence
        #10 rst = 0;
        #10;
        
        // Start processing
        start = 1;
        #10 start = 0;
        
        // Wait for completion
        wait(done);
        
        // Display results
        display_output();
        
        // Expected calculation:
        // After conv: 4 channels of 2x2, each multiplied by its weight
        // Ch0: [1,2,3,4] * 1 = [1,2,3,4]
        // Ch1: [1,2,3,4] * 2 = [2,4,6,8] 
        // Ch2: [1,2,3,4] * 3 = [3,6,9,12]
        // Ch3: [1,2,3,4] * 4 = [4,8,12,16]
        //
        // After pixel shuffle with R=2:
        // Rearranges 4 channels of 2x2 into 1 channel of 4x4
        // Expected 4x4 output:
        // [ 1,  2,  2,  4]
        // [ 3,  6,  4,  8] 
        // [ 3,  4,  6,  8]
        // [ 9, 12, 12, 16]
        
        $display("Expected output:");
        $display("1   2   2   4");
        $display("3   6   4   8");  
        $display("3   4   6   8");
        $display("9  12  12  16");
        
        #100;
        $display("Test completed");
        $finish;
    end

endmodule