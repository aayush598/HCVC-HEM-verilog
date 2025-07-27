`timescale 1ns/1ps

module tb_pixel_shuffle;

    // Parameters for reconfigurable test
    parameter C = 1;
    parameter R = 2;
    parameter H = 2;
    parameter W = 2;
    parameter DATA_WIDTH = 8;

    localparam IN_CHANNELS = C * R * R;
    localparam IN_PIXELS   = IN_CHANNELS * H * W;
    localparam OUT_PIXELS  = C * (H * R) * (W * R);

    reg clk, rst, start;
    reg  [IN_PIXELS*DATA_WIDTH-1:0] in_data_flat;
    wire [OUT_PIXELS*DATA_WIDTH-1:0] out_data_flat;
    wire done;

    reg [DATA_WIDTH-1:0] out_data [0:OUT_PIXELS-1];
    integer i;

    pixel_shuffle #(
        .C(C),
        .R(R),
        .H(H),
        .W(W),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .in_data_flat(in_data_flat),
        .done(done),
        .out_data_flat(out_data_flat)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        #10 rst = 0;

        // Fill in_data_flat with 1 to 16 for a 4-channel 2x2
        in_data_flat = {
            8'd16, 8'd15, 8'd14, 8'd13, // channel 3
            8'd12, 8'd11, 8'd10, 8'd9,  // channel 2
            8'd8,  8'd7,  8'd6,  8'd5,  // channel 1
            8'd4,  8'd3,  8'd2,  8'd1   // channel 0
        };

        #10 start = 1;
        #10 start = 0;

        wait(done);
        #10;

        for (i = 0; i < OUT_PIXELS; i = i + 1)
            out_data[i] = out_data_flat[i*DATA_WIDTH +: DATA_WIDTH];

        $display("===== Output (H*R x W*R = %0d x %0d) =====", H*R, W*R);
        for (i = 0; i < OUT_PIXELS; i = i + 1) begin
            $write("%0d\t", out_data[i]);
            if ((i + 1) % (W * R) == 0) $write("\n");
        end

        $finish;
    end

endmodule
