`timescale 1ns/1ps

module avg_pool2d_tb;

    reg clk;
    reg rst;
    reg [127:0] data_in_flat;
    wire [31:0] data_out_flat;

    avg_pool2d uut (
        .clk(clk),
        .rst(rst),
        .data_in_flat(data_in_flat),
        .data_out_flat(data_out_flat)
    );

    integer i;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1;
        #10;
        rst = 0;

        // Input 4x4 matrix (flattened row-wise):
        // [  4   8  12  16 ]
        // [ 20  24  28  32 ]
        // [ 36  40  44  48 ]
        // [ 52  56  60  64 ]
        data_in_flat = {
            8'd4, 8'd8, 8'd12, 8'd16,
            8'd20, 8'd24, 8'd28, 8'd32,
            8'd36, 8'd40, 8'd44, 8'd48,
            8'd52, 8'd56, 8'd60, 8'd64
        };

        #20;

        $display("AvgPool2D Output:");
        $display("data_out[0] = %d", data_out_flat[31:24]);
        $display("data_out[1] = %d", data_out_flat[23:16]);
        $display("data_out[2] = %d", data_out_flat[15:8]);
        $display("data_out[3] = %d", data_out_flat[7:0]);

        $finish;
    end

endmodule
