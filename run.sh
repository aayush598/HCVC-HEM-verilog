clear
python test_conv2d.py 
iverilog -o out top.v conv2d_parallelmac.v conv2d_parallelmac_tb.v 
vvp out