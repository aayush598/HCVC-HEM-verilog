`timescale 1ns / 1ps

module concat_tb;

    parameter WIDTH = 8;
    
    reg  [WIDTH-1:0] feature;
    reg  [WIDTH-1:0] context2;
    wire [2*WIDTH-1:0] concat_out;

    // Instantiate the module
    concat #(WIDTH) uut (
        .feature(feature),
        .context2(context2),
        .concat_out(concat_out)
    );

    initial begin
        $display("Time\tfeature\t\tcontext2\tconcat_out");
        $monitor("%0t\t%b\t%b\t%b", $time, feature, context2, concat_out);

        // Test case 1
        feature  = 8'b10101010;
        context2 = 8'b11001100;
        #10;

        // Test case 2
        feature  = 8'b00001111;
        context2 = 8'b11110000;
        #10;

        // Test case 3
        feature  = 8'b11111111;
        context2 = 8'b00000000;
        #10;

        $finish;
    end

endmodule
