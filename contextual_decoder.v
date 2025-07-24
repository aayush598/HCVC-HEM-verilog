module contextual_decoder #(
    parameter DATA_WIDTH = 32,
    parameter BATCH_SIZE = 1,
    parameter HEIGHT = 4,
    parameter WIDTH = 4,
    parameter CHANNEL_N = 64,
    parameter CHANNEL_M = 96
)(
    input clk,
    input rst,
    input start,
    input  [BATCH_SIZE*CHANNEL_M*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_in,
    input  [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*4*DATA_WIDTH-1:0] context2,
    input  [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*2*DATA_WIDTH-1:0] context3,
    
    // Weight and bias inputs for all conv layers
    input  [CHANNEL_N*4*CHANNEL_M*3*3*DATA_WIDTH-1:0] up1_weights,
    input  [CHANNEL_N*4*DATA_WIDTH-1:0] up1_bias,
    input  [CHANNEL_N*4*CHANNEL_N*3*3*DATA_WIDTH-1:0] up2_weights,
    input  [CHANNEL_N*4*DATA_WIDTH-1:0] up2_bias,
    input  [CHANNEL_N*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] res1_weights1,
    input  [CHANNEL_N*DATA_WIDTH-1:0] res1_bias1,
    input  [CHANNEL_N*2*CHANNEL_N*3*3*DATA_WIDTH-1:0] res1_weights2,
    input  [CHANNEL_N*2*DATA_WIDTH-1:0] res1_bias2,
    input  [CHANNEL_N*4*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] up3_weights,
    input  [CHANNEL_N*4*DATA_WIDTH-1:0] up3_bias,
    input  [CHANNEL_N*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] res2_weights1,
    input  [CHANNEL_N*DATA_WIDTH-1:0] res2_bias1,
    input  [CHANNEL_N*2*CHANNEL_N*3*3*DATA_WIDTH-1:0] res2_weights2,
    input  [CHANNEL_N*2*DATA_WIDTH-1:0] res2_bias2,
    input  [128*CHANNEL_N*2*3*3*DATA_WIDTH-1:0] up4_weights,
    input  [128*DATA_WIDTH-1:0] up4_bias,
    
    output reg done,
    output [BATCH_SIZE*32*HEIGHT*WIDTH*16*DATA_WIDTH-1:0] feature_out
);

    // Internal wires for data flow
    wire [BATCH_SIZE*CHANNEL_N*4*HEIGHT*WIDTH*DATA_WIDTH-1:0] up1_conv_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*4*DATA_WIDTH-1:0] up1_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*16*DATA_WIDTH-1:0] up2_conv_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*16*DATA_WIDTH-1:0] up2_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*32*DATA_WIDTH - 1:0] concat1_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*32*DATA_WIDTH - 1:0] res1_out;
    wire [BATCH_SIZE*CHANNEL_N*4*HEIGHT*WIDTH*4*DATA_WIDTH-1:0] up3_conv_out;
    wire [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*8*DATA_WIDTH-1:0] up3_out;
    wire [BATCH_SIZE*CHANNEL_N*2*HEIGHT*WIDTH*8*DATA_WIDTH-1:0] concat2_out;
    wire [BATCH_SIZE*CHANNEL_N*2*HEIGHT*WIDTH*8*DATA_WIDTH-1:0] res2_out;
    wire [BATCH_SIZE*128*HEIGHT*WIDTH*8*DATA_WIDTH-1:0] up4_conv_out;
    
    wire up1_ps_done, up2_ps_done, up3_ps_done, up4_ps_done;
    
    // UP1: Conv2D + PixelShuffle (M->N*4, then shuffle to N with 2x upscale)
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_M),
        .OUT_CHANNELS(CHANNEL_N*4),
        .IN_HEIGHT(HEIGHT),
        .IN_WIDTH(WIDTH),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .DATA_WIDTH(DATA_WIDTH)
    ) up1_conv (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(x_in),
        .weights_flat(up1_weights),
        .bias_flat(up1_bias),
        .output_tensor_flat(up1_conv_out)
    );
    
    pixel_shuffle #(
        .C(CHANNEL_N),
        .R(2),
        .H(HEIGHT),
        .W(WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) up1_ps (
        .clk(clk),
        .rst(rst),
        .start(start),
        .in_data_flat(up1_conv_out),
        .done(up1_ps_done),
        .out_data_flat(up1_out)
    );
    
    // UP2: Conv2D + PixelShuffle (N->N*4, then shuffle to N with 2x upscale)
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_N),
        .OUT_CHANNELS(CHANNEL_N*4),
        .IN_HEIGHT(HEIGHT*2),
        .IN_WIDTH(WIDTH*2),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .DATA_WIDTH(DATA_WIDTH)
    ) up2_conv (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(up1_out),
        .weights_flat(up2_weights),
        .bias_flat(up2_bias),
        .output_tensor_flat(up2_conv_out)
    );
    
    pixel_shuffle #(
        .C(CHANNEL_N),
        .R(2),
        .H(HEIGHT*2),
        .W(WIDTH*2),
        .DATA_WIDTH(DATA_WIDTH)
    ) up2_ps (
        .clk(clk),
        .rst(rst),
        .start(up1_ps_done),
        .in_data_flat(up2_conv_out),
        .done(up2_ps_done),
        .out_data_flat(up2_out)
    );
    
    // CONCAT1: Concatenate up2_out with context3
    concat #(
        .FEATURE_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*16*DATA_WIDTH),
        .CONTEXT_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*2*DATA_WIDTH)
    ) concat1 (
        .feature(up2_out),
        .context2(context3),
        .concat_out(concat1_out)
    );
    
    // RES1: ResBlock with bottleneck
    resblock #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNELS(CHANNEL_N*2),
        .HEIGHT(HEIGHT*4),
        .WIDTH(WIDTH*4),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .SLOPE_SMALL(1'b0),
        .START_FROM_RELU(1'b1),
        .END_WITH_RELU(1'b1),
        .BOTTLENECK(1'b1)
    ) res1 (
        .clk(clk),
        .rst(rst),
        .x_in(concat1_out),
        .weights1(res1_weights1),
        .bias1(res1_bias1),
        .weights2(res1_weights2),
        .bias2(res1_bias2),
        .x_out(res1_out)
    );
    
    // UP3: Conv2D + PixelShuffle (N*2->N*4, then shuffle to N with 2x upscale)
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_N*2),
        .OUT_CHANNELS(CHANNEL_N*4),
        .IN_HEIGHT(HEIGHT*4),
        .IN_WIDTH(WIDTH*4),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .DATA_WIDTH(DATA_WIDTH)
    ) up3_conv (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(res1_out),
        .weights_flat(up3_weights),
        .bias_flat(up3_bias),
        .output_tensor_flat(up3_conv_out)
    );
    
    pixel_shuffle #(
        .C(CHANNEL_N),
        .R(2),
        .H(HEIGHT*4),
        .W(WIDTH*4),
        .DATA_WIDTH(DATA_WIDTH)
    ) up3_ps (
        .clk(clk),
        .rst(rst),
        .start(up2_ps_done),
        .in_data_flat(up3_conv_out),
        .done(up3_ps_done),
        .out_data_flat(up3_out)
    );
    
    // CONCAT2: Concatenate up3_out with context2
    concat #(
        .FEATURE_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*8*DATA_WIDTH),
        .CONTEXT_WIDTH(BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*4*DATA_WIDTH)
    ) concat2 (
        .feature(up3_out),
        .context2(context2),
        .concat_out(concat2_out)
    );
    
    // RES2: ResBlock with bottleneck
    resblock #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNELS(CHANNEL_N*2),
        .HEIGHT(HEIGHT*8),
        .WIDTH(WIDTH*8),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .SLOPE_SMALL(1'b0),
        .START_FROM_RELU(1'b1),
        .END_WITH_RELU(1'b1),
        .BOTTLENECK(1'b1)
    ) res2 (
        .clk(clk),
        .rst(rst),
        .x_in(concat2_out),
        .weights1(res2_weights1),
        .bias1(res2_bias1),
        .weights2(res2_weights2),
        .bias2(res2_bias2),
        .x_out(res2_out)
    );
    
    // UP4: Conv2D + PixelShuffle (N*2->128, then shuffle to 32 with 2x upscale)
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNEL_N*2),
        .OUT_CHANNELS(128),
        .IN_HEIGHT(HEIGHT*8),
        .IN_WIDTH(WIDTH*8),
        .KERNEL_SIZE(3),
        .STRIDE(1),
        .PADDING(1),
        .DATA_WIDTH(DATA_WIDTH)
    ) up4_conv (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(res2_out),
        .weights_flat(up4_weights),
        .bias_flat(up4_bias),
        .output_tensor_flat(up4_conv_out)
    );
    
    pixel_shuffle #(
        .C(32),
        .R(2),
        .H(HEIGHT*8),
        .W(WIDTH*8),
        .DATA_WIDTH(DATA_WIDTH)
    ) up4_ps (
        .clk(clk),
        .rst(rst),
        .start(up3_ps_done),
        .in_data_flat(up4_conv_out),
        .done(up4_ps_done),
        .out_data_flat(feature_out)
    );
    
    // Done signal
    always @(posedge clk or posedge rst) begin
        if (rst)
            done <= 1'b0;
        else
            done <= up4_ps_done;
    end

endmodule
