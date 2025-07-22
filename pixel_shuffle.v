module pixel_shuffle #(
    parameter C = 1,           // Output channels
    parameter R = 2,           // Upscale factor
    parameter H = 2,           // Input height
    parameter W = 2,           // Input width
    parameter DATA_WIDTH = 8   // Data bit width
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

    reg [DATA_WIDTH-1:0] in_data [0:IN_PIXELS-1];
    reg [DATA_WIDTH-1:0] out_data[0:OUT_PIXELS-1];

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
        end
    end

endmodule
