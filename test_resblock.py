import torch
import torch.nn as nn

# Input data: 1 batch, 1 channel, 2x2 image
# Verilog input: [1, 2, 3, 4] → arranged row-wise
input_tensor = torch.tensor([[[[1., 2.],
                               [3., 4.]]]])  # shape: [1, 1, 2, 2]

# Custom resblock definition matching Verilog parameters
class ResBlock(nn.Module):
    def __init__(self, channel, slope=0.0, start_from_relu=False, end_with_relu=False,
                 bottleneck=False):
        super().__init__()
        if bottleneck:
            self.conv1 = nn.Conv2d(channel, channel // 2, 3, padding=1, bias=True)
            self.conv2 = nn.Conv2d(channel // 2, channel, 3, padding=1, bias=True)
        else:
            # Match kernel_size=1 in Verilog
            self.conv1 = nn.Conv2d(channel, channel, kernel_size=1, bias=True)
            self.conv2 = nn.Conv2d(channel, channel, kernel_size=1, bias=True)

        # Disable bias if not used in Verilog
        self.relu = nn.ReLU() if slope < 1e-5 else nn.LeakyReLU(negative_slope=slope)
        self.first_layer = self.relu if start_from_relu else nn.Identity()
        self.last_layer = self.relu if end_with_relu else nn.Identity()

    def forward(self, x):
        out = self.first_layer(x)
        out = self.conv1(out)
        out = self.relu(out)
        out = self.conv2(out)
        out = self.last_layer(out)
        return x + out

# Initialize the model
model = ResBlock(channel=1, slope=0.0, start_from_relu=False, end_with_relu=False, bottleneck=False)

# Manually set weights and biases to match Verilog initialization
# conv1 and conv2 weights are 1, bias is 0 (as in Verilog)
with torch.no_grad():
    model.conv1.weight.fill_(1.0)
    model.conv1.bias.fill_(0.0)
    model.conv2.weight.fill_(1.0)
    model.conv2.bias.fill_(0.0)

# Run the model
output_tensor = model(input_tensor)

# Display output
print("Input Tensor:")
print(input_tensor[0, 0])

print("\nOutput Tensor:")
print(output_tensor[0, 0])

# Convert output to 8-bit values (match Verilog DATA_WIDTH = 8)
print("\nOutput as 8-bit ints:")
print(output_tensor[0, 0].int())
