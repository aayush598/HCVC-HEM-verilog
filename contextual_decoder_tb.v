module contextual_decoder_tb;

    // Parameters
    parameter DATA_WIDTH = 16;  // Using 16-bit for easier verification
    parameter BATCH_SIZE = 1;
    parameter HEIGHT = 2;
    parameter WIDTH = 2;
    parameter CHANNEL_N = 4;    // Reduced for testbench
    parameter CHANNEL_M = 6;    // Reduced for testbench
    parameter CLK_PERIOD = 10;

    // Clock and reset
    reg clk;
    reg rst;
    reg start;
    
    // Input signals
    reg [BATCH_SIZE*CHANNEL_M*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_in;
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*4*DATA_WIDTH-1:0] context2;
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*2*DATA_WIDTH-1:0] context3;
    
    // Weight and bias inputs (simplified - using small values for testing)
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
    
    // File handles for writing outputs
    integer output_file;
    integer i, j;
    
    // Instantiate DUT
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
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Initialize weights and biases with simple patterns
    task initialize_weights;
        integer idx;
        begin
            // Initialize all weights to small positive values (0.1 in fixed point)
            for (idx = 0; idx < CHANNEL_N*4*CHANNEL_M*3*3; idx = idx + 1) begin
                up1_weights[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199; // ~0.1 in Q8.8
            end
            for (idx = 0; idx < CHANNEL_N*4; idx = idx + 1) begin
                up1_bias[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066; // ~0.025 in Q8.8
            end
            
            // Similar initialization for other weights (simplified)
            for (idx = 0; idx < CHANNEL_N*4*CHANNEL_N*3*3; idx = idx + 1) begin
                up2_weights[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199;
            end
            for (idx = 0; idx < CHANNEL_N*4; idx = idx + 1) begin
                up2_bias[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066;
            end
            
            // ResBlock weights
            for (idx = 0; idx < CHANNEL_N*CHANNEL_N*2*3*3; idx = idx + 1) begin
                res1_weights1[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199;
            end
            for (idx = 0; idx < CHANNEL_N; idx = idx + 1) begin
                res1_bias1[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066;
            end
            for (idx = 0; idx < CHANNEL_N*2*CHANNEL_N*3*3; idx = idx + 1) begin
                res1_weights2[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199;
            end
            for (idx = 0; idx < CHANNEL_N*2; idx = idx + 1) begin
                res1_bias2[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066;
            end
            
            // UP3 weights
            for (idx = 0; idx < CHANNEL_N*4*CHANNEL_N*2*3*3; idx = idx + 1) begin
                up3_weights[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199;
            end
            for (idx = 0; idx < CHANNEL_N*4; idx = idx + 1) begin
                up3_bias[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066;
            end
            
            // ResBlock2 weights
            for (idx = 0; idx < CHANNEL_N*CHANNEL_N*2*3*3; idx = idx + 1) begin
                res2_weights1[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199;
            end
            for (idx = 0; idx < CHANNEL_N; idx = idx + 1) begin
                res2_bias1[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066;
            end
            for (idx = 0; idx < CHANNEL_N*2*CHANNEL_N*3*3; idx = idx + 1) begin
                res2_weights2[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199;
            end
            for (idx = 0; idx < CHANNEL_N*2; idx = idx + 1) begin
                res2_bias2[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066;
            end
            
            // UP4 weights
            for (idx = 0; idx < 128*CHANNEL_N*2*3*3; idx = idx + 1) begin
                up4_weights[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0199;
            end
            for (idx = 0; idx < 128; idx = idx + 1) begin
                up4_bias[idx*DATA_WIDTH +: DATA_WIDTH] = 16'h0066;
            end
        end
    endtask
    
    // Initialize input data
    task initialize_inputs;
        integer idx;
        begin
            // Initialize x_in with incrementing pattern
            for (idx = 0; idx < BATCH_SIZE*CHANNEL_M*HEIGHT*WIDTH; idx = idx + 1) begin
                x_in[idx*DATA_WIDTH +: DATA_WIDTH] = (idx + 1) << 8; // Convert to Q8.8
            end
            
            // Initialize context2 with pattern
            for (idx = 0; idx < BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*4; idx = idx + 1) begin
                context2[idx*DATA_WIDTH +: DATA_WIDTH] = ((idx % 8) + 1) << 7; // Q8.8
            end
            
            // Initialize context3 with pattern  
            for (idx = 0; idx < BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*2; idx = idx + 1) begin
                context3[idx*DATA_WIDTH +: DATA_WIDTH] = ((idx % 4) + 1) << 7; // Q8.8
            end
        end
    endtask
    
    // Write input data to files for Python verification
    task write_input_data;
        integer idx;
        begin
            output_file = $fopen("verilog_inputs.txt", "w");
            
            // Write x_in
            $fwrite(output_file, "x_in:\n");
            for (idx = 0; idx < BATCH_SIZE*CHANNEL_M*HEIGHT*WIDTH; idx = idx + 1) begin
                $fwrite(output_file, "%d\n", $signed(x_in[idx*DATA_WIDTH +: DATA_WIDTH]));
            end
            
            // Write context2
            $fwrite(output_file, "context2:\n");
            for (idx = 0; idx < BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*4; idx = idx + 1) begin
                $fwrite(output_file, "%d\n", $signed(context2[idx*DATA_WIDTH +: DATA_WIDTH]));
            end
            
            // Write context3
            $fwrite(output_file, "context3:\n");
            for (idx = 0; idx < BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*2; idx = idx + 1) begin
                $fwrite(output_file, "%d\n", $signed(context3[idx*DATA_WIDTH +: DATA_WIDTH]));
            end
            
            // Write weights (simplified - just up1 weights as example)
            $fwrite(output_file, "up1_weights:\n");
            for (idx = 0; idx < CHANNEL_N*4*CHANNEL_M*3*3; idx = idx + 1) begin
                $fwrite(output_file, "%d\n", $signed(up1_weights[idx*DATA_WIDTH +: DATA_WIDTH]));
            end
            
            $fclose(output_file);
        end
    endtask
    
    // Write output data to file
    task write_output_data;
        integer idx;
        begin
            output_file = $fopen("verilog_outputs.txt", "w");
            $fwrite(output_file, "feature_out:\n");
            for (idx = 0; idx < BATCH_SIZE*32*HEIGHT*WIDTH*16; idx = idx + 1) begin
                $fwrite(output_file, "%d\n", $signed(feature_out[idx*DATA_WIDTH +: DATA_WIDTH]));
            end
            $fclose(output_file);
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst = 1;
        start = 0;
        
        // Initialize weights and inputs
        initialize_weights();
        initialize_inputs();
        
        // Write input data for Python verification
        write_input_data();
        
        // Reset sequence
        #(CLK_PERIOD * 2);
        rst = 0;
        #(CLK_PERIOD * 2);
        
        // Start processing
        $display("Starting contextual decoder test...");
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        // Wait for completion
        wait(done);
        #(CLK_PERIOD * 5);
        
        // Write outputs
        write_output_data();
        
        $display("Test completed. Done signal asserted.");
        $display("Input and output data written to files for Python verification.");
        
        // Display some output values
        $display("First few output values:");
        for (i = 0; i < 8; i = i + 1) begin
            $display("feature_out[%0d] = %d", i, $signed(feature_out[i*DATA_WIDTH +: DATA_WIDTH]));
        end
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 10000);
        $display("ERROR: Timeout - test did not complete");
        $finish;
    end
    
    // Monitor key signals
    initial begin
        $monitor("Time=%0t, rst=%b, start=%b, done=%b", 
                 $time, rst, start, done);
    end

endmodule