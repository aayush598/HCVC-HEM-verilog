
// =============================================================================
// Usage Example with Different Weight/Bias Files
// =============================================================================

module conv2d_example_usage;
    
    // Example 1: Small convolution with custom files
    conv2d_file #(
        .BATCH_SIZE(1),
        .IN_CHANNELS(3),
        .OUT_CHANNELS(16),
        .IN_HEIGHT(32),
        .IN_WIDTH(32),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .WEIGHT_FILE("conv1_weights.mem"),
        .BIAS_FILE("conv1_bias.mem")
    ) conv_layer1 (
        .clk(clk),
        .rst(rst),
        .start(start1),
        .done(done1),
        .valid(valid1),
        .input_addr(input_addr1),
        .input_data(input_data1),
        .input_en(input_en1),
        .output_addr(output_addr1),
        .output_data(output_data1),
        .output_we(output_we1),
        .output_en(output_en1)
    );
    
    // Example 2: Larger convolution with different files
    conv2d_file #(
        .BATCH_SIZE(1),
        .IN_CHANNELS(16),
        .OUT_CHANNELS(32),
        .IN_HEIGHT(16),
        .IN_WIDTH(16),
        .KERNEL_SIZE(5),
        .STRIDE(2),
        .PADDING(2),
        .WEIGHT_FILE("conv2_weights.mem"),
        .BIAS_FILE("conv2_bias.mem")
    ) conv_layer2 (
        .clk(clk),
        .rst(rst),
        .start(start2),
        .done(done2),
        .valid(valid2),
        .input_addr(input_addr2),
        .input_data(input_data2),
        .input_en(input_en2),
        .output_addr(output_addr2),
        .output_data(output_data2),
        .output_we(output_we2),
        .output_en(output_en2)
    );
    
    // Add your connections and control logic here...
    
endmodule