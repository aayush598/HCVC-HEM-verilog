clear
python test_conv2d.py 
iverilog -o out top.v conv2d_memoryoptimization.v conv2d_memoryoptimization_tb.v 
vvp out