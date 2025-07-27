import torch
import torch.nn as nn
import torch.nn.functional as F

# Sub-pixel convolution block
def subpel_conv3x3(in_ch, out_ch, r=1):
    return nn.Sequential(
        nn.Conv2d(in_ch, out_ch * r ** 2, kernel_size=3, padding=1),
        nn.PixelShuffle(r)
    )

# Residual block
class ResBlock(nn.Module):
    def __init__(self, channel, slope=0.01, start_from_relu=True, end_with_relu=False,
                 bottleneck=False):
        super().__init__()
        self.relu = nn.LeakyReLU(negative_slope=slope)
        if slope < 0.0001:
            self.relu = nn.ReLU()
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

# Contextual Decoder
class ContextualDecoder(nn.Module):
    def __init__(self, channel_N=4, channel_M=6):  # Keep channels small for testing
        super().__init__()
        self.up1 = subpel_conv3x3(channel_M, channel_N, 2)        # -> N x 2H x 2W
        self.up2 = subpel_conv3x3(channel_N, channel_N, 2)        # -> N x 4H x 4W
        self.res1 = ResBlock(channel_N * 2, bottleneck=True, slope=0.1,
                             start_from_relu=True, end_with_relu=True)
        self.up3 = subpel_conv3x3(channel_N * 2, channel_N, 2)    # -> N x 8H x 8W
        self.res2 = ResBlock(channel_N * 2, bottleneck=True, slope=0.1,
                             start_from_relu=True, end_with_relu=True)
        self.up4 = subpel_conv3x3(channel_N * 2, 1, 2)            # -> 1 x 16H x 16W

    def forward(self, x, context2, context3):
        feature = self.up1(x)
        feature = self.up2(feature)
        feature = self.res1(torch.cat([feature, context3], dim=1))
        feature = self.up3(feature)
        feature = self.res2(torch.cat([feature, context2], dim=1))
        feature = self.up4(feature)
        return feature

# ==== Simple Testing ====
# Initialize the model
model = ContextualDecoder(channel_N=4, channel_M=6)

# Create simple inputs filled with 1s
x = torch.ones(1, 6, 4, 4)           # Main input (B=1, C=6, H=4, W=4)
context3 = torch.ones(1, 4, 16, 16)  # From encoder or another stage
context2 = torch.ones(1, 4, 32, 32)  # From encoder or another stage

# Forward pass
output = model(x, context2, context3)

# Show output
print("Output shape:", output.shape)
print("Output tensor (first 1x1 patch):", output[0, 0, :2, :2])  # Show a small part
    