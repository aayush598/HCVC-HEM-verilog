import math

with open("sigmoid_lut.mem", "w") as f:
    for i in range(256):
        x = (i - 128) / 16.0  # Map index to range -8 to +8
        y = 1 / (1 + math.exp(-x))  # Sigmoid
        fixed = int(y * 4096)  # Convert to Q4.12
        f.write("{:04X}\n".format(fixed & 0xFFFF))
