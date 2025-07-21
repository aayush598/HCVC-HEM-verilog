
// Testbench for Leaky ReLU
module tb_leaky_relu();

    // Parameters
    parameter DATA_WIDTH = 16;
    parameter FRAC_WIDTH = 8;
    parameter CLK_PERIOD = 10;

    // Signals
    reg clk;
    reg rst_n;
    reg signed [DATA_WIDTH-1:0] x_in;
    reg valid_in;
    wire signed [DATA_WIDTH-1:0] y_out;
    wire valid_out;

    // Test vectors and expected outputs
    reg signed [DATA_WIDTH-1:0] test_inputs [0:9];
    reg signed [DATA_WIDTH-1:0] expected_outputs [0:9];
    integer i;

    // Instantiate DUT
    leaky_relu #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .valid_in(valid_in),
        .y_out(y_out),
        .valid_out(valid_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Initialize test vectors
    initial begin
        // Test inputs (in fixed-point format with 8 fractional bits)
        test_inputs[0] = 16'h0100;  // +1.0 (256 in fixed-point)
        test_inputs[1] = 16'h0200;  // +2.0 (512 in fixed-point)  
        test_inputs[2] = 16'h0080;  // +0.5 (128 in fixed-point)
        test_inputs[3] = 16'h0000;  // 0.0
        test_inputs[4] = 16'hFF00;  // -1.0 (-256 in fixed-point)
        test_inputs[5] = 16'hFE00;  // -2.0 (-512 in fixed-point)
        test_inputs[6] = 16'hFF80;  // -0.5 (-128 in fixed-point)
        test_inputs[7] = 16'h0400;  // +4.0 (1024 in fixed-point)
        test_inputs[8] = 16'hFC00;  // -4.0 (-1024 in fixed-point)
        test_inputs[9] = 16'h0001;  // Small positive (1/256)

        // Expected outputs (for alpha = 1/128 = 0.0078125)
        expected_outputs[0] = 16'h0100;  // +1.0 (positive, unchanged)
        expected_outputs[1] = 16'h0200;  // +2.0 (positive, unchanged)
        expected_outputs[2] = 16'h0080;  // +0.5 (positive, unchanged)
        expected_outputs[3] = 16'h0000;  // 0.0 (unchanged)
        expected_outputs[4] = 16'hFFFE;  // -1.0/128 ≈ -0.0078 (-2 in fixed-point)
        expected_outputs[5] = 16'hFFFC;  // -2.0/128 ≈ -0.0156 (-4 in fixed-point)
        expected_outputs[6] = 16'hFFFF;  // -0.5/128 ≈ -0.0039 (-1 in fixed-point)
        expected_outputs[7] = 16'h0400;  // +4.0 (positive, unchanged)
        expected_outputs[8] = 16'hFFF8;  // -4.0/128 ≈ -0.0312 (-8 in fixed-point)
        expected_outputs[9] = 16'h0001;  // Small positive (unchanged)
    end

    // Test sequence
    initial begin
        $dumpfile("leaky_relu_tb.vcd");
        $dumpvars(0, tb_leaky_relu);
        
        // Initialize
        rst_n = 0;
        valid_in = 0;
        x_in = 0;
        
        // Reset
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        $display("Starting Leaky ReLU Test");
        $display("Time\t\tInput\t\tOutput\t\tExpected\tPass/Fail");
        $display("----\t\t-----\t\t------\t\t--------\t---------");
        
        // Apply test vectors
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            x_in = test_inputs[i];
            valid_in = 1;
            
            @(posedge clk);
            valid_in = 0;
            
            // Wait for output
            while (!valid_out) @(posedge clk);
            
            // Check result
            if (y_out == expected_outputs[i]) begin
                $display("%0t\t\t%d\t\t%d\t\t%d\t\tPASS", 
                    $time, test_inputs[i], y_out, expected_outputs[i]);
            end else begin
                $display("%0t\t\t%d\t\t%d\t\t%d\t\tFAIL", 
                    $time, test_inputs[i], y_out, expected_outputs[i]);
            end
            
            @(posedge clk);
        end
        
        $display("\nTest completed");
        $finish;
    end

    // Timeout
    initial begin
        #10000;
        $display("Test timeout!");
        $finish;
    end

endmodule