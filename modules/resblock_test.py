import torch
import torch.nn as nn

class ResBlock(nn.Module):
    def __init__(self, channel, slope=0.01, start_from_relu=False, end_with_relu=False, bottleneck=False):
        super().__init__()

        # Use Identity as activation
        self.relu = nn.LeakyReLU(negative_slope=slope)
        if slope < 0.0001:
            self.relu = nn.ReLU()

        # Use 1x1 conv with padding=0 to match Verilog testbench
        if bottleneck:
            self.conv1 = nn.Conv2d(channel, channel // 2, kernel_size=1, padding=0)
            self.conv2 = nn.Conv2d(channel // 2, channel, kernel_size=1, padding=0)
        else:
            self.conv1 = nn.Conv2d(channel, channel, kernel_size=1, padding=0)
            self.conv2 = nn.Conv2d(channel, channel, kernel_size=1, padding=0)

        # Use Identity functions (no ReLU)
        self.first_layer = self.relu if start_from_relu else nn.Identity()
        self.last_layer = self.relu if end_with_relu else nn.Identity()

    def forward(self, x):
        out = self.first_layer(x)
        out = self.conv1(out)
        out = self.relu(out)
        out = self.conv2(out)
        out = self.last_layer(out)
        return x + out
x_in = torch.tensor([[[[1.0, 2.0],
                       [3.0, 4.0]]]])  # (1, 1, 2, 2)

model = ResBlock(channel=1, slope=0.01, start_from_relu=False, end_with_relu=False, bottleneck=False)

# Set weights and biases to match Verilog
with torch.no_grad():
    model.conv1.weight.fill_(1.0)
    model.conv1.bias.fill_(0.0)
    model.conv2.weight.fill_(1.0)
    model.conv2.bias.fill_(0.0)

out = model(x_in)

print("Input:")
print(x_in[0, 0].int())

print("\nOutput:")
print(out[0, 0].int())
