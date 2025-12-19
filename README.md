# 1D Steady-State Kalman Filter on pico2-ice

A SystemVerilog implementation of a real-time Kalman Filter designed for the **pico2-ice** (RP2350 + Lattice iCE40) platform. This project implements a high-speed "middle-man" filter that intercepts raw sensor data via SPI, processes it through a discrete-time Kalman algorithm, and re-serializes it for a host controller.

## 🎯 Project Status: Functional Simulation / Hardware Debugging
*   **Logic Verification:** 100% Pass (All modules verified via testbench and GTKWave).
*   **Mathematical Model:** 100% Pass (Steady-state gain convergence verified).
*   **Hardware Implementation:** **Partial.** The output stage (`parallel_2_serial`) currently exhibits signal integrity issues when interfaced with external Raspberry Pi GPIO.

---

## 🧠 System Architecture

The design utilizes a modular three-stage pipeline to ensure separation of concerns between protocol handling and mathematical computation.

1.  **`serial_2_parallel` (Input Stage):** Deserializes the 16-bit MISO stream from the sensor. It performs automatic byte-swapping to convert Little-Endian sensor data into Big-Endian signed integers for processing.
2.  **`kalman_filter` (Processing Stage):** Implements a Discrete-Time Kalman Filter using a pre-calculated Steady-State Gain ($K = 0.4232$). 
    *   **Fixed-Point Math:** Q1.15 format.
    *   **Optimization:** By using a steady-state gain and a one-dimensional filter, we eliminate the need for costly square root and matrix inversion logic on the FPGA, significantly reducing LUT utilization.
3.  **`parallel_2_serial` (Output Stage):** Latches the filtered data and serializes it for a secondary SPI bus connected to a Raspberry Pi.

---

## ✅ Verification & Simulation

Despite hardware bottlenecks, the logical integrity of the project was confirmed through rigorous RTL simulation. 

*   **Testbench Performance:** Each module was tested individually. Simulation photographs of results prove that the Kalman Filter correctly tracks an input signal while suppressing Gaussian noise.
* Each module's testbench result follows the naming convention of **'tb_<module_name>.png'**.
* The Kalman Filter module has a simulation csv file saved in **'sim/'** directory and an image of a graph of this plot is saved in the **'assets/'** directory.

---

## 🛠 Hardware Analysis & Debugging (Post-Mortem)

During the hardware deployment phase, the output MISO signal from the `parallel_2_serial` module produced inconsistent/garbage values. Our team’s analysis identified the following root causes:

### 1. Signal Integrity & Jitter
The Raspberry Pi's SPI clock (SCLK) and Chip Select (CS) lines showed significant jitter and ringing when interfaced with the FPGA headers. Because the current RTL samples these signals directly, high-frequency noise on the clock line likely caused "double-clocking," where the shift register advanced multiple bits on a single intended clock edge.

### 2. Clock Domain Crossing (CDC) Issues
The FPGA operates in two asynchronous domains: the Sensor SPI clock and the Raspberry Pi SPI clock. The "random" nature of the output suggests a metastability issue where the `parallel_2_serial` module attempts to latch `filtered_data` while the Kalman module is still updating the register.

### 3. Synchronization Failure
Due to time constraints, a multi-stage synchronizer was not implemented on the incoming RPi CS and SCK signals. In a final production build, these asynchronous inputs would be passed through a 2-flip-flop bridge and a debounce filter to ensure stability.

---

## 🚀 Future Improvements
If granted more development time, the following steps would be taken to resolve the hardware issues:
1.  **Input Debouncing:** Implement a high-speed sampling clock (e.g., 48MHz) to "debounce" the RPi SPI signals, treating them as data inputs rather than raw clocks.
2.  **Double Buffering:** Implement a shadow register (ping-pong buffer) between the Kalman Filter and the Serializer to prevent data tearing during read operations.
3.  **Physical Layer Shielding:** Use twisted-pair wiring or lower SPI frequencies to mitigate the EMI/Jitter observed on the Raspberry Pi GPIO interface.

---

## 📁 Repository Structure
*   `/`: SystemVerilog source files.
*   `/sim`: Testbenches. 
*   `/assets`: Screenshots of successful simulations proving logic validity.
*   `top.pcf`: Physical constraint file for the pico2-ice.

---

**Contributors:** Nathan Neidigh & Jeffrey McCormick  
**Course:** ENGR 433  
**Date:** December 2024
