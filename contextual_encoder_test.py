import torch
import torch.nn as nn
import torch.nn.functional as F

class ResBlock(nn.Module):
    def __init__(self, channel, slope=0.01, start_from_relu=True, end_with_relu=False,
                 bottleneck=False):
        super().__init__()
        self.relu = nn.LeakyReLU(negative_slope=slope) if slope >= 0.0001 else nn.ReLU()
        if bottleneck:
            self.conv1 = nn.Conv2d(channel, channel // 2, 3, padding=1)
            self.conv2 = nn.Conv2d(channel // 2, channel, 3, padding=1)
        else:
            self.conv1 = nn.Conv2d(channel, channel, 3, padding=1)
            self.conv2 = nn.Conv2d(channel, channel, 3, padding=1)
        self.first_layer = self.relu if start_from_relu else nn.Identity()
        self.last_layer = self.relu if end_with_relu else nn.Identity()

    def forward(self, x):
        out = self.first_layer(x)
        out = self.conv1(out)
        out = self.relu(out)
        out = self.conv2(out)
        out = self.last_layer(out)
        return x + out

class ContextualEncoder(nn.Module):
    def __init__(self, channel_N=64, channel_M=96):
        super().__init__()
        self.conv1 = nn.Conv2d(channel_N + 3, channel_N, 3, stride=2, padding=1)
        self.res1 = ResBlock(channel_N * 2, bottleneck=True, slope=0.1,
                             start_from_relu=True, end_with_relu=True)
        self.conv2 = nn.Conv2d(channel_N * 2, channel_N, 3, stride=2, padding=1)
        self.res2 = ResBlock(channel_N * 2, bottleneck=True, slope=0.1,
                             start_from_relu=True, end_with_relu=True)
        self.conv3 = nn.Conv2d(channel_N * 2, channel_N, 3, stride=2, padding=1)
        self.conv4 = nn.Conv2d(channel_N, channel_M, 3, stride=2, padding=1)

    def forward(self, x, context1, context2, context3):
        print("Input shapes:")
        print("x:", x.shape)
        print("context1:", context1.shape)
        print("context2:", context2.shape)
        print("context3:", context3.shape)

        # Layer 1
        feature = self.conv1(torch.cat([x, context1], dim=1))
        print("After conv1:", feature[0, 0, :2, :2])

        # Layer 2
        feature = self.res1(torch.cat([feature, context2], dim=1))
        print("After res1:", feature[0, 0, :2, :2])

        # Layer 3
        feature = self.conv2(feature)
        print("After conv2:", feature[0, 0, :2, :2])

        # Layer 4
        feature = self.res2(torch.cat([feature, context3], dim=1))
        print("After res2:", feature[0, 0, :1, :1])

        # Layer 5
        feature = self.conv3(feature)
        print("After conv3:", feature[0, 0, :1, :1])

        # Layer 6 (final)
        feature = self.conv4(feature)
        print("After conv4 (final output):", feature)

        return feature

# === Testing Setup ===

# Assume input 16x16 with values matching Verilog expectations
x = torch.ones((1, 3, 16, 16)) * 1       # x input = 1
context1 = torch.ones((1, 64, 16, 16)) * 2  # context1 input = 2
context2 = torch.ones((1, 64, 8, 8)) * 3     # context2 input = 3
context3 = torch.ones((1, 64, 4, 4)) * 4     # context3 input = 4

model = ContextualEncoder(channel_N=64, channel_M=96)

# Set all weights to 1 and biases to 0
with torch.no_grad():
    for m in model.modules():
        if isinstance(m, nn.Conv2d):
            nn.init.constant_(m.weight, 1.0)
            if m.bias is not None:
                nn.init.constant_(m.bias, 0.0)

out = model(x, context1, context2, context3)

print("\nFinal output tensor (float):", out)
print("Final output tensor shape:", out.shape)
print("Final output scalar value (rounded):", round(out[0, 0, 0, 0].item()))
print("Final output uint8 mod 256:", int(round(out[0, 0, 0, 0].item())) % 256)
