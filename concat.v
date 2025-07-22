module concat #(parameter WIDTH = 8)(
    input  [WIDTH-1:0] feature,
    input  [WIDTH-1:0] context2,
    output [2*WIDTH-1:0] concat_out
);

    assign concat_out = {feature, context2};

endmodule
