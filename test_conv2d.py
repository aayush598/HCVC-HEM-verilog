import torch
import torch.nn.functional as F
import time

# Parameters
BATCH_SIZE = 1
IN_CHANNELS = 2
OUT_CHANNELS = 1
IN_HEIGHT = 4
IN_WIDTH = 4
KERNEL_SIZE = 2
STRIDE = 2
PADDING = 0

# Input tensor: 0 to 31
input_tensor = torch.arange(BATCH_SIZE * IN_CHANNELS * IN_HEIGHT * IN_WIDTH, dtype=torch.float32)
input_tensor = input_tensor.view(BATCH_SIZE, IN_CHANNELS, IN_HEIGHT, IN_WIDTH)

# Weights: all 1s
weights = torch.ones((OUT_CHANNELS, IN_CHANNELS, KERNEL_SIZE, KERNEL_SIZE), dtype=torch.float32)

# Bias: zeros
bias = torch.zeros(OUT_CHANNELS, dtype=torch.float32)

# Measure time
start = time.time()

output_tensor = F.conv2d(input_tensor, weights, bias, stride=STRIDE, padding=PADDING)

end = time.time()

# Print output
print("\n=== PyTorch Convolution Output Tensor ===")
print(output_tensor)
print("Flattened Output:", output_tensor.view(-1).tolist())
print(f"Convolution Time Taken in Python: {(end - start) * 1e6:.2f} µs")
