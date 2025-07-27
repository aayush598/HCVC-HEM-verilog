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
    
    // State machine
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE_ST = 2'b10;
    
    reg [1:0] state, next_state;
    
    // Counters
    reg [7:0] b, out_ch, out_h, out_w, in_ch, k_h, k_w;
    
    // Computation variables
    reg signed [DATA_WIDTH+8-1:0] accumulator;
    reg signed [15:0] input_h, input_w;
    reg [31:0] in_index, w_index, out_index;
    reg signed [DATA_WIDTH-1:0] input_val, weight_val;
    reg store_result;
    
    // Memory arrays
    reg [DATA_WIDTH-1:0] input_mem [0:TOTAL_INPUT_SIZE-1];
    reg [DATA_WIDTH-1:0] weight_mem [0:TOTAL_WEIGHT_SIZE-1];
    reg [DATA_WIDTH-1:0] bias_mem [0:TOTAL_BIAS_SIZE-1];
    reg [DATA_WIDTH-1:0] output_mem [0:TOTAL_OUTPUT_SIZE-1];
    
    integer i;
    
    // Unpack input data
    always @(*) begin
        for (i = 0; i < TOTAL_INPUT_SIZE; i = i + 1)
            input_mem[i] = input_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH];
        for (i = 0; i < TOTAL_WEIGHT_SIZE; i = i + 1)
            weight_mem[i] = weights_flat[i*DATA_WIDTH +: DATA_WIDTH];
        for (i = 0; i < TOTAL_BIAS_SIZE; i = i + 1)
            bias_mem[i] = bias_flat[i*DATA_WIDTH +: DATA_WIDTH];
    end
    
    // Calculate indices and values
    always @(*) begin
        // Calculate input coordinates
        input_h = $signed(out_h) * $signed(STRIDE) + $signed(k_h) - $signed(PADDING);
        input_w = $signed(out_w) * $signed(STRIDE) + $signed(k_w) - $signed(PADDING);
        
        // Get input value (with padding check)
        if (input_h >= 0 && input_h < IN_HEIGHT && input_w >= 0 && input_w < IN_WIDTH) begin
            in_index = b * IN_CHANNELS * IN_HEIGHT * IN_WIDTH +
                      in_ch * IN_HEIGHT * IN_WIDTH +
                      input_h * IN_WIDTH + input_w;
            input_val = $signed(input_mem[in_index]);
        end else begin
            input_val = 0; // Padding
        end
        
        // Get weight value
        w_index = out_ch * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE +
                 in_ch * KERNEL_SIZE * KERNEL_SIZE +
                 k_h * KERNEL_SIZE + k_w;
        weight_val = $signed(weight_mem[w_index]);
        
        // Check if we should store result (last element of convolution window)
        store_result = (k_w == KERNEL_SIZE - 1) && (k_h == KERNEL_SIZE - 1) && (in_ch == IN_CHANNELS - 1);
    end
    
    // Main computation logic
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            b <= 0;
            out_ch <= 0;
            out_h <= 0;
            out_w <= 0;
            in_ch <= 0;
            k_h <= 0;
            k_w <= 0;
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
                        state <= COMPUTE;
                        // Initialize all counters
                        b <= 0;
                        out_ch <= 0;
                        out_h <= 0;
                        out_w <= 0;
                        in_ch <= 0;
                        k_h <= 0;
                        k_w <= 0;
                        // Initialize accumulator with bias for first output
                        accumulator <= $signed(bias_mem[0]);
                    end
                end
                
                COMPUTE: begin
                    // Always accumulate the current multiplication
                    accumulator <= accumulator + (input_val * weight_val);
                    
                    // If this is the last element for current output position, store result
                    if (store_result) begin
                        out_index = b * OUT_CHANNELS * OUT_HEIGHT * OUT_WIDTH +
                                   out_ch * OUT_HEIGHT * OUT_WIDTH +
                                   out_h * OUT_WIDTH + out_w;
                        output_mem[out_index] <= (accumulator + (input_val * weight_val));
                    end
                    
                    // Update counters
                    if (k_w == KERNEL_SIZE - 1) begin
                        k_w <= 0;
                        if (k_h == KERNEL_SIZE - 1) begin
                            k_h <= 0;
                            if (in_ch == IN_CHANNELS - 1) begin
                                in_ch <= 0;
                                
                                // Move to next output position
                                if (out_w == OUT_WIDTH - 1) begin
                                    out_w <= 0;
                                    if (out_h == OUT_HEIGHT - 1) begin
                                        out_h <= 0;
                                        if (out_ch == OUT_CHANNELS - 1) begin
                                            out_ch <= 0;
                                            if (b == BATCH_SIZE - 1) begin
                                                // All done
                                                state <= DONE_ST;
                                            end else begin
                                                b <= b + 1;
                                                accumulator <= $signed(bias_mem[0]);
                                            end
                                        end else begin
                                            out_ch <= out_ch + 1;
                                            accumulator <= $signed(bias_mem[out_ch + 1]);
                                        end
                                    end else begin
                                        out_h <= out_h + 1;
                                        accumulator <= $signed(bias_mem[out_ch]);
                                    end
                                end else begin
                                    out_w <= out_w + 1;
                                    accumulator <= $signed(bias_mem[out_ch]);
                                end
                            end else begin
                                in_ch <= in_ch + 1;
                            end
                        end else begin
                            k_h <= k_h + 1;
                        end
                    end else begin
                        k_w <= k_w + 1;
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