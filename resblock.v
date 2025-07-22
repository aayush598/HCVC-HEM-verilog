    module resblock #(
        parameter DATA_WIDTH = 32,
        parameter BATCH_SIZE = 1,
        parameter CHANNELS = 32,
        parameter HEIGHT = 4,
        parameter WIDTH = 4,
        parameter KERNEL_SIZE = 3,
        parameter STRIDE = 1,
        parameter PADDING = 1,
        parameter SLOPE_SMALL = 1'b0,  // 1 if slope < 0.0001 (use ReLU), 0 for LeakyReLU
        parameter START_FROM_RELU = 1'b1,
        parameter END_WITH_RELU = 1'b0,
        parameter BOTTLENECK = 1'b0
    ) (
        input clk,
        input rst,
        input  [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_in,
        input  [CONV1_OUT_CHANNELS*CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights1,
        input  [CONV1_OUT_CHANNELS*DATA_WIDTH-1:0] bias1,
        input  [CHANNELS*CONV2_IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights2,
        input  [CHANNELS*DATA_WIDTH-1:0] bias2,
        output [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_out
    );


        // Internal parameters for bottleneck
        localparam CONV1_OUT_CHANNELS = BOTTLENECK ? CHANNELS/2 : CHANNELS;
        localparam CONV2_IN_CHANNELS = BOTTLENECK ? CHANNELS/2 : CHANNELS;
        
        // Internal wires for data flow
        wire [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] first_layer_out;
        wire [BATCH_SIZE*CONV1_OUT_CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] conv1_out;
        wire [BATCH_SIZE*CONV1_OUT_CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] relu1_out;
        wire [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] conv2_out;
        wire [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] last_layer_out;
        
        // Residual addition
        reg [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] residual_sum;
        
        // First layer (ReLU or Identity based on START_FROM_RELU)
        generate
            if (START_FROM_RELU == 1'b1) begin : first_relu_gen
                if (SLOPE_SMALL == 1'b1) begin : first_relu_small
                    // Use ReLU for small slope
                    relu_binary_clk_array #(
                        .DATA_WIDTH(DATA_WIDTH),
                        .BATCH_SIZE(BATCH_SIZE),
                        .CHANNELS(CHANNELS),
                        .HEIGHT(HEIGHT),
                        .WIDTH(WIDTH)
                    ) first_relu_inst (
                        .clk(clk),
                        .reset(rst),
                        .in_tensor(x_in),
                        .out_tensor(first_layer_out)
                    );
                end else begin : first_leaky_relu
                    // Use LeakyReLU
                    leaky_relu_array #(
                        .DATA_WIDTH(DATA_WIDTH),
                        .BATCH_SIZE(BATCH_SIZE),
                        .CHANNELS(CHANNELS),
                        .HEIGHT(HEIGHT),
                        .WIDTH(WIDTH)
                    ) first_leaky_relu_inst (
                        .clk(clk),
                        .rst(rst),
                        .in_tensor(x_in),
                        .out_tensor(first_layer_out)
                    );
                end
            end else begin : first_identity
                // Identity layer
                identity #(
                    .WIDTH(BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH)
                ) first_identity_inst (
                    .in(x_in),
                    .out(first_layer_out)
                );
            end
        endgenerate
        
        // First Conv2D layer
        conv2d #(
            .BATCH_SIZE(BATCH_SIZE),
            .IN_CHANNELS(CHANNELS),
            .OUT_CHANNELS(CONV1_OUT_CHANNELS),
            .IN_HEIGHT(HEIGHT),
            .IN_WIDTH(WIDTH),
            .KERNEL_SIZE(KERNEL_SIZE),
            .STRIDE(STRIDE),
            .PADDING(PADDING),
            .DATA_WIDTH(DATA_WIDTH)
        ) conv1_inst (
            .clk(clk),
            .rst(rst),
            .input_tensor_flat(first_layer_out),
            .weights_flat(weights1), // Placeholder weights
            .bias_flat(bias1), // Placeholder bias
            .output_tensor_flat(conv1_out)
        );
        
        // Middle ReLU/LeakyReLU (always present)
        generate
            if (SLOPE_SMALL == 1'b1) begin : middle_relu_small
                relu_binary_clk_array #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .BATCH_SIZE(BATCH_SIZE),
                    .CHANNELS(CONV1_OUT_CHANNELS),
                    .HEIGHT(HEIGHT),
                    .WIDTH(WIDTH)
                ) middle_relu_inst (
                    .clk(clk),
                    .reset(rst),
                    .in_tensor(conv1_out),
                    .out_tensor(relu1_out)
                );
            end else begin : middle_leaky_relu
                leaky_relu_array #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .BATCH_SIZE(BATCH_SIZE),
                    .CHANNELS(CONV1_OUT_CHANNELS),
                    .HEIGHT(HEIGHT),
                    .WIDTH(WIDTH)
                ) middle_leaky_relu_inst (
                    .clk(clk),
                    .rst(rst),
                    .in_tensor(conv1_out),
                    .out_tensor(relu1_out)
                );
            end
        endgenerate
        
        // Second Conv2D layer
        conv2d #(
            .BATCH_SIZE(BATCH_SIZE),
            .IN_CHANNELS(CONV2_IN_CHANNELS),
            .OUT_CHANNELS(CHANNELS),
            .IN_HEIGHT(HEIGHT),
            .IN_WIDTH(WIDTH),
            .KERNEL_SIZE(KERNEL_SIZE),
            .STRIDE(STRIDE),
            .PADDING(PADDING),
            .DATA_WIDTH(DATA_WIDTH)
        ) conv2_inst (
            .clk(clk),
            .rst(rst),
            .input_tensor_flat(relu1_out),
            .weights_flat(weights2), // Placeholder weights
            .bias_flat(bias2), // Placeholder bias
            .output_tensor_flat(conv2_out)
        );
        
        // Last layer (ReLU or Identity based on END_WITH_RELU)
        generate
            if (END_WITH_RELU == 1'b1) begin : last_relu_gen
                if (SLOPE_SMALL == 1'b1) begin : last_relu_small
                    relu_binary_clk_array #(
                        .DATA_WIDTH(DATA_WIDTH),
                        .BATCH_SIZE(BATCH_SIZE),
                        .CHANNELS(CHANNELS),
                        .HEIGHT(HEIGHT),
                        .WIDTH(WIDTH)
                    ) last_relu_inst (
                        .clk(clk),
                        .reset(rst),
                        .in_tensor(conv2_out),
                        .out_tensor(last_layer_out)
                    );
                end else begin : last_leaky_relu
                    leaky_relu_array #(
                        .DATA_WIDTH(DATA_WIDTH),
                        .BATCH_SIZE(BATCH_SIZE),
                        .CHANNELS(CHANNELS),
                        .HEIGHT(HEIGHT),
                        .WIDTH(WIDTH)
                    ) last_leaky_relu_inst (
                        .clk(clk),
                        .rst(rst),
                        .in_tensor(conv2_out),
                        .out_tensor(last_layer_out)
                    );
                end
            end else begin : last_identity
                identity #(
                    .WIDTH(BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH)
                ) last_identity_inst (
                    .in(conv2_out),
                    .out(last_layer_out)
                );
            end
        endgenerate
        
        // Residual addition: x + out
        integer i;
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                residual_sum <= {(BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH){1'b0}};
            end else begin
                for (i = 0; i < BATCH_SIZE*CHANNELS*HEIGHT*WIDTH; i = i + 1) begin
                    residual_sum[i*DATA_WIDTH +: DATA_WIDTH] <= 
                        x_in[i*DATA_WIDTH +: DATA_WIDTH] + 
                        last_layer_out[i*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
        
        assign x_out = residual_sum;

    endmodule
