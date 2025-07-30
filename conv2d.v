module conv2d #(
    parameter BATCH_SIZE   = 1,
    parameter IN_CHANNELS  = 67,
    parameter OUT_CHANNELS = 64,
    parameter IN_HEIGHT    = 4,
    parameter IN_WIDTH     = 4,
    parameter KERNEL_SIZE  = 3,
    parameter STRIDE       = 2,
    parameter PADDING      = 1,
    parameter DATA_WIDTH   = 8,
    parameter ADDR_WIDTH   = 8
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
    localparam WEIGHT_SIZE = OUT_CHANNELS * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE;
    localparam MAX_CHANNELS = 8; // Maximum supported channels for Verilog compatibility
    
    // Hardcoded weights and bias as parameters
    reg signed [DATA_WIDTH-1:0] weights [0:WEIGHT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] bias [0:OUT_CHANNELS-1];
    
// Initialize weights and bias (synthesizable)
always @(posedge clk) begin
    if (rst) begin
        // Assign weights
        weights[0] <= 32'd1;
        weights[1] <= 32'd1;
        weights[2] <= 32'd1;
        weights[3] <= 32'd1;
        weights[4] <= 32'd1;
        weights[5] <= 32'd1;
        weights[6] <= 32'd1;
        weights[7] <= 32'd1;

        // Extend as needed up to WEIGHT_SIZE-1

        // Assign bias
        bias[0] <= 32'd0;

        // Extend if OUT_CHANNELS > 1
    end
end

    
    // State machine
    localparam IDLE = 4'b0000;
    localparam INIT_WINDOW = 4'b0001;
    localparam READ_BIAS = 4'b0010;
    localparam SLIDE_WINDOW = 4'b0011;
    localparam READ_INPUT = 4'b0100;
    localparam COMPUTE_CONV = 4'b0101;
    localparam STORE_RESULT = 4'b0110;
    localparam WRITE_OUTPUT = 4'b0111;
    localparam DONE_ST = 4'b1000;
    
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
    reg signed [DATA_WIDTH+8-1:0] mac_result;
    reg [ADDR_WIDTH-1:0] computed_input_addr, computed_weight_addr, computed_output_addr;
    reg signed [DATA_WIDTH-1:0] input_val, weight_val, bias_val;
    reg input_valid, within_bounds;
    
    // Pipeline registers for computation (fixed size for Verilog)
    reg signed [DATA_WIDTH-1:0] input_vals [0:MAX_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] weight_vals [0:MAX_CHANNELS-1];
    
    // MAC computation wires for different channel configurations
    wire signed [DATA_WIDTH+8-1:0] mac_ch0, mac_ch1, mac_ch2, mac_ch3;
    wire signed [DATA_WIDTH+8-1:0] mac_ch4, mac_ch5, mac_ch6, mac_ch7;
    wire signed [DATA_WIDTH+8-1:0] mac_sum_01, mac_sum_23, mac_sum_45, mac_sum_67;
    wire signed [DATA_WIDTH+8-1:0] mac_sum_0123, mac_sum_4567, mac_sum_final;
    
    // Individual MAC operations
    assign mac_ch0 = input_vals[0] * weight_vals[0];
    assign mac_ch1 = input_vals[1] * weight_vals[1];
    assign mac_ch2 = input_vals[2] * weight_vals[2];
    assign mac_ch3 = input_vals[3] * weight_vals[3];
    assign mac_ch4 = input_vals[4] * weight_vals[4];
    assign mac_ch5 = input_vals[5] * weight_vals[5];
    assign mac_ch6 = input_vals[6] * weight_vals[6];
    assign mac_ch7 = input_vals[7] * weight_vals[7];
    
    // Hierarchical addition
    assign mac_sum_01 = mac_ch0 + mac_ch1;
    assign mac_sum_23 = mac_ch2 + mac_ch3;
    assign mac_sum_45 = mac_ch4 + mac_ch5;
    assign mac_sum_67 = mac_ch6 + mac_ch7;
    assign mac_sum_0123 = mac_sum_01 + mac_sum_23;
    assign mac_sum_4567 = mac_sum_45 + mac_sum_67;
    assign mac_sum_final = mac_sum_0123 + mac_sum_4567;
    
    // Select appropriate MAC result based on channel count
    always @(*) begin
        case (IN_CHANNELS)
            1: mac_result = mac_ch0;
            2: mac_result = mac_sum_01;
            3: mac_result = mac_sum_01 + mac_ch2;
            4: mac_result = mac_sum_0123;
            5: mac_result = mac_sum_0123 + mac_ch4;
            6: mac_result = mac_sum_0123 + mac_sum_45;
            7: mac_result = mac_sum_0123 + mac_sum_45 + mac_ch6;
            8: mac_result = mac_sum_final;
            default: mac_result = mac_sum_01; // Default to 2 channels
        endcase
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
            
            // Initialize arrays to prevent X states
            input_vals[0] <= 0; input_vals[1] <= 0; input_vals[2] <= 0; input_vals[3] <= 0;
            input_vals[4] <= 0; input_vals[5] <= 0; input_vals[6] <= 0; input_vals[7] <= 0;
            weight_vals[0] <= 0; weight_vals[1] <= 0; weight_vals[2] <= 0; weight_vals[3] <= 0;
            weight_vals[4] <= 0; weight_vals[5] <= 0; weight_vals[6] <= 0; weight_vals[7] <= 0;
            
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
                    // Load bias value from internal array
                    bias_val <= bias[out_ch_idx];
                    accumulator <= bias[out_ch_idx];
                    state <= SLIDE_WINDOW;
                end
                
                SLIDE_WINDOW: begin
                    // Setup memory read for current window position
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
                    
                    // Store input and weight values
                    if (input_valid) begin
                        input_vals[in_ch_idx] <= $signed(input_data);
                    end else begin
                        input_vals[in_ch_idx] <= 0;
                    end
                    
                    // Get weight from internal array
                    weight_vals[in_ch_idx] <= weights[computed_weight_addr];
                    
                    if (in_ch_idx == IN_CHANNELS - 1) begin
                        state <= COMPUTE_CONV;
                    end else begin
                        in_ch_idx <= in_ch_idx + 1;
                        state <= SLIDE_WINDOW;
                    end
                end
                
                COMPUTE_CONV: begin
                    // Use the combinational MAC result
                    accumulator <= accumulator + mac_result;
                    
                    // Reset in_ch_idx for next kernel position
                    in_ch_idx <= 0;

                    // Advance kernel position
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