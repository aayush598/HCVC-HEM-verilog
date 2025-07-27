module leaky_relu_array #(
    parameter DATA_WIDTH = 32,
    parameter BATCH_SIZE = 1,
    parameter CHANNELS = 1,
    parameter HEIGHT = 4,
    parameter WIDTH = 4
)(
    input clk,
    input rst,
    input  [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] in_tensor,
    output [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] out_tensor
);

    genvar b, c, h, w;
    generate
        for (b = 0; b < BATCH_SIZE; b = b + 1) begin : batch_loop
            for (c = 0; c < CHANNELS; c = c + 1) begin : channel_loop
                for (h = 0; h < HEIGHT; h = h + 1) begin : height_loop
                    for (w = 0; w < WIDTH; w = w + 1) begin : width_loop
                        localparam INDEX = (((b*CHANNELS + c)*HEIGHT + h)*WIDTH + w)*DATA_WIDTH;

                        leaky_relu #(
                            .DATA_WIDTH(DATA_WIDTH),
                            .FRAC_WIDTH(8)
                        ) leaky_relu_inst (
                            .clk(clk),
                            .rst_n(!rst),
                            .x_in(in_tensor[INDEX +: DATA_WIDTH]),
                            .valid_in(1'b1),  // Always valid for simplicity
                            .y_out(out_tensor[INDEX +: DATA_WIDTH]),
                            .valid_out()
                        );
                    end
                end
            end
        end
    endgenerate

endmodule
