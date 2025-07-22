module pixel_shuffle (
    input clk,
    input rst,
    input start,
    input  [127:0] in_data_flat,
    output reg done,
    output reg [127:0] out_data_flat
);

    reg [7:0] in_data [0:15];
    reg [7:0] out_data [0:15];
    integer i, h, w;

    // Unflatten input data at every clock
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 0;
        end else if (start) begin
            // Step 1: Unpack flat input into array
            for (i = 0; i < 16; i = i + 1) begin
                in_data[i] = in_data_flat[i*8 +: 8];
            end

            // Step 2: Pixel shuffle for r = 2
            for (h = 0; h < 2; h = h + 1) begin
                for (w = 0; w < 2; w = w + 1) begin
                    out_data[(h*2 + 0)*4 + (w*2 + 0)] = in_data[0*4 + h*2 + w]; // channel 0
                    out_data[(h*2 + 0)*4 + (w*2 + 1)] = in_data[1*4 + h*2 + w]; // channel 1
                    out_data[(h*2 + 1)*4 + (w*2 + 0)] = in_data[2*4 + h*2 + w]; // channel 2
                    out_data[(h*2 + 1)*4 + (w*2 + 1)] = in_data[3*4 + h*2 + w]; // channel 3
                end
            end

            // Step 3: Pack output array into flat
            out_data_flat = 128'd0;
            for (i = 0; i < 16; i = i + 1) begin
                out_data_flat[i*8 +: 8] = out_data[i];
            end

            done <= 1;
        end
    end

endmodule
