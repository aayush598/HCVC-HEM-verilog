import torch
import torch.nn as nn
import torch.nn.functional as F

def mod256(tensor):
    return torch.remainder(tensor, 256)  # Ensures values are in [0, 255]

class ResBlock(nn.Module):
    def __init__(self, channel, slope=0.01, start_from_relu=True, end_with_relu=False,
                 bottleneck=False):
        super().__init__()
        self.relu = nn.LeakyReLU(negative_slope=slope) if slope >= 0.0001 else nn.ReLU()
        
        self.conv1 = nn.Conv2d(channel, channel // 2, 3, padding=1)
        self.conv2 = nn.Conv2d(channel // 2, channel, 3, padding=1)
        
        self.first_layer = self.relu if start_from_relu else nn.Identity()
        self.last_layer = self.relu if end_with_relu else nn.Identity()

    def forward(self, x):
        out = self.first_layer(x)
        out = mod256(out)
        out = self.conv1(out)
        out = mod256(out)
        out = self.relu(out)
        out = mod256(out)
        out = self.conv2(out)
        out = mod256(out)
        out = self.last_layer(out)
        out = mod256(out)
        out = x + out
        return mod256(out)

class ContextualEncoder(nn.Module):
    def __init__(self, channel_N=1, channel_M=1):
        super().__init__()
        self.conv1 = nn.Conv2d(channel_N + 3, channel_N, 3, stride=2, padding=1)
        self.res1 = ResBlock(channel_N * 2, slope=0.1, start_from_relu=True, end_with_relu=True)
        self.conv2 = nn.Conv2d(channel_N * 2, channel_N, 3, stride=2, padding=1)
        self.res2 = ResBlock(channel_N * 2, slope=0.1, start_from_relu=True, end_with_relu=True)
        self.conv3 = nn.Conv2d(channel_N * 2, channel_N, 3, stride=2, padding=1)
        self.conv4 = nn.Conv2d(channel_N, channel_M, 3, stride=2, padding=1)

    def forward(self, x, context1, context2, context3):
        print("=== Forward Pass Debug ===")
        print("x:", x.shape, "mean:", x.mean().item())

        concat1 = torch.cat([x, context1], dim=1)
        feature = self.conv1(concat1)
        feature = mod256(feature)

        concat2 = torch.cat([feature, context2], dim=1)
        feature = self.res1(concat2)
        feature = mod256(feature)

        feature = self.conv2(feature)
        feature = mod256(feature)

        concat3 = torch.cat([feature, context3], dim=1)
        feature = self.res2(concat3)
        feature = mod256(feature)

        feature = self.conv3(feature)
        feature = mod256(feature)

        feature = self.conv4(feature)
        feature = mod256(feature)

        return feature

# === Testing Function Remains the Same ===

def test_model():
    print("Initializing test with small values to match Verilog...")
    
    x = torch.ones((1, 1, 16, 16), dtype=torch.float32) * 1        
    context1 = torch.ones((1, 3, 16, 16), dtype=torch.float32) * 2  
    context2 = torch.ones((1, 1, 8, 8), dtype=torch.float32) * 3    
    context3 = torch.ones((1, 1, 4, 4), dtype=torch.float32) * 4    

    model = ContextualEncoder(channel_N=1, channel_M=1)

    with torch.no_grad():
        for name, m in model.named_modules():
            if isinstance(m, nn.Conv2d):
                print(f"Initializing {name}: weight shape {m.weight.shape}")
                nn.init.constant_(m.weight, 1.0)
                if m.bias is not None:
                    nn.init.constant_(m.bias, 0.0)

    print("\n" + "="*50)
    print("RUNNING FORWARD PASS")
    print("="*50)
    
    with torch.no_grad():
        out = model(x, context1, context2, context3)

    print("\n" + "="*50)
    print("FINAL RESULTS")
    print("="*50)
    print("Final output tensor shape:", out.shape)
    print("Final output tensor (float):", out.item())
    print("Final output as integer:", int(round(out.item())))
    print("Final output uint8 (mod 256):", int(round(out.item())) % 256)
    print("Final output as hex:", hex(int(round(out.item())) % 256))

    return out

if __name__ == "__main__":
    result = test_model()
