module conv3x3 #(
    parameter BATCH_SIZE   = 1,
    parameter IN_CHANNELS  = 2,
    parameter OUT_CHANNELS = 1,
    parameter IN_HEIGHT    = 4,
    parameter IN_WIDTH     = 4,
    parameter DATA_WIDTH   = 32
)(
    input clk,
    input rst,
    input  [BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat,
    input  [OUT_CHANNELS*IN_CHANNELS*3*3*DATA_WIDTH-1:0] weights_flat,
    input  [OUT_CHANNELS*DATA_WIDTH-1:0] bias_flat,
    output [BATCH_SIZE*OUT_CHANNELS*((IN_HEIGHT+2-3)/1+1)*((IN_WIDTH+2-3)/1+1)*DATA_WIDTH-1:0] output_tensor_flat
);

    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
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
        .weights_flat(weights_flat),
        .bias_flat(bias_flat),
        .output_tensor_flat(output_tensor_flat)
    );

endmodule
