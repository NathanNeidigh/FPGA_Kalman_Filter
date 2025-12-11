import spidev
import time
import struct
import numpy as np
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt

spi = spidev.SpiDev(0, 0)
spi.max_speed_hz = 10_000_000 #10MHz
spi.mode = 0b11

def write_reg(reg, value):
    spi.xfer2([reg & 0x7F, value])

def read_reg(reg, msg_len):
    address = reg | 0x80
    data = spi.xfer2([address] + [0]*msg_len)
    
    return data

def read_accel():
    msg_len = 6
    data = read_reg(0x28, msg_len)
    x, y, z = struct.unpack('<hhh', bytes(data[1:]))

    g = 0.000061
    return x*g, y*g, z*g

def setup_IMU():
    write_reg(0x10, 0x60)

setup_IMU()

xs, ys, zs = [], [], []
times = []

start = time.time()

plt.ion()
fig, ax = plt.subplots()
line_x, = ax.plot([], [], label='Ax')
line_y, = ax.plot([], [], label='Ay')
line_z, = ax.plot([], [], label='Az')
ax.legend()
ax.set_ylim(-2, 2)
ax.set_xlabel("Time (s)")
ax.set_ylabel("Acceleration (g)")

while True:
    x, y, z = read_accel()
    t = time.time() - start

    xs.append(x)
    ys.append(y)
    zs.append(z)
    times.append(t)

    line_x.set_data(times, xs)
    line_y.set_data(times, ys)
    line_z.set_data(times, zs)
    ax.set_xlim(max(0, t-5), t)
    plt.pause(0.001)
