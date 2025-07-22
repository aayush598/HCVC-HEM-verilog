`timescale 1ns/1ps

module tb_pixel_shuffle;

    reg clk, rst, start;
    wire done;
    reg  [127:0] in_data_flat;
    wire [127:0] out_data_flat;

    integer i;
    reg [7:0] out_data[0:15];

    // Instantiate DUT
    pixel_shuffle uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .in_data_flat(in_data_flat),
        .done(done),
        .out_data_flat(out_data_flat)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        #10 rst = 0;

        // Initialize flat input (same order as 4 channels of 2x2)
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

        // Convert flat output to byte array for printing
        for (i = 0; i < 16; i = i + 1)
            out_data[i] = out_data_flat[i*8 +: 8];

        $display("===== Output (4x4 Image) =====");
        for (i = 0; i < 16; i = i + 1) begin
            $write("%0d\t", out_data[i]);
            if ((i+1) % 4 == 0)
                $write("\n");
        end

        $finish;
    end

endmodule
