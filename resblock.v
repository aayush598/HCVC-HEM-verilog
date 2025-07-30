module resblock #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter BATCH_SIZE = 1,
    parameter CHANNELS = 32,
    parameter HEIGHT = 4,
    parameter WIDTH = 4,
    parameter KERNEL_SIZE = 3,
    parameter STRIDE = 1,
    parameter PADDING = 1,
    parameter SLOPE_SMALL = 1'b0,  // 1 if slope < 0.0001 (use ReLU), 0 for LeakyReLU
    parameter START_FROM_RELU = 1'b1,
    parameter END_WITH_RELU = 1'b0,
    parameter BOTTLENECK = 1'b0
) (
    input clk,
    input rst,
    input  [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_in,
    output [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] x_out
);

    // Internal parameters for bottleneck
    localparam CONV1_OUT_CHANNELS = BOTTLENECK ? CHANNELS/2 : CHANNELS;
    localparam CONV2_IN_CHANNELS = BOTTLENECK ? CHANNELS/2 : CHANNELS;
    
    // Memory sizes
    localparam INPUT_MEM_SIZE = BATCH_SIZE * CHANNELS * HEIGHT * WIDTH;
    localparam INTERMEDIATE1_MEM_SIZE = BATCH_SIZE * CONV1_OUT_CHANNELS * HEIGHT * WIDTH;
    localparam INTERMEDIATE2_MEM_SIZE = BATCH_SIZE * CHANNELS * HEIGHT * WIDTH;
    
    // State machine states
    localparam IDLE = 3'b000;
    localparam FIRST_LAYER = 3'b001;
    localparam CONV1 = 3'b010;
    localparam MIDDLE_RELU = 3'b011;
    localparam CONV2 = 3'b100;
    localparam LAST_LAYER = 3'b101;
    localparam RESIDUAL_ADD = 3'b110;
    localparam DONE = 3'b111;
    
    reg [2:0] state, next_state;
    
    // Internal wires for data flow
    wire [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] first_layer_out;
    wire [BATCH_SIZE*CONV1_OUT_CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] conv1_out;
    wire [BATCH_SIZE*CONV1_OUT_CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] relu1_out;
    wire [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] conv2_out;
    wire [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] last_layer_out;
    
    // Control signals
    reg conv1_start, conv2_start;
    wire conv1_done, conv1_valid;
    wire conv2_done, conv2_valid;
    reg processing_done;
    
    // Memory interface signals for conv1
    wire [ADDR_WIDTH-1:0] conv1_input_addr, conv1_output_addr;
    wire [DATA_WIDTH-1:0] conv1_input_data, conv1_output_data;
    wire conv1_input_en, conv1_output_we, conv1_output_en;
    
    // Memory interface signals for conv2
    wire [ADDR_WIDTH-1:0] conv2_input_addr, conv2_output_addr;
    wire [DATA_WIDTH-1:0] conv2_input_data, conv2_output_data;
    wire conv2_input_en, conv2_output_we, conv2_output_en;
    
    // Internal memory arrays
    reg [DATA_WIDTH-1:0] first_layer_mem [0:INPUT_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] conv1_mem [0:INTERMEDIATE1_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] relu1_mem [0:INTERMEDIATE1_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] conv2_mem [0:INTERMEDIATE2_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] last_layer_mem [0:INTERMEDIATE2_MEM_SIZE-1];
    reg [DATA_WIDTH-1:0] input_copy_mem [0:INPUT_MEM_SIZE-1];
    
    // Address counters
    reg [ADDR_WIDTH-1:0] process_addr;
    reg [BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH-1:0] result_reg;
    
    integer i;
    
    // Unpack input tensor to memory array
    always @(*) begin
        for (i = 0; i < INPUT_MEM_SIZE; i = i + 1) begin
            input_copy_mem[i] = x_in[i*DATA_WIDTH +: DATA_WIDTH];
        end
    end
    
    // First layer (ReLU or Identity based on START_FROM_RELU)
    generate
        if (START_FROM_RELU == 1'b1) begin : first_relu_gen
            if (SLOPE_SMALL == 1'b1) begin : first_relu_small
                // Use ReLU for small slope
                relu_binary_clk_array #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .BATCH_SIZE(BATCH_SIZE),
                    .CHANNELS(CHANNELS),
                    .HEIGHT(HEIGHT),
                    .WIDTH(WIDTH)
                ) first_relu_inst (
                    .clk(clk),
                    .reset(rst),
                    .in_tensor(x_in),
                    .out_tensor(first_layer_out)
                );
            end else begin : first_leaky_relu
                // Use LeakyReLU
                leaky_relu_array #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .BATCH_SIZE(BATCH_SIZE),
                    .CHANNELS(CHANNELS),
                    .HEIGHT(HEIGHT),
                    .WIDTH(WIDTH)
                ) first_leaky_relu_inst (
                    .clk(clk),
                    .rst(rst),
                    .in_tensor(x_in),
                    .out_tensor(first_layer_out)
                );
            end
        end else begin : first_identity
            // Identity layer
            identity #(
                .WIDTH(BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH)
            ) first_identity_inst (
                .in(x_in),
                .out(first_layer_out)
            );
        end
    endgenerate
    
    // Pack first layer output to memory
    always @(*) begin
        for (i = 0; i < INPUT_MEM_SIZE; i = i + 1) begin
            first_layer_mem[i] = first_layer_out[i*DATA_WIDTH +: DATA_WIDTH];
        end
    end
    
    // First Conv2D layer
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CHANNELS),
        .OUT_CHANNELS(CONV1_OUT_CHANNELS),
        .IN_HEIGHT(HEIGHT),
        .IN_WIDTH(WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) conv1_inst (
        .clk(clk),
        .rst(rst),
        .start(conv1_start),
        .done(conv1_done),
        .valid(conv1_valid),
        .input_addr(conv1_input_addr),
        .input_data(conv1_input_data),
        .input_en(conv1_input_en),
        .output_addr(conv1_output_addr),
        .output_data(conv1_output_data),
        .output_we(conv1_output_we),
        .output_en(conv1_output_en)
    );
    
    // Memory interface for conv1 input
    assign conv1_input_data = (conv1_input_en && conv1_input_addr < INPUT_MEM_SIZE) ? 
                              first_layer_mem[conv1_input_addr] : {DATA_WIDTH{1'b0}};
    
    // Conv1 output memory write
    always @(posedge clk) begin
        if (conv1_output_en && conv1_output_we && conv1_output_addr < INTERMEDIATE1_MEM_SIZE) begin
            conv1_mem[conv1_output_addr] <= conv1_output_data;
        end
    end
    
    // Pack conv1 output for middle ReLU
    genvar j;
    generate
        for (j = 0; j < INTERMEDIATE1_MEM_SIZE; j = j + 1) begin: conv1_pack
            assign conv1_out[j*DATA_WIDTH +: DATA_WIDTH] = conv1_mem[j];
        end
    endgenerate
    
    // Middle ReLU/LeakyReLU (always present)
    generate
        if (SLOPE_SMALL == 1'b1) begin : middle_relu_small
            relu_binary_clk_array #(
                .DATA_WIDTH(DATA_WIDTH),
                .BATCH_SIZE(BATCH_SIZE),
                .CHANNELS(CONV1_OUT_CHANNELS),
                .HEIGHT(HEIGHT),
                .WIDTH(WIDTH)
            ) middle_relu_inst (
                .clk(clk),
                .reset(rst),
                .in_tensor(conv1_out),
                .out_tensor(relu1_out)
            );
        end else begin : middle_leaky_relu
            leaky_relu_array #(
                .DATA_WIDTH(DATA_WIDTH),
                .BATCH_SIZE(BATCH_SIZE),
                .CHANNELS(CONV1_OUT_CHANNELS),
                .HEIGHT(HEIGHT),
                .WIDTH(WIDTH)
            ) middle_leaky_relu_inst (
                .clk(clk),
                .rst(rst),
                .in_tensor(conv1_out),
                .out_tensor(relu1_out)
            );
        end
    endgenerate
    
    // Pack middle ReLU output to memory
    always @(*) begin
        for (i = 0; i < INTERMEDIATE1_MEM_SIZE; i = i + 1) begin
            relu1_mem[i] = relu1_out[i*DATA_WIDTH +: DATA_WIDTH];
        end
    end
    
    // Second Conv2D layer
    conv2d #(
        .BATCH_SIZE(BATCH_SIZE),
        .IN_CHANNELS(CONV2_IN_CHANNELS),
        .OUT_CHANNELS(CHANNELS),
        .IN_HEIGHT(HEIGHT),
        .IN_WIDTH(WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .STRIDE(STRIDE),
        .PADDING(PADDING),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) conv2_inst (
        .clk(clk),
        .rst(rst),
        .start(conv2_start),
        .done(conv2_done),
        .valid(conv2_valid),
        .input_addr(conv2_input_addr),
        .input_data(conv2_input_data),
        .input_en(conv2_input_en),
        .output_addr(conv2_output_addr),
        .output_data(conv2_output_data),
        .output_we(conv2_output_we),
        .output_en(conv2_output_en)
    );
    
    // Memory interface for conv2 input
    assign conv2_input_data = (conv2_input_en && conv2_input_addr < INTERMEDIATE1_MEM_SIZE) ? 
                              relu1_mem[conv2_input_addr] : {DATA_WIDTH{1'b0}};
    
    // Conv2 output memory write
    always @(posedge clk) begin
        if (conv2_output_en && conv2_output_we && conv2_output_addr < INTERMEDIATE2_MEM_SIZE) begin
            conv2_mem[conv2_output_addr] <= conv2_output_data;
        end
    end
    
    // Pack conv2 output for last layer
    generate
        for (j = 0; j < INTERMEDIATE2_MEM_SIZE; j = j + 1) begin: conv2_pack
            assign conv2_out[j*DATA_WIDTH +: DATA_WIDTH] = conv2_mem[j];
        end
    endgenerate
    
    // Last layer (ReLU or Identity based on END_WITH_RELU)
    generate
        if (END_WITH_RELU == 1'b1) begin : last_relu_gen
            if (SLOPE_SMALL == 1'b1) begin : last_relu_small
                relu_binary_clk_array #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .BATCH_SIZE(BATCH_SIZE),
                    .CHANNELS(CHANNELS),
                    .HEIGHT(HEIGHT),
                    .WIDTH(WIDTH)
                ) last_relu_inst (
                    .clk(clk),
                    .reset(rst),
                    .in_tensor(conv2_out),
                    .out_tensor(last_layer_out)
                );
            end else begin : last_leaky_relu
                leaky_relu_array #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .BATCH_SIZE(BATCH_SIZE),
                    .CHANNELS(CHANNELS),
                    .HEIGHT(HEIGHT),
                    .WIDTH(WIDTH)
                ) last_leaky_relu_inst (
                    .clk(clk),
                    .rst(rst),
                    .in_tensor(conv2_out),
                    .out_tensor(last_layer_out)
                );
            end
        end else begin : last_identity
            identity #(
                .WIDTH(BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH)
            ) last_identity_inst (
                .in(conv2_out),
                .out(last_layer_out)
            );
        end
    endgenerate
    
    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: next_state = FIRST_LAYER;
            FIRST_LAYER: next_state = CONV1;
            CONV1: next_state = conv1_done ? MIDDLE_RELU : CONV1;
            MIDDLE_RELU: next_state = CONV2;
            CONV2: next_state = conv2_done ? LAST_LAYER : CONV2;
            LAST_LAYER: next_state = RESIDUAL_ADD;
            RESIDUAL_ADD: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Control logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv1_start <= 1'b0;
            conv2_start <= 1'b0;
            processing_done <= 1'b0;
            result_reg <= {(BATCH_SIZE*CHANNELS*HEIGHT*WIDTH*DATA_WIDTH){1'b0}};
        end else begin
            case (state)
                CONV1: begin
                    conv1_start <= (conv1_done) ? 1'b0 : 1'b1;
                end
                
                CONV2: begin
                    conv2_start <= (conv2_done) ? 1'b0 : 1'b1;
                end
                
                RESIDUAL_ADD: begin
                    // Perform residual addition: x_in + last_layer_out
                    for (i = 0; i < BATCH_SIZE*CHANNELS*HEIGHT*WIDTH; i = i + 1) begin
                        result_reg[i*DATA_WIDTH +: DATA_WIDTH] <= 
                            x_in[i*DATA_WIDTH +: DATA_WIDTH] + 
                            last_layer_out[i*DATA_WIDTH +: DATA_WIDTH];
                    end
                    processing_done <= 1'b1;
                end
                
                DONE: begin
                    processing_done <= 1'b0;
                end
                
                default: begin
                    conv1_start <= 1'b0;
                    conv2_start <= 1'b0;
                end
            endcase
        end
    end
    
    assign x_out = result_reg;

endmodule