clear
python test_conv2d.py 
iverilog -o conv2d_test conv2d.v conv2d_tb.v
vvp conv2d_test