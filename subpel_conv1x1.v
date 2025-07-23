module subpel_conv1x1_top #(
    parameter IN_CHANNELS = 1,
    parameter OUT_CHANNELS = 1,
    parameter UPSCALE = 2,
    parameter H = 2,
    parameter W = 2,
    parameter DATA_WIDTH = 8
)(
    input clk,
    input rst,
    input start,
    input [IN_CHANNELS*H*W*DATA_WIDTH-1:0] input_tensor_flat,
    input [(OUT_CHANNELS*UPSCALE*UPSCALE)*IN_CHANNELS*1*1*DATA_WIDTH-1:0] weights_flat,
    input [(OUT_CHANNELS*UPSCALE*UPSCALE)*DATA_WIDTH-1:0] bias_flat,
    output done,
    output [(OUT_CHANNELS*(H*UPSCALE)*(W*UPSCALE)*DATA_WIDTH)-1:0] output_tensor_flat
);

    // Intermediate wire to connect conv2d and pixel_shuffle
    wire [(OUT_CHANNELS*UPSCALE*UPSCALE)*H*W*DATA_WIDTH-1:0] conv2d_out;

    // conv2d module with kernel 1x1, stride 1, padding 0
    conv2d #(
        .BATCH_SIZE(1),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS * UPSCALE * UPSCALE),
        .IN_HEIGHT(H),
        .IN_WIDTH(W),
        .KERNEL_SIZE(1),
        .STRIDE(1),
        .PADDING(0),
        .DATA_WIDTH(DATA_WIDTH)
    ) conv_inst (
        .clk(clk),
        .rst(rst),
        .input_tensor_flat(input_tensor_flat),
        .weights_flat(weights_flat),
        .bias_flat(bias_flat),
        .output_tensor_flat(conv2d_out)
    );

    // Pixel shuffle module
    pixel_shuffle #(
        .C(OUT_CHANNELS),
        .R(UPSCALE),
        .H(H),
        .W(W),
        .DATA_WIDTH(DATA_WIDTH)
    ) ps_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .in_data_flat(conv2d_out),
        .done(done),
        .out_data_flat(output_tensor_flat)
    );

endmodule
