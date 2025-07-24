module subpel_conv3x3 #(
    parameter IN_CHANNELS  = 2,
    parameter OUT_CHANNELS = 1,
    parameter IN_HEIGHT    = 4,
    parameter IN_WIDTH     = 4,
    parameter R            = 2,        // Upscale factor
    parameter DATA_WIDTH   = 16
)(
    input clk,
    input rst,
    input start,
    
    // Input tensor: [IN_CHANNELS][IN_HEIGHT][IN_WIDTH]
    input  [IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat,
    
    // Conv weights: [OUT_CHANNELS*R*R][IN_CHANNELS][3][3] 
    input  [(OUT_CHANNELS*R*R)*IN_CHANNELS*3*3*DATA_WIDTH-1:0] conv_weights_flat,
    
    // Conv bias: [OUT_CHANNELS*R*R]
    input  [(OUT_CHANNELS*R*R)*DATA_WIDTH-1:0] conv_bias_flat,
    
    output reg done,
    // Output tensor: [OUT_CHANNELS][IN_HEIGHT*R][IN_WIDTH*R]
    output reg [OUT_CHANNELS*(IN_HEIGHT*R)*(IN_WIDTH*R)*DATA_WIDTH-1:0] output_tensor_flat
);

    // Internal parameters
    localparam CONV_OUT_CHANNELS = OUT_CHANNELS * R * R;
    localparam CONV_OUT_HEIGHT = IN_HEIGHT;  // 3x3 conv with padding=1 keeps same size
    localparam CONV_OUT_WIDTH = IN_WIDTH;
    localparam FINAL_OUT_HEIGHT = IN_HEIGHT * R;
    localparam FINAL_OUT_WIDTH = IN_WIDTH * R;
    
    // State machine
    reg [1:0] state;
    localparam IDLE = 0, CONV = 1, SHUFFLE = 2, DONE = 3;
    
    // Internal signals
    reg conv_start, shuffle_start;
    wire conv_done, shuffle_done;
    
    // Conv2D outputs
    wire [CONV_OUT_CHANNELS*CONV_OUT_HEIGHT*CONV_OUT_WIDTH*DATA_WIDTH-1:0] conv_output_flat;
    
    // PixelShuffle outputs  
    wire [OUT_CHANNELS*FINAL_OUT_HEIGHT*FINAL_OUT_WIDTH*DATA_WIDTH-1:0] shuffle_output_flat;
    
    // Instantiate Conv2D module
    conv2d #(
        .BATCH_SIZE(1),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(CONV_OUT_CHANNELS),
        .IN_HEIGHT(IN_HEIGHT),
        .IN_WIDTH(IN_WIDTH),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .DATA_WIDTH(DATA_WIDTH)
    ) conv_inst (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(input_tensor_flat),
        .weights_flat(conv_weights_flat),
        .bias_flat(conv_bias_flat),
        .output_tensor_flat(conv_output_flat)
    );
    
    // Instantiate PixelShuffle module
    pixel_shuffle #(
        .C(OUT_CHANNELS),
        .R(R),
        .H(CONV_OUT_HEIGHT),
        .W(CONV_OUT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) shuffle_inst (
        .clk(clk),
        .rst(rst),
        .start(shuffle_start),
        .in_data_flat(conv_output_flat),
        .done(shuffle_done),
        .out_data_flat(shuffle_output_flat)
    );
    
    // State machine and control logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            conv_start <= 0;
            shuffle_start <= 0;
            done <= 0;
            output_tensor_flat <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CONV;
                        conv_start <= 1;
                    end
                end
                
                CONV: begin
                    conv_start <= 0;
                    // Conv2D operates continuously, wait one cycle for output
                    state <= SHUFFLE;
                    shuffle_start <= 1;
                end
                
                SHUFFLE: begin
                    shuffle_start <= 0;
                    if (shuffle_done) begin
                        state <= DONE;
                        output_tensor_flat <= shuffle_output_flat;
                        done <= 1;
                    end
                end
                
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule

