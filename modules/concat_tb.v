`timescale 1ns / 1ps

module concat_tb;

    parameter FEATURE_WIDTH = 128;
    parameter CONTEXT_WIDTH = 384;
    parameter TOTAL_WIDTH = FEATURE_WIDTH + CONTEXT_WIDTH;

    reg  [FEATURE_WIDTH-1:0] feature;
    reg  [CONTEXT_WIDTH-1:0] context2;
    wire [TOTAL_WIDTH-1:0] concat_out;

    // Instantiate the concat module
    concat #(FEATURE_WIDTH, CONTEXT_WIDTH) uut (
        .feature(feature),
        .context2(context2),
        .concat_out(concat_out)
    );

    initial begin
        $display("Time\t\tFEATURE\t\t\t\t\t\t\t\t\t\tCONTEXT\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tCONCAT_OUT");
        $monitor("%0t\t%032x\t%096x\t%0x", 
                 $time, feature, context2, concat_out);

        // Test case 1
        feature  = 128'h0123456789ABCDEF0123456789ABCDEF;
        context2 = 384'hFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210;
        #10;

        // Test case 2
        feature  = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        context2 = 384'h0000000000000000000000000000000000000000000000000000000000000000;
        #10;

        // Test case 3
        feature  = 128'h00000000000000000000000000000000;
        context2 = 384'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        #10;

        $finish;
    end

endmodule
