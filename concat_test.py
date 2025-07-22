import torch

# Define 8-bit feature and context2 as binary tensors
feature = torch.tensor([[1,0,1,0,1,0,1,0]], dtype=torch.uint8)   # 0b10101010
context2 = torch.tensor([[1,1,0,0,1,1,0,0]], dtype=torch.uint8)  # 0b11001100

# Concatenate along columns (dim=1)
concat_out = torch.cat([feature, context2], dim=1)

print("feature   :", feature)
print("context2  :", context2)
print("concat_out:", concat_out)
print("concat_out as bits:", ''.join(str(bit.item()) for bit in concat_out[0]))
