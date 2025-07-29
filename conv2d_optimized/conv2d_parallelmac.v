// // =============================================================================
// // TOP MODULE - Instantiates and connects conv2d_file modules
// // =============================================================================

// module top;
//     // Parameters
//     parameter BATCH_SIZE   = 1;
//     parameter IN_CHANNELS  = 2;
//     parameter OUT_CHANNELS = 1;
//     parameter IN_HEIGHT    = 4;
//     parameter IN_WIDTH     = 4;
//     parameter KERNEL_SIZE  = 2;
//     parameter STRIDE       = 2;
//     parameter PADDING      = 0;
//     parameter DATA_WIDTH   = 32;
//     parameter ADDR_WIDTH   = 16;

//     // Clock and reset
//     reg clk, rst;
    
//     // Control signals
//     reg start1, start2;
//     wire done1, done2;
//     wire valid1, valid2;
    
//     // Memory interface signals for instance 1
//     wire [ADDR_WIDTH-1:0] input_addr1, output_addr1;
//     wire [DATA_WIDTH-1:0] input_data1, output_data1;
//     wire input_en1, output_en1, output_we1;
    
//     // Memory interface signals for instance 2  
//     wire [ADDR_WIDTH-1:0] input_addr2, output_addr2;
//     wire [DATA_WIDTH-1:0] input_data2, output_data2;
//     wire input_en2, output_en2, output_we2;
    
//     // Calculate memory sizes
//     localparam INPUT_MEM_SIZE = BATCH_SIZE * IN_CHANNELS * IN_HEIGHT * IN_WIDTH;
//     localparam OUTPUT_MEM_SIZE = BATCH_SIZE * OUT_CHANNELS * ((IN_HEIGHT + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1) * ((IN_WIDTH + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1);
    
//     // Shared memory arrays
//     reg [DATA_WIDTH-1:0] input_mem [0:INPUT_MEM_SIZE-1];
//     reg [DATA_WIDTH-1:0] output_mem1 [0:OUTPUT_MEM_SIZE-1];
//     reg [DATA_WIDTH-1:0] output_mem2 [0:OUTPUT_MEM_SIZE-1];
    
//     integer i;

//     // Clock generation
//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk;
//     end

//     // First conv2d_file instance
//     conv2d_file #(
//         .BATCH_SIZE(BATCH_SIZE),
//         .IN_CHANNELS(IN_CHANNELS),
//         .OUT_CHANNELS(OUT_CHANNELS),
//         .IN_HEIGHT(IN_HEIGHT),
//         .IN_WIDTH(IN_WIDTH),
//         .KERNEL_SIZE(KERNEL_SIZE),
//         .STRIDE(STRIDE),
//         .PADDING(PADDING),
//         .DATA_WIDTH(DATA_WIDTH),
//         .ADDR_WIDTH(ADDR_WIDTH),
//         .WEIGHT_FILE("weights1.mem"),
//         .BIAS_FILE("bias1.mem")
//     ) conv1 (
//         .clk(clk),
//         .rst(rst),
//         .start(start1),
//         .done(done1),
//         .valid(valid1),
//         .input_addr(input_addr1),
//         .input_data(input_data1),
//         .input_en(input_en1),
//         .output_addr(output_addr1),
//         .output_data(output_data1),
//         .output_we(output_we1),
//         .output_en(output_en1)
//     );

//     // Second conv2d_file instance
//     conv2d_file #(
//         .BATCH_SIZE(BATCH_SIZE),
//         .IN_CHANNELS(IN_CHANNELS),
//         .OUT_CHANNELS(OUT_CHANNELS),
//         .IN_HEIGHT(IN_HEIGHT),
//         .IN_WIDTH(IN_WIDTH),
//         .KERNEL_SIZE(KERNEL_SIZE),
//         .STRIDE(STRIDE),
//         .PADDING(PADDING),
//         .DATA_WIDTH(DATA_WIDTH),
//         .ADDR_WIDTH(ADDR_WIDTH),
//         .WEIGHT_FILE("weights2.mem"),
//         .BIAS_FILE("bias2.mem")
//     ) conv2 (
//         .clk(clk),
//         .rst(rst),
//         .start(start2),
//         .done(done2),
//         .valid(valid2),
//         .input_addr(input_addr2),
//         .input_data(input_data2),
//         .input_en(input_en2),
//         .output_addr(output_addr2),
//         .output_data(output_data2),
//         .output_we(output_we2),
//         .output_en(output_en2)
//     );

