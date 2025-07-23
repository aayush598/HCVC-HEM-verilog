module contextual_encoder #(
    parameter DATA_WIDTH = 32,
    parameter BATCH_SIZE = 1,
    parameter CHANNEL_N = 64,
    parameter CHANNEL_M = 96,
    parameter HEIGHT = 32,      // Initial height
    parameter WIDTH = 32,       // Initial width
    parameter KERNEL_SIZE = 3,
    parameter STRIDE = 2,
    parameter PADDING = 1
)(
    input clk,
    input rst,
    // Input tensors
    input  [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*DATA_WIDTH-1:0] x,
    input  [BATCH_SIZE*3*HEIGHT*WIDTH*DATA_WIDTH-1:0] context1,
    input  [BATCH_SIZE*CHANNEL_N*HEIGHT/2*WIDTH/2*DATA_WIDTH-1:0] context2,
    input  [BATCH_SIZE*CHANNEL_N*HEIGHT/4*WIDTH/4*DATA_WIDTH-1:0] context3,
    // Weight and bias inputs for conv layers
    input  [CHANNEL_N*(CHANNEL_N+3)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv1_weights,
    input  [CHANNEL_N*DATA_WIDTH-1:0] conv1_bias,
    input  [(CHANNEL_N*2)*CHANNEL_N*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv2_weights,
    input  [CHANNEL_N*DATA_WIDTH-1:0] conv2_bias,
    input  [CHANNEL_N*(CHANNEL_N*2)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv3_weights,
    input  [CHANNEL_N*DATA_WIDTH-1:0] conv3_bias,
    input  [CHANNEL_M*CHANNEL_N*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv4_weights,
    input  [CHANNEL_M*DATA_WIDTH-1:0] conv4_bias,
    // Weight and bias inputs for ResBlocks
    input  [(CHANNEL_N)*CHANNEL_N*2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res1_weights1,
    input  [(CHANNEL_N)*DATA_WIDTH-1:0] res1_bias1,
    input  [CHANNEL_N*2*(CHANNEL_N)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res1_weights2,
    input  [CHANNEL_N*2*DATA_WIDTH-1:0] res1_bias2,
    input  [(CHANNEL_N)*CHANNEL_N*2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res2_weights1,
    input  [(CHANNEL_N)*DATA_WIDTH-1:0] res2_bias1,
    input  [CHANNEL_N*2*(CHANNEL_N)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res2_weights2,
    input  [CHANNEL_N*2*DATA_WIDTH-1:0] res2_bias2,
    // Output
    output [BATCH_SIZE*CHANNEL_M*HEIGHT/16*WIDTH/16*DATA_WIDTH-1:0] feature_out
);

    // Internal dimensions after each layer
    localparam HEIGHT_2 = HEIGHT/2;
    localparam WIDTH_2 = WIDTH/2;
    localparam HEIGHT_4 = HEIGHT/4;
    localparam WIDTH_4 = WIDTH/4;
    localparam HEIGHT_8 = HEIGHT/8;
    localparam WIDTH_8 = WIDTH/8;
    localparam HEIGHT_16 = HEIGHT/16;
    localparam WIDTH_16 = WIDTH/16;

    // Internal wire declarations
    wire [BATCH_SIZE*(CHANNEL_N+3)*HEIGHT*WIDTH*DATA_WIDTH-1:0] concat1_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT_2*WIDTH_2*DATA_WIDTH-1:0] conv1_out;
    wire [BATCH_SIZE*(CHANNEL_N*2)*HEIGHT_2*WIDTH_2*DATA_WIDTH-1:0] concat2_out;
    wire [BATCH_SIZE*(CHANNEL_N*2)*HEIGHT_2*WIDTH_2*DATA_WIDTH-1:0] res1_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT_4*WIDTH_4*DATA_WIDTH-1:0] conv2_out;
    wire [BATCH_SIZE*(CHANNEL_N*2)*HEIGHT_4*WIDTH_4*DATA_WIDTH-1:0] concat3_out;
    wire [BATCH_SIZE*(CHANNEL_N*2)*HEIGHT_4*WIDTH_4*DATA_WIDTH-1:0] res2_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT_8*WIDTH_8*DATA_WIDTH-1:0] conv3_out;

    // First concatenation: cat([x, context1], dim=1)
    concat #(
        .FEATURE_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*DATA_WIDTH),
        .CONTEXT_WIDTH(BATCH_SIZE*3*HEIGHT*WIDTH*DATA_WIDTH)
    ) concat1_inst (
        .feature(x),
        .context2(context1),
        .concat_out(concat1_out)
    );

    // First convolution: conv1
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_N+3),
        .OUT_CHANNELS(CHANNEL_N),
        .IN_HEIGHT(HEIGHT),
        .IN_WIDTH(WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH)
    ) conv1_inst (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(concat1_out),
        .weights_flat(conv1_weights),
        .bias_flat(conv1_bias),
        .output_tensor_flat(conv1_out)
    );

    // Second concatenation: cat([feature, context2], dim=1)
    concat #(
        .FEATURE_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT_2*WIDTH_2*DATA_WIDTH),
        .CONTEXT_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT_2*WIDTH_2*DATA_WIDTH)
    ) concat2_inst (
        .feature(conv1_out),
        .context2(context2),
        .concat_out(concat2_out)
    );

    // First ResBlock: res1
    resblock #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNELS(CHANNEL_N*2),
        .HEIGHT(HEIGHT_2),
        .WIDTH(WIDTH_2),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(1),
        .PADDING(PADDING),
        .SLOPE_SMALL(1'b0),  // slope=0.1, so use LeakyReLU
        .START_FROM_RELU(1'b1),
        .END_WITH_RELU(1'b1),
        .BOTTLENECK(1'b1)
    ) res1_inst (
        .clk(clk),
        .rst(rst),
        .x_in(concat2_out),
        .weights1(res1_weights1),
        .bias1(res1_bias1),
        .weights2(res1_weights2),
        .bias2(res1_bias2),
        .x_out(res1_out)
    );

    // Second convolution: conv2
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_N*2),
        .OUT_CHANNELS(CHANNEL_N),
        .IN_HEIGHT(HEIGHT_2),
        .IN_WIDTH(WIDTH_2),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH)
    ) conv2_inst (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(res1_out),
        .weights_flat(conv2_weights),
        .bias_flat(conv2_bias),
        .output_tensor_flat(conv2_out)
    );

    // Third concatenation: cat([feature, context3], dim=1)
    concat #(
        .FEATURE_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT_4*WIDTH_4*DATA_WIDTH),
        .CONTEXT_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT_4*WIDTH_4*DATA_WIDTH)
    ) concat3_inst (
        .feature(conv2_out),
        .context2(context3),
        .concat_out(concat3_out)
    );

    // Second ResBlock: res2
    resblock #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNELS(CHANNEL_N*2),
        .HEIGHT(HEIGHT_4),
        .WIDTH(WIDTH_4),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(1),
        .PADDING(PADDING),
        .SLOPE_SMALL(1'b0),  // slope=0.1, so use LeakyReLU
        .START_FROM_RELU(1'b1),
        .END_WITH_RELU(1'b1),
        .BOTTLENECK(1'b1)
    ) res2_inst (
        .clk(clk),
        .rst(rst),
        .x_in(concat3_out),
        .weights1(res2_weights1),
        .bias1(res2_bias1),
        .weights2(res2_weights2),
        .bias2(res2_bias2),
        .x_out(res2_out)
    );

    // Third convolution: conv3
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_N*2),
        .OUT_CHANNELS(CHANNEL_N),
        .IN_HEIGHT(HEIGHT_4),
        .IN_WIDTH(WIDTH_4),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH)
    ) conv3_inst (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(res2_out),
        .weights_flat(conv3_weights),
        .bias_flat(conv3_bias),
        .output_tensor_flat(conv3_out)
    );

    // Fourth convolution: conv4
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_N),
        .OUT_CHANNELS(CHANNEL_M),
        .IN_HEIGHT(HEIGHT_8),
        .IN_WIDTH(WIDTH_8),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH)
    ) conv4_inst (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(conv3_out),
        .weights_flat(conv4_weights),
        .bias_flat(conv4_bias),
        .output_tensor_flat(feature_out)
    );

endmodule