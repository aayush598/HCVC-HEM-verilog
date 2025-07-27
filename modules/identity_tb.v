`timescale 1ns / 1ps

module identity_tb;

    // Parameters
    parameter WIDTH = 8;

    // Testbench signals
    reg  [WIDTH-1:0] in;
    wire [WIDTH-1:0] out;

    // Instantiate the identity module
    identity #(.WIDTH(WIDTH)) uut (
        .in(in),
        .out(out)
    );

    initial begin
        // Monitor changes
        $monitor("Time = %0t | in = %b | out = %b", $time, in, out);

        // Apply test vectors
        in = 8'b00000000; #10;
        in = 8'b11111111; #10;
        in = 8'b10101010; #10;
        in = 8'b01010101; #10;
        in = 8'b11001100; #10;
        in = 8'b00110011; #10;

        // End simulation
        $finish;
    end

endmodule
