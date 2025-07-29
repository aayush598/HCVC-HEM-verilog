module conv2d #(
    parameter BATCH_SIZE   = 1,
    parameter IN_CHANNELS  = 2,
    parameter OUT_CHANNELS = 1,
    parameter IN_HEIGHT    = 4,
    parameter IN_WIDTH     = 4,
    parameter KERNEL_SIZE  = 2,
    parameter STRIDE       = 2,
    parameter PADDING      = 0,
    parameter DATA_WIDTH   = 32
)(
    input clk,
    input rst,
    input start,
    
    output reg done,
    output reg valid,
    
    input  [BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat,
    input  [OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_flat,
    input  [OUT_CHANNELS*DATA_WIDTH-1:0] bias_flat,
    output [BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH*DATA_WIDTH-1:0] output_tensor_flat
);

    // Calculate output dimensions
    localparam OUT_HEIGHT = (IN_HEIGHT + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    localparam OUT_WIDTH  = (IN_WIDTH  + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    
    // Calculate total elements
    localparam TOTAL_INPUT_SIZE = BATCH_SIZE * IN_CHANNELS * IN_HEIGHT * IN_WIDTH;
    localparam TOTAL_WEIGHT_SIZE = OUT_CHANNELS * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE;
    localparam TOTAL_BIAS_SIZE = OUT_CHANNELS;
    localparam TOTAL_OUTPUT_SIZE = BATCH_SIZE * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH;
    
    // State machine for sliding window
    localparam IDLE = 3'b000;
    localparam INIT_WINDOW = 3'b001;
    localparam SLIDE_WINDOW = 3'b010;
    localparam COMPUTE_CONV = 3'b011;
    localparam STORE_RESULT = 3'b100;
    localparam DONE_ST = 3'b101;
    
    reg [2:0] state, next_state;
    
    // Sliding window position counters
    reg [7:0] batch_idx;        // Current batch
    reg [7:0] out_ch_idx;       // Current output channel
    reg [7:0] out_row;          // Current output row
    reg [7:0] out_col;          // Current output column
    
    // Window computation counters
    reg [7:0] window_step;      // Current step in window computation (0 to KERNEL_SIZE*KERNEL_SIZE*IN_CHANNELS-1)
    reg [7:0] in_ch_idx;        // Current input channel within window
    reg [7:0] kernel_row;       // Current kernel row within window
    reg [7:0] kernel_col;       // Current kernel col within window
    
    // Sliding window variables
    reg signed [15:0] input_row, input_col;  // Current input coordinates
    reg signed [DATA_WIDTH+8-1:0] accumulator;
    reg [31:0] in_index, weight_index, out_index, bias_index;
    reg signed [DATA_WIDTH-1:0] input_val, weight_val, bias_val;
    
    // Memory arrays
    reg [DATA_WIDTH-1:0] input_mem [0:TOTAL_INPUT_SIZE-1];
    reg [DATA_WIDTH-1:0] weight_mem [0:TOTAL_WEIGHT_SIZE-1];
    reg [DATA_WIDTH-1:0] bias_mem [0:TOTAL_BIAS_SIZE-1];
    reg [DATA_WIDTH-1:0] output_mem [0:TOTAL_OUTPUT_SIZE-1];
    
    integer i;
    
    // Unpack input data into memory arrays
    always @(*) begin
        for (i = 0; i < TOTAL_INPUT_SIZE; i = i + 1)
            input_mem[i] = input_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH];
        for (i = 0; i < TOTAL_WEIGHT_SIZE; i = i + 1)
            weight_mem[i] = weights_flat[i*DATA_WIDTH +: DATA_WIDTH];
        for (i = 0; i < TOTAL_BIAS_SIZE; i = i + 1)
            bias_mem[i] = bias_flat[i*DATA_WIDTH +: DATA_WIDTH];
    end
    
    // Sliding window position calculation
    always @(*) begin
        // Calculate input coordinates based on sliding window position
        input_row = $signed(out_row) * $signed(STRIDE) + $signed(kernel_row) - $signed(PADDING);
        input_col = $signed(out_col) * $signed(STRIDE) + $signed(kernel_col) - $signed(PADDING);
        
        // Calculate memory indices
        bias_index = out_ch_idx;
        bias_val = $signed(bias_mem[bias_index]);
        
        // Get input value with boundary checking (padding)
        if (input_row >= 0 && input_row < IN_HEIGHT && input_col >= 0 && input_col < IN_WIDTH) begin
            in_index = batch_idx * IN_CHANNELS * IN_HEIGHT * IN_WIDTH +
                      in_ch_idx * IN_HEIGHT * IN_WIDTH +
                      input_row * IN_WIDTH + input_col;
            input_val = $signed(input_mem[in_index]);
        end else begin
            input_val = 0; // Zero padding
        end
        
        // Get weight value
        weight_index = out_ch_idx * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE +
                      in_ch_idx * KERNEL_SIZE * KERNEL_SIZE +
                      kernel_row * KERNEL_SIZE + kernel_col;
        weight_val = $signed(weight_mem[weight_index]);
        
        // Calculate output index
        out_index = batch_idx * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH +
                   out_ch_idx * OUT_HEIGHT * OUT_WIDTH +
                   out_row * OUT_WIDTH + out_col;
    end
    
    // Main sliding window state machine
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            
            // Reset all counters
            batch_idx <= 0;
            out_ch_idx <= 0;
            out_row <= 0;
            out_col <= 0;
            window_step <= 0;
            in_ch_idx <= 0;
            kernel_row <= 0;
            kernel_col <= 0;
            accumulator <= 0;
            
            // Initialize output memory
            for (i = 0; i < TOTAL_OUTPUT_SIZE; i = i + 1)
                output_mem[i] <= 0;
                
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        state <= INIT_WINDOW;
                        // Reset all position counters
                        batch_idx <= 0;
                        out_ch_idx <= 0;
                        out_row <= 0;
                        out_col <= 0;
                    end
                end
                
                INIT_WINDOW: begin
                    // Initialize sliding window for current output position
                    window_step <= 0;
                    in_ch_idx <= 0;
                    kernel_row <= 0;
                    kernel_col <= 0;
                    accumulator <= bias_val; // Start with bias
                    state <= SLIDE_WINDOW;
                end
                
                SLIDE_WINDOW: begin
                    // Position the sliding window at current kernel position
                    state <= COMPUTE_CONV;
                end
                
                COMPUTE_CONV: begin
                    // Perform convolution at current window position
                    accumulator <= accumulator + (input_val * weight_val);
                    
                    // Move to next position in sliding window
                    if (kernel_col == KERNEL_SIZE - 1) begin
                        kernel_col <= 0;
                        if (kernel_row == KERNEL_SIZE - 1) begin
                            kernel_row <= 0;
                            if (in_ch_idx == IN_CHANNELS - 1) begin
                                // Finished sliding window for current output position
                                state <= STORE_RESULT;
                            end else begin
                                in_ch_idx <= in_ch_idx + 1;
                                state <= SLIDE_WINDOW;
                            end
                        end else begin
                            kernel_row <= kernel_row + 1;
                            state <= SLIDE_WINDOW;
                        end
                    end else begin
                        kernel_col <= kernel_col + 1;
                        state <= SLIDE_WINDOW;
                    end
                    
                    window_step <= window_step + 1;
                end
                
                STORE_RESULT: begin
                    // Store the computed result
                    output_mem[out_index] <= accumulator;
                    
                    // Move to next output position
                    if (out_col == OUT_WIDTH - 1) begin
                        out_col <= 0;
                        if (out_row == OUT_HEIGHT - 1) begin
                            out_row <= 0;
                            if (out_ch_idx == OUT_CHANNELS - 1) begin
                                out_ch_idx <= 0;
                                if (batch_idx == BATCH_SIZE - 1) begin
                                    // All positions processed
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
    
    // Pack output tensor
    genvar j;
    generate
        for (j = 0; j < TOTAL_OUTPUT_SIZE; j = j + 1) begin : output_pack
            assign output_tensor_flat[j*DATA_WIDTH +: DATA_WIDTH] = output_mem[j];
        end
    endgenerate

endmodule