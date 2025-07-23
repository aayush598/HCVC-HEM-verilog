`timescale 1ns/1ps

module tb_contextual_encoder;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter BATCH_SIZE = 1;
    parameter CHANNEL_N = 1;
    parameter CHANNEL_M = 1;
    parameter HEIGHT = 16;
    parameter WIDTH = 16;
    parameter KERNEL_SIZE = 3;
    parameter STRIDE = 2;
    parameter PADDING = 1;

    // Local parameters
    localparam HEIGHT_2 = HEIGHT/2;
    localparam WIDTH_2 = WIDTH/2;
    localparam HEIGHT_4 = HEIGHT/4;
    localparam WIDTH_4 = WIDTH/4;
    localparam HEIGHT_8 = HEIGHT/8;
    localparam WIDTH_8 = WIDTH/8;
    localparam HEIGHT_16 = HEIGHT/16;
    localparam WIDTH_16 = WIDTH/16;

    // Clock and reset
    reg clk = 0;
    reg rst = 0;

    // Inputs
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT*WIDTH*DATA_WIDTH-1:0] x;
    reg [BATCH_SIZE*3*HEIGHT*WIDTH*DATA_WIDTH-1:0] context1;
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT_2*WIDTH_2*DATA_WIDTH-1:0] context2;
    reg [BATCH_SIZE*CHANNEL_N*HEIGHT_4*WIDTH_4*DATA_WIDTH-1:0] context3;

    reg [CHANNEL_N*(CHANNEL_N+3)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv1_weights;
    reg [CHANNEL_N*DATA_WIDTH-1:0] conv1_bias;

    reg [(CHANNEL_N*2)*CHANNEL_N*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv2_weights;
    reg [CHANNEL_N*DATA_WIDTH-1:0] conv2_bias;

    reg [CHANNEL_N*(CHANNEL_N*2)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv3_weights;
    reg [CHANNEL_N*DATA_WIDTH-1:0] conv3_bias;

    reg [CHANNEL_M*CHANNEL_N*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] conv4_weights;
    reg [CHANNEL_M*DATA_WIDTH-1:0] conv4_bias;

    reg [(CHANNEL_N)*CHANNEL_N*2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res1_weights1;
    reg [(CHANNEL_N)*DATA_WIDTH-1:0] res1_bias1;
    reg [CHANNEL_N*2*(CHANNEL_N)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res1_weights2;
    reg [CHANNEL_N*2*DATA_WIDTH-1:0] res1_bias2;

    reg [(CHANNEL_N)*CHANNEL_N*2*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res2_weights1;
    reg [(CHANNEL_N)*DATA_WIDTH-1:0] res2_bias1;
    reg [CHANNEL_N*2*(CHANNEL_N)*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] res2_weights2;
    reg [CHANNEL_N*2*DATA_WIDTH-1:0] res2_bias2;

    // Output
    wire [BATCH_SIZE*CHANNEL_M*HEIGHT_16*WIDTH_16*DATA_WIDTH-1:0] feature_out;

    // Instantiate DUT
    contextual_encoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .CHANNEL_N(CHANNEL_N),
        .CHANNEL_M(CHANNEL_M),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING)
    ) dut (
        .clk(clk),
        .rst(rst),
        .x(x),
        .context1(context1),
        .context2(context2),
        .context3(context3),
        .conv1_weights(conv1_weights),
        .conv1_bias(conv1_bias),
        .conv2_weights(conv2_weights),
        .conv2_bias(conv2_bias),
        .conv3_weights(conv3_weights),
        .conv3_bias(conv3_bias),
        .conv4_weights(conv4_weights),
        .conv4_bias(conv4_bias),
        .res1_weights1(res1_weights1),
        .res1_bias1(res1_bias1),
        .res1_weights2(res1_weights2),
        .res1_bias2(res1_bias2),
        .res2_weights1(res2_weights1),
        .res2_bias1(res2_bias1),
        .res2_weights2(res2_weights2),
        .res2_bias2(res2_bias2),
        .feature_out(feature_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        $display("Starting simulation...");

        // Enable waveform dump
        $dumpfile("contextual_encoder.vcd");
        $dumpvars(0, tb_contextual_encoder);

        // Reset
        rst = 1;
        #20;
        rst = 0;

        // === Simple Initialization with Known Values ===

        // Input tensor
        x = {128{8'h01}};          // x = all 1s
        context1 = {384{8'h02}};   // 3 channels * all 2s
        context2 = {64{8'h03}};    // all 3s
        context3 = {16{8'h04}};    // all 4s

        // Conv Weights and Bias
        conv1_weights = {72{8'h01}};
        conv1_bias = 8'h00;

        conv2_weights = {72{8'h01}};
        conv2_bias = 8'h00;

        conv3_weights = {72{8'h01}};
        conv3_bias = 8'h00;

        conv4_weights = {9{8'h01}};
        conv4_bias = 8'h00;

        // ResBlock weights and biases
        res1_weights1 = {72{8'h01}};
        res1_bias1 = 8'h00;
        res1_weights2 = {144{8'h01}};
        res1_bias2 = {2{8'h00}};

        res2_weights1 = {72{8'h01}};
        res2_bias1 = 8'h00;
        res2_weights2 = {144{8'h01}};
        res2_bias2 = {2{8'h00}};

        // Wait for operations to complete
        #200;

        $display("Output feature_out: %h", feature_out);

        $finish;
    end

endmodule
