
// Helper module: ReLU array wrapper for relu_binary_clk
module relu_binary_clk_array #(
    parameter DATA_WIDTH = 32,
    parameter BATCH_SIZE = 1,
    parameter CHANNELS = 1,
    parameter HEIGHT = 4,
    parameter WIDTH = 4
)(
    input clk,
    input reset,
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

                        relu_binary_clk relu_inst (
                            .clk(clk),
                            .reset(reset),
                            .in_data(in_tensor[INDEX +: 8]),  // Using 8-bit from original module
                            .out_data(out_tensor[INDEX +: 8])
                        );
                        
                        // For DATA_WIDTH > 8, replicate or extend as needed
                        if (DATA_WIDTH > 8) begin
                            assign out_tensor[INDEX+8 +: (DATA_WIDTH-8)] = {(DATA_WIDTH-8){1'b0}};
                        end
                    end
                end
            end
        end
    endgenerate

endmodule