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
WINDOW_SIZE = 500
PLOT_INTERVAL = 0.5

index = 0
zs = np.zeros(WINDOW_SIZE, dtype=np.float64)
times = np.zeros(WINDOW_SIZE, dtype=np.float64)

def write_reg(reg, value):
    spi.xfer2([reg & 0x7F, value])

def read_reg(reg, msg_len):
    address = reg | 0x80
    data = spi.xfer2([address] + [0]*msg_len)
    
    return data

def setup_IMU():
    write_reg(0x10, 0xA0)

def read_accel():
    data = read_reg(0x2C, 2)
    z = int.from_bytes(data[1:], byteorder="little", signed=True)
    g = 0.000061
    return z*g

def read_accel_fpga():
    data = spi.xfer2([0]*2)
    z = int.from_bytes(data, byteorder="big", signed=True)
    g = 0.000061
    return z*g

def update_buffers(times, zs, t, z):
    global index
    times[index] = t
    zs[index] = z
    index = (index + 1) % WINDOW_SIZE

def read_buffer(buf):
    global index
    return np.concatenate((buf[index:], buf[:index]))

if (False):
    setup_IMU()

    plt.ion()
    fig, ax = plt.subplots()
    line_z, = ax.plot([], [], label='Az')
    ax.set_ylim(0.9, 1.1)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Acceleration (g)")

    start = time.perf_counter()
    last_plot = time.perf_counter()

    while True:
        z = read_accel()
        t = time.perf_counter() - start
        update_buffers(times, zs, t, z)

        now = time.perf_counter()
        if now - last_plot > PLOT_INTERVAL:
            last_plot = now
            valid_times = read_buffer(times)
            valid_zs = read_buffer(zs)
            line_z.set_data(valid_times, valid_zs)
            ax.set_xlim(min(valid_times), max(valid_times))
            sample_rate = WINDOW_SIZE  / (times[index-1] - times[index]) 
            ax.set_title(f"Linear Acceleraion data at {sample_rate}")
            plt.pause(0.001)
else:
    plt.ion()
    fig, ax = plt.subplots()
    line_z, = ax.plot([], [], label='Az')
    ax.set_ylim(0.9, 1.1)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Acceleration (g)")

    start = time.perf_counter()
    last_plot = time.perf_counter()

    while True:
        z = read_accel_fpga()
        t = time.perf_counter() - start
        update_buffers(times, zs, t, z)

        now = time.perf_counter()
        if now - last_plot > PLOT_INTERVAL:
            last_plot = now
            valid_times = read_buffer(times)
            valid_zs = read_buffer(zs)
            line_z.set_data(valid_times, valid_zs)
            ax.set_xlim(min(valid_times), max(valid_times))
            sample_rate = WINDOW_SIZE  / (times[index-1] - times[index]) 
            ax.set_title(f"Linear Acceleraion data at {sample_rate}")
            plt.pause(0.001)
