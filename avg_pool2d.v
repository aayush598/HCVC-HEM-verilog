module avg_pool2d (
    input clk,
    input rst,
    input [127:0] data_in_flat,      // 16 * 8 bits = 4x4
    output wire [31:0] data_out_flat  // 4 * 8 bits = 2x2
);

    wire [7:0] data_in [0:15];

    assign data_in[0]  = data_in_flat[127:120];
    assign data_in[1]  = data_in_flat[119:112];
    assign data_in[2]  = data_in_flat[111:104];
    assign data_in[3]  = data_in_flat[103:96];
    assign data_in[4]  = data_in_flat[95:88];
    assign data_in[5]  = data_in_flat[87:80];
    assign data_in[6]  = data_in_flat[79:72];
    assign data_in[7]  = data_in_flat[71:64];
    assign data_in[8]  = data_in_flat[63:56];
    assign data_in[9]  = data_in_flat[55:48];
    assign data_in[10] = data_in_flat[47:40];
    assign data_in[11] = data_in_flat[39:32];
    assign data_in[12] = data_in_flat[31:24];
    assign data_in[13] = data_in_flat[23:16];
    assign data_in[14] = data_in_flat[15:8];
    assign data_in[15] = data_in_flat[7:0];

    reg [7:0] data_out [0:3];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out[0] <= 0;
            data_out[1] <= 0;
            data_out[2] <= 0;
            data_out[3] <= 0;
        end else begin
            data_out[0] <= (data_in[0] + data_in[1] + data_in[4] + data_in[5]) >> 2;
            data_out[1] <= (data_in[2] + data_in[3] + data_in[6] + data_in[7]) >> 2;
            data_out[2] <= (data_in[8] + data_in[9] + data_in[12] + data_in[13]) >> 2;
            data_out[3] <= (data_in[10] + data_in[11] + data_in[14] + data_in[15]) >> 2;
        end
    end

    assign data_out_flat = {data_out[0], data_out[1], data_out[2], data_out[3]};

endmodule
