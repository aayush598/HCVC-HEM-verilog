`timescale 1ns / 1ps

module sigmoid_tb;

    reg [7:0] in;
    wire [15:0] out;

    // Instantiate the sigmoid module
    sigmoid uut (
        .in(in),
        .out(out)
    );

    integer i;

    initial begin
        $display("Input Index | Sigmoid Output (Hex) | Sigmoid Output (Float)");
        for (i = 0; i < 256; i = i + 16) begin
            in = i;
            #10;
            $display("%3d         | %h                | %f", i, out, $itor(out)/4096.0);
        end
        $finish;
    end

endmodule
