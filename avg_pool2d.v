module avg_pool2d #(
    parameter IN_SIZE = 4,     // Input matrix size (e.g., 4x4)
    parameter OUT_SIZE = IN_SIZE / 2, // Output matrix size (2x2 for 4x4 input)
    parameter BIT_WIDTH = 8    // Bit width per pixel
)(
    input clk,
    input rst,
    input [IN_SIZE*IN_SIZE*BIT_WIDTH-1:0] data_in_flat,
    output reg [OUT_SIZE*OUT_SIZE*BIT_WIDTH-1:0] data_out_flat
);

    // Internal array to store input pixels
    wire [BIT_WIDTH-1:0] data_in [0:IN_SIZE*IN_SIZE-1];

    genvar i;
    generate
        for (i = 0; i < IN_SIZE*IN_SIZE; i = i + 1) begin : UNPACK_INPUT
            assign data_in[i] = data_in_flat[(IN_SIZE*IN_SIZE*BIT_WIDTH-1)-(i*BIT_WIDTH) -: BIT_WIDTH];
        end
    endgenerate

    integer row, col, idx;
    reg [BIT_WIDTH-1:0] avg [0:OUT_SIZE*OUT_SIZE-1];
    reg [BIT_WIDTH+1:0] sum;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (idx = 0; idx < OUT_SIZE*OUT_SIZE; idx = idx + 1) begin
                avg[idx] <= 0;
            end
        end else begin
            idx = 0;
            for (row = 0; row < IN_SIZE; row = row + 2) begin
                for (col = 0; col < IN_SIZE; col = col + 2) begin
                    sum = data_in[row*IN_SIZE + col] +
                          data_in[row*IN_SIZE + col + 1] +
                          data_in[(row+1)*IN_SIZE + col] +
                          data_in[(row+1)*IN_SIZE + col + 1];
                    avg[idx] <= sum >> 2;
                    idx = idx + 1;
                end
            end
        end
    end

    // Pack output
    always @(*) begin
        for (idx = 0; idx < OUT_SIZE*OUT_SIZE; idx = idx + 1) begin
            data_out_flat[(OUT_SIZE*OUT_SIZE*BIT_WIDTH-1)-(idx*BIT_WIDTH) -: BIT_WIDTH] = avg[idx];
        end
    end

endmodule
