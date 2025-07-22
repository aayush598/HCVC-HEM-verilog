module concat #(
    parameter FEATURE_WIDTH = 128,
    parameter CONTEXT_WIDTH = 384
)(
    input  [FEATURE_WIDTH-1:0] feature,
    input  [CONTEXT_WIDTH-1:0] context2,
    output [FEATURE_WIDTH + CONTEXT_WIDTH - 1:0] concat_out
);

    assign concat_out = {feature, context2};

endmodule
