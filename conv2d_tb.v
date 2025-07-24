`timescale 1ns / 1ps

module tb_conv1;

  // Convolution Parameters
  parameter DATA_WIDTH   = 32;
  parameter BATCH_SIZE   = 1;
  parameter IN_CHANNELS  = 8;
  parameter IN_HEIGHT    = 7;
  parameter IN_WIDTH     = 7;
  parameter OUT_CHANNELS = 32;
  parameter KERNEL_SIZE  = 7;
  parameter STRIDE       = 1;
  parameter PADDING      = 3;
  parameter OUT_HEIGHT   = (IN_HEIGHT + 2*PADDING - KERNEL_SIZE) / STRIDE + 1;
  parameter OUT_WIDTH    = (IN_WIDTH + 2*PADDING - KERNEL_SIZE) / STRIDE + 1;

  // Inputs & Outputs
  reg clk, rst;
  reg [BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH*DATA_WIDTH-1:0] input_tensor_flat;
  reg [OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0] weights_flat;
  reg [OUT_CHANNELS*DATA_WIDTH-1:0] bias_flat;
  wire [BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH*DATA_WIDTH-1:0] output_tensor_flat;

  // Instantiate DUT
  conv2d #(
    .BATCH_SIZE(BATCH_SIZE),
    .IN_CHANNELS(IN_CHANNELS),
    .OUT_CHANNELS(OUT_CHANNELS),
    .IN_HEIGHT(IN_HEIGHT),
    .IN_WIDTH(IN_WIDTH),
    .KERNEL_SIZE(KERNEL_SIZE),
    .STRIDE(STRIDE),
    .PADDING(PADDING),
    .DATA_WIDTH(DATA_WIDTH)
  ) uut (
    .clk(clk),
    .rst(rst),
    .input_tensor_flat(input_tensor_flat),
    .weights_flat(weights_flat),
    .bias_flat(bias_flat),
    .output_tensor_flat(output_tensor_flat)
  );

  // Clock generation: 100MHz = 10ns period
  always #5 clk = ~clk;

  // Local arrays for loading memory
  reg [DATA_WIDTH-1:0] input_tensor   [0:BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH-1];
  reg [DATA_WIDTH-1:0] weights_tensor [0:OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE-1];
  reg [DATA_WIDTH-1:0] bias_tensor    [0:OUT_CHANNELS-1];

  integer i;
  integer output_file;

  // Cycle counter and done flag
  integer cycle_count = 0;
  reg done = 0;

  // Count clock cycles after reset deasserted
  always @(posedge clk) begin
    if (!rst && !done)
      cycle_count <= cycle_count + 1;
  end

  initial begin
    clk = 0;
    rst = 1;
    input_tensor_flat = 0;
    weights_flat = 0;
    bias_flat = 0;
    cycle_count = 0;
    done = 0;

    $display("🚀 Simulation started");

    // Load HEX files
    $display("📥 Loading input...");
    $readmemh("input_hex.txt", input_tensor);
    $display("📥 Loading weights...");
    $readmemh("weights_hex.txt", weights_tensor);
    $display("📥 Loading bias...");
    $readmemh("bias_hex.txt", bias_tensor);

    // Flatten input tensor
    $display("🔃 Flattening input tensor...");
    for (i = 0; i < BATCH_SIZE*IN_CHANNELS*IN_HEIGHT*IN_WIDTH; i = i + 1)
      input_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH] = input_tensor[i];

    // Flatten weights
    $display("🔃 Flattening weights tensor...");
    for (i = 0; i < OUT_CHANNELS*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE; i = i + 1)
      weights_flat[i*DATA_WIDTH +: DATA_WIDTH] = weights_tensor[i];

    // Flatten bias
    $display("🔃 Flattening bias tensor...");
    for (i = 0; i < OUT_CHANNELS; i = i + 1)
      bias_flat[i*DATA_WIDTH +: DATA_WIDTH] = bias_tensor[i];

    // Deassert reset after 20ns
    $display("🛑 Deasserting reset in 20ns...");
    #20 rst = 0;
    $display("▶️  Running convolution...");

    // Let simulation run for enough time
    #2000;

    done = 1; // Stop counting cycles
    $display("⏱️  Total clock cycles: %0d", cycle_count);
    $display("⏱️  Time at 100MHz: %0d ns = %0.3f us", cycle_count * 10, cycle_count * 10.0 / 1000.0);

    // Write output to file
    $display("💾 Writing output to output_hex.txt...");
    output_file = $fopen("output_hex.txt", "w");

    for (i = 0; i < BATCH_SIZE*OUT_CHANNELS*OUT_HEIGHT*OUT_WIDTH; i = i + 1) begin
      $fdisplay(output_file, "%h", output_tensor_flat[i*DATA_WIDTH +: DATA_WIDTH]);
    end

    $fclose(output_file);
    $display("✅ Simulation completed, output saved.");
    $finish;
  end

endmodule
