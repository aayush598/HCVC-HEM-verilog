module conv2d #(
    parameter BATCH_SIZE   = 1,
    parameter IN_CHANNELS  = 2,
    parameter OUT_CHANNELS = 1,
    parameter IN_HEIGHT    = 4,
    parameter IN_WIDTH     = 4,
    parameter KERNEL_SIZE  = 2,
    parameter STRIDE       = 2,
    parameter PADDING      = 0,
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 16
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
    
    // Weight memory interface  
    output reg [ADDR_WIDTH-1:0] weight_addr,
    input [DATA_WIDTH-1:0] weight_data,
    output reg weight_en,
    
    // Bias memory interface
    output reg [ADDR_WIDTH-1:0] bias_addr,
    input [DATA_WIDTH-1:0] bias_data,
    output reg bias_en,
    
    // Output memory interface
    output reg [ADDR_WIDTH-1:0] output_addr,
    output reg [DATA_WIDTH-1:0] output_data,
    output reg output_we,
    output reg output_en
);

    // Calculate output dimensions
    localparam OUT_HEIGHT = (IN_HEIGHT + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    localparam OUT_WIDTH  = (IN_WIDTH  + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    
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
    
    reg [3:0] state, next_state;
    
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
    
    // Pipeline registers for memory access
    reg [DATA_WIDTH-1:0] input_data_reg, weight_data_reg, bias_data_reg;
    reg memory_read_done;
    
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
            weight_en <= 0;
            bias_en <= 0;
            output_en <= 0;
            output_we <= 0;
            
            memory_read_done <= 0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    input_en <= 0;
                    weight_en <= 0;
                    bias_en <= 0;
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
                    
                    // Setup bias read
                    bias_addr <= out_ch_idx;
                    bias_en <= 1;
                end
                
                READ_BIAS: begin
                    bias_en <= 0;
                    bias_val <= $signed(bias_data);
                    accumulator <= $signed(bias_data);
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
                    
                    weight_addr <= computed_weight_addr;
                    weight_en <= 1;
                    
                    state <= READ_INPUT;
                end
                
                READ_INPUT: begin
                    input_en <= 0;
                    if (input_valid) begin
                        input_data_reg <= input_data;
                        input_val <= $signed(input_data);
                    end else begin
                        input_val <= 0;
                    end
                    state <= READ_WEIGHT;
                end
                
                READ_WEIGHT: begin
                    weight_en <= 0;
                    weight_data_reg <= weight_data;
                    weight_val <= $signed(weight_data);
                    state <= COMPUTE_CONV;
                end
                
                COMPUTE_CONV: begin
                    // Perform convolution computation
                    accumulator <= accumulator + (input_val * weight_val);
                    
                    // Move to next position in sliding window
                    if (kernel_col == KERNEL_SIZE - 1) begin
                        kernel_col <= 0;
                        if (kernel_row == KERNEL_SIZE - 1) begin
                            kernel_row <= 0;
                            if (in_ch_idx == IN_CHANNELS - 1) begin
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