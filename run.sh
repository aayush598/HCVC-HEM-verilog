clear
python test_conv2d.py 
iverilog -o conv2d_test conv2d_pipeline.v conv2d_pipeline_tb.v
vvp conv2d_test