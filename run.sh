clear
python test_conv2d.py 
iverilog -o out conv2d_WBNotInput.v conv2d_WBNotInput_tb.v 
vvp out