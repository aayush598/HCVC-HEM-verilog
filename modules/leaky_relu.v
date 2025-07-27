// Leaky ReLU Module
// f(x) = x if x >= 0, else alpha * x
// Using alpha = 0.01 (1/128 for easy binary implementation)

module leaky_relu #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 8  // 8 fractional bits for fixed-point
)(
    input wire clk,
    input wire rst_n,
    input wire signed [DATA_WIDTH-1:0] x_in,
    input wire valid_in,
    output reg signed [DATA_WIDTH-1:0] y_out,
    output reg valid_out
);

    // Internal signals (not needed anymore, keeping for clarity)
    // reg signed [DATA_WIDTH-1:0] alpha_x;
    // reg signed [DATA_WIDTH+6:0] mult_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_out <= 0;
            valid_out <= 0;
        end
        else if (valid_in) begin
            // Check if input is negative
            if (x_in[DATA_WIDTH-1] == 1'b1) begin  // Negative number
                // Multiply by alpha (1/128 = right shift by 7)
                y_out <= x_in >>> 7;  // Arithmetic right shift by 7 (divide by 128)
            end
            else begin  // Positive or zero
                y_out <= x_in;
            end
            valid_out <= 1'b1;
        end
        else begin
            valid_out <= 1'b0;
        end
    end

endmodule