//     // Memory interface for instance 1
//     assign input_data1 = (input_en1 && input_addr1 < INPUT_MEM_SIZE) ? input_mem[input_addr1] : {DATA_WIDTH{1'b0}};
    
//     always @(posedge clk) begin
//         if (output_en1 && output_we1 && output_addr1 < OUTPUT_MEM_SIZE) begin
//             output_mem1[output_addr1] <= output_data1;
//         end
//     end

//     // Memory interface for instance 2
//     assign input_data2 = (input_en2 && input_addr2 < INPUT_MEM_SIZE) ? input_mem[input_addr2] : {DATA_WIDTH{1'b0}};
    
//     always @(posedge clk) begin
//         if (output_en2 && output_we2 && output_addr2 < OUTPUT_MEM_SIZE) begin
//             output_mem2[output_addr2] <= output_data2;
//         end
//     end

//     // Test stimulus
//     initial begin
//         $display("=== Starting Top Module Test ===");
        
//         // Initialize
//         rst = 1;
//         start1 = 0;
//         start2 = 0;
        
//         // Initialize input memory
//         for (i = 0; i < INPUT_MEM_SIZE; i = i + 1) begin
//             input_mem[i] = i;
//         end
        
//         // Initialize output memories
//         for (i = 0; i < OUTPUT_MEM_SIZE; i = i + 1) begin
//             output_mem1[i] = 0;
//             output_mem2[i] = 0;
//         end
        
//         #20;
//         rst = 0;
//         #10;
        
//         // Start both convolutions
//         $display("Starting convolutions...");
//         start1 = 1;
//         start2 = 1;
//         @(posedge clk);
//         start1 = 0;
//         start2 = 0;
        
//         // Wait for completion
//         wait (done1 && done2);
        
//         $display("Both convolutions completed!");
//         $display("Conv1 output: %0d %0d %0d %0d", output_mem1[0], output_mem1[1], output_mem1[2], output_mem1[3]);
//         $display("Conv2 output: %0d %0d %0d %0d", output_mem2[0], output_mem2[1], output_mem2[2], output_mem2[3]);
        
//         #100;
//         $finish;
//     end

// endmodule

// =============================================================================
// CONV2D FILE MODULE - Fixed version of your original module
// =============================================================================

module conv2d_file #(
    parameter BATCH_SIZE   = 1,
    parameter IN_CHANNELS  = 2,
    parameter OUT_CHANNELS = 1,
    parameter IN_HEIGHT    = 4,
    parameter IN_WIDTH     = 4,
    parameter KERNEL_SIZE  = 2,
    parameter STRIDE       = 2,
    parameter PADDING      = 0,
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 16,
    parameter WEIGHT_FILE  = "weights.mem",
    parameter BIAS_FILE    = "bias.mem"
)(
    input clk,
    input rst,
    input start,
    
    output reg done,
    output reg valid,
    
    // Input memory interface
    output reg [ADDR_WIDTH-1:0] input_addr,
    input [DATA_WIDTH-1:0] input_data,
    output reg input_en,
    
    // Output memory interface
    output reg [ADDR_WIDTH-1:0] output_addr,
    output reg [DATA_WIDTH-1:0] output_data,
    output reg output_we,
    output reg output_en
);

    // Calculate output dimensions
    localparam OUT_HEIGHT = (IN_HEIGHT + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    localparam OUT_WIDTH  = (IN_WIDTH  + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    
    // Memory sizes
    localparam WEIGHT_MEM_SIZE = OUT_CHANNELS * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE;
    localparam BIAS_MEM_SIZE = OUT_CHANNELS;
    
    // Internal weight and bias memories
    reg [DATA_WIDTH-1:0] weight_mem [0:WEIGHT_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] bias_mem [0:BIAS_MEM_SIZE-1];
    
    // State machine
    localparam IDLE = 4'b0000;
    localparam INIT_WINDOW = 4'b0001;
    localparam READ_BIAS = 4'b0010;
    localparam SLIDE_WINDOW = 4'b0011;
    localparam READ_INPUT = 4'b0100;
    localparam READ_WEIGHT = 4'b0101;
    localparam COMPUTE_CONV = 4'b0110;
    localparam STORE_RESULT = 4'b0111;
    localparam WRITE_OUTPUT = 4'b1000;
    localparam DONE_ST = 4'b1001;
    
    reg [3:0] state;
    
    // Position counters
    reg [7:0] batch_idx;
    reg [7:0] out_ch_idx;
    reg [7:0] out_row;
    reg [7:0] out_col;
    reg [7:0] in_ch_idx;
    reg [7:0] kernel_row;
    reg [7:0] kernel_col;
    
    // Computation variables
    reg signed [15:0] input_row, input_col;
    reg signed [DATA_WIDTH+8-1:0] accumulator;
    reg [ADDR_WIDTH-1:0] computed_input_addr, computed_weight_addr, computed_output_addr;
    reg signed [DATA_WIDTH-1:0] input_val, weight_val, bias_val;
    reg input_valid, within_bounds;
    
    integer j;
    reg signed [DATA_WIDTH+8-1:0] mac_sum;
    reg signed [DATA_WIDTH-1:0] input_vals [0:IN_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] weight_vals [0:IN_CHANNELS-1];

    // Initialize weights and biases from files
    initial begin
        $readmemh(WEIGHT_FILE, weight_mem);
        $readmemh(BIAS_FILE, bias_mem);
    end
    
    // Address calculation
    always @(*) begin
        // Calculate input coordinates
        input_row = $signed(out_row) * $signed(STRIDE) + $signed(kernel_row) - $signed(PADDING);
        input_col = $signed(out_col) * $signed(STRIDE) + $signed(kernel_col) - $signed(PADDING);
        
        // Check bounds
        within_bounds = (input_row >= 0) && (input_row < IN_HEIGHT) && 
                       (input_col >= 0) && (input_col < IN_WIDTH);
        
        // Calculate memory addresses
        computed_input_addr = batch_idx * (IN_CHANNELS * IN_HEIGHT * IN_WIDTH) +
                             in_ch_idx * (IN_HEIGHT * IN_WIDTH) +
                             input_row * IN_WIDTH + input_col;
                             
        computed_weight_addr = out_ch_idx * (IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE) +
                              in_ch_idx * (KERNEL_SIZE * KERNEL_SIZE) +
                              kernel_row * KERNEL_SIZE + kernel_col;
                              
        computed_output_addr = batch_idx * (OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH) +
                              out_ch_idx * (OUT_HEIGHT * OUT_WIDTH) +
                              out_row * OUT_WIDTH + out_col;
    end
    
    // Main state machine
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            
            // Reset counters
            batch_idx <= 0;
            out_ch_idx <= 0;
            out_row <= 0;
            out_col <= 0;
            in_ch_idx <= 0;
            kernel_row <= 0;
            kernel_col <= 0;
            accumulator <= 0;
            
            // Reset memory interfaces
            input_en <= 0;
            output_en <= 0;
            output_we <= 0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    input_en <= 0;
                    output_en <= 0;
                    output_we <= 0;
                    
                    if (start) begin
                        state <= INIT_WINDOW;
                        batch_idx <= 0;
                        out_ch_idx <= 0;
                        out_row <= 0;
                        out_col <= 0;
                    end
                end
                
                INIT_WINDOW: begin
                    // Initialize window for current output position
                    in_ch_idx <= 0;
                    kernel_row <= 0;
                    kernel_col <= 0;
                    state <= READ_BIAS;
                end
                
                READ_BIAS: begin
                    // Read bias from internal memory
                    bias_val <= $signed(bias_mem[out_ch_idx]);
                    accumulator <= $signed(bias_mem[out_ch_idx]);
                    state <= SLIDE_WINDOW;
                end
                
                SLIDE_WINDOW: begin
                    // Setup memory reads for current window position
                    if (within_bounds) begin
                        input_addr <= computed_input_addr;
                        input_en <= 1;
                        input_valid <= 1;
                    end else begin
                        input_en <= 0;
                        input_valid <= 0;
                        input_val <= 0; // Zero padding
                    end
                    
                    state <= READ_INPUT;
                end
                
                READ_INPUT: begin
                    input_en <= 0;
                    if (input_valid) begin
                        input_vals[in_ch_idx] <= $signed(input_data);
                    end else begin
                        input_vals[in_ch_idx] <= 0;
                    end
                    state <= READ_WEIGHT;
                end
                
                READ_WEIGHT: begin
                    // Read weight from internal memory
                    weight_vals[in_ch_idx] <= $signed(weight_mem[computed_weight_addr]);
                    
                    if (in_ch_idx == IN_CHANNELS - 1) begin
                        state <= COMPUTE_CONV;
                    end else begin
                        in_ch_idx <= in_ch_idx + 1;
                        state <= SLIDE_WINDOW;
                    end
                end
                
                COMPUTE_CONV: begin
                    mac_sum = 0;
                    for (j = 0; j < IN_CHANNELS; j = j + 1) begin
                        mac_sum = mac_sum + input_vals[j] * weight_vals[j];
                    end
                    accumulator <= accumulator + mac_sum;
                    
                    // Reset in_ch_idx for next kernel position
                    in_ch_idx <= 0;

                    // Advance kernel
                    if (kernel_col == KERNEL_SIZE - 1) begin
                        kernel_col <= 0;
                        if (kernel_row == KERNEL_SIZE - 1) begin
                            kernel_row <= 0;
                            state <= STORE_RESULT;
                        end else begin
                            kernel_row <= kernel_row + 1;
                            state <= SLIDE_WINDOW;
                        end
                    end else begin
                        kernel_col <= kernel_col + 1;
                        state <= SLIDE_WINDOW;
                    end
                end
                
                STORE_RESULT: begin
                    // Setup output write
                    output_addr <= computed_output_addr;
                    output_data <= accumulator[DATA_WIDTH-1:0];
                    output_en <= 1;
                    output_we <= 1;
                    state <= WRITE_OUTPUT;
                end
                
                WRITE_OUTPUT: begin
                    output_en <= 0;
                    output_we <= 0;
                    
                    // Move to next output position
                    if (out_col == OUT_WIDTH - 1) begin
                        out_col <= 0;
                        if (out_row == OUT_HEIGHT - 1) begin
                            out_row <= 0;
                            if (out_ch_idx == OUT_CHANNELS - 1) begin
                                out_ch_idx <= 0;
                                if (batch_idx == BATCH_SIZE - 1) begin
                                    state <= DONE_ST;
                                end else begin
                                    batch_idx <= batch_idx + 1;
                                    state <= INIT_WINDOW;
                                end
                            end else begin
                                out_ch_idx <= out_ch_idx + 1;
                                state <= INIT_WINDOW;
                            end
                        end else begin
                            out_row <= out_row + 1;
                            state <= INIT_WINDOW;
                        end
                    end else begin
                        out_col <= out_col + 1;
                        state <= INIT_WINDOW;
                    end
                end
                
                DONE_ST: begin
                    done <= 1;
                    valid <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
