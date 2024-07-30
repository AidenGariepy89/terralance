import os
import sys

import matplotlib
import matplotlib.pyplot as plt
import numpy as np

if len(sys.argv) != 2:
    print("Expected path!")
    exit(1)
path = sys.argv[1]

if not os.path.exists(path):
    print("Expected file!")
    exit(1)

file = open(path)
contents = file.readline()
file.close()

x = []
str_nums = contents.split(",")
for str_num in str_nums:
    if str_num == "":
        continue
    x.append(int(str_num))

plt.hist(x, 256)
plt.show()