// Updated Conv2D module with corrected parameter calculation
module conv2d #(
    parameter BATCH_SIZE   = 1,
    parameter IN_CHANNELS  = 2,
    parameter OUT_CHANNELS = 4,
    parameter IN_HEIGHT    = 4,
    parameter IN_WIDTH     = 4,
    parameter KERNEL_SIZE  = 3,
    parameter STRIDE       = 1,
    parameter PADDING      = 1,
    parameter DATA_WIDTH   = 16
)(
    input clk,
    input rst,
    input  [BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat,
    input  [OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_flat,
    input  [OUT_CHANNELS*DATA_WIDTH-1:0] bias_flat,
    output reg [BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH*DATA_WIDTH-1:0] output_tensor_flat
);

    localparam OUT_HEIGHT = (IN_HEIGHT + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;
    localparam OUT_WIDTH  = (IN_WIDTH  + (2 * PADDING) - KERNEL_SIZE) / STRIDE + 1;

    integer b, out_ch, in_ch, out_h, out_w, k_h, k_w;
    integer input_h, input_w;
    integer in_index, w_index, out_index;

    reg signed [DATA_WIDTH-1:0] input_val, weight_val, acc;

    // Internal unpacked memories
    reg signed [DATA_WIDTH-1:0] input_tensor  [0:BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] weights       [0:OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE-1];
    reg signed [DATA_WIDTH-1:0] bias          [0:OUT_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] output_tensor [0:BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH-1];
    
    // Unpack input, weights, bias
    always @(*) begin
        for (integer i = 0; i < BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH; i = i + 1)
            input_tensor[i] = input_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH];
        for (integer i = 0; i < OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE; i = i + 1)
            weights[i] = weights_flat[i*DATA_WIDTH +: DATA_WIDTH];
        for (integer i = 0; i < OUT_CHANNELS; i = i + 1)
            bias[i] = bias_flat[i*DATA_WIDTH +: DATA_WIDTH];
    end

    // Convolution Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (integer i = 0; i < BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH; i = i + 1)
                output_tensor[i] <= 0;
        end else begin
            for (b = 0; b < BATCH_SIZE; b = b + 1) begin
                for (out_ch = 0; out_ch < OUT_CHANNELS; out_ch = out_ch + 1) begin
                    for (out_h = 0; out_h < OUT_HEIGHT; out_h = out_h + 1) begin
                        for (out_w = 0; out_w < OUT_WIDTH; out_w = out_w + 1) begin
                            acc = bias[out_ch];
                            for (in_ch = 0; in_ch < IN_CHANNELS; in_ch = in_ch + 1) begin
                                for (k_h = 0; k_h < KERNEL_SIZE; k_h = k_h + 1) begin
                                    for (k_w = 0; k_w < KERNEL_SIZE; k_w = k_w + 1) begin
                                        input_h = out_h * STRIDE + k_h - PADDING;
                                        input_w = out_w * STRIDE + k_w - PADDING;

                                        if (input_h >= 0 && input_h < IN_HEIGHT &&
                                            input_w >= 0 && input_w < IN_WIDTH) begin
                                            in_index = b*IN_CHANNELS*IN_HEIGHT*IN_WIDTH +
                                                       in_ch*IN_HEIGHT*IN_WIDTH +
                                                       input_h*IN_WIDTH + input_w;
                                            input_val = input_tensor[in_index];
                                        end else begin
                                            input_val = 0;
                                        end

                                        w_index = out_ch*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE +
                                                  in_ch*KERNEL_SIZE*KERNEL_SIZE +
                                                  k_h*KERNEL_SIZE + k_w;
                                        weight_val = weights[w_index];

                                        acc = acc + input_val * weight_val;
                                    end
                                end
                            end
                            out_index = b*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH +
                                        out_ch*OUT_HEIGHT*OUT_WIDTH +
                                        out_h*OUT_WIDTH + out_w;
                            output_tensor[out_index] <= acc;
                        end
                    end
                end
            end
        end
    end

    // Pack output tensor to flat
    always @(*) begin
        for (integer i = 0; i < BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH; i = i + 1)
            output_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH] = output_tensor[i];
    end

endmodule

// Updated PixelShuffle module
module pixel_shuffle #(
    parameter C = 1,           // Output channels
    parameter R = 2,           // Upscale factor
    parameter H = 4,           // Input height
    parameter W = 4,           // Input width
    parameter DATA_WIDTH = 16  // Data bit width
)(
    input clk,
    input rst,
    input start,
    input  [(C*R*R*H*W*DATA_WIDTH)-1:0] in_data_flat,
    output reg done,
    output reg [(C*(H*R)*(W*R)*DATA_WIDTH)-1:0] out_data_flat
);

    localparam IN_CHANNELS = C * R * R;
    localparam IN_PIXELS   = IN_CHANNELS * H * W;
    localparam OUT_PIXELS  = C * (H * R) * (W * R);

    reg signed [DATA_WIDTH-1:0] in_data [0:IN_PIXELS-1];
    reg signed [DATA_WIDTH-1:0] out_data[0:OUT_PIXELS-1];

    integer i, c, h, w, r1, r2;

    // Unflatten input
    always @(*) begin
        for (i = 0; i < IN_PIXELS; i = i + 1) begin
            in_data[i] = in_data_flat[i*DATA_WIDTH +: DATA_WIDTH];
        end
    end

    // Main pixel shuffle logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 0;
            out_data_flat <= 0;
        end else if (start) begin
            for (c = 0; c < C; c = c + 1) begin
                for (h = 0; h < H; h = h + 1) begin
                    for (w = 0; w < W; w = w + 1) begin
                        for (r1 = 0; r1 < R; r1 = r1 + 1) begin
                            for (r2 = 0; r2 < R; r2 = r2 + 1) begin
                                // Input index
                                i = (((c*R*R + r1*R + r2)*H + h)*W + w);
                                // Output index
                                out_data[((c*(H*R) + (h*R + r1))*(W*R) + (w*R + r2))] = in_data[i];
                            end
                        end
                    end
                end
            end

            // Flatten output
            for (i = 0; i < OUT_PIXELS; i = i + 1) begin
                out_data_flat[i*DATA_WIDTH +: DATA_WIDTH] <= out_data[i];
            end

            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule