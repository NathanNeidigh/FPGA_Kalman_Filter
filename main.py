# -----------------------------------------------------------------------------
# File: main.py
# Description: This script performs the system initialization sequence for
#              the pico2-ice board:
#              1. Loads the FPGA bitstream ('sensor_stream.bin') into the CRAM
#                 using the optimized 'ice' module.
#              2. Initializes the ISM330DHCX sensor via the shared SPI bus.
# Target:      pico2-ice (RP2350 Host)
# -----------------------------------------------------------------------------

import time
from machine import Pin, SPI
# The 'ice' module provides a high-level, reliable interface for
# programming the iCE40 FPGA from the RP2350.
import ice 

# ==========================================
# 1. PIN DEFINITIONS (RP2350 GPIOs)
# ==========================================

# --- FPGA Configuration Pins (CRAM) ---
# These are the specific RP2350 GPIOs used by the 'ice' module to program the FPGA.
# Pin assignments are critical and based on your provided reference.
PIN_CDONE    = 40  # GPIO CDONE pin (Done signal, checks if configuration was successful)
PIN_CLOCK    = 21  # GPIO FPGA configuration clock pin
PIN_CRESET_B = 31  # GPIO FPGA Reset (Active Low, held low during config)
PIN_CRAM_CS  = 5   # GPIO CRAM SPI Chip Select (CS)
PIN_CRAM_MOSI= 4   # GPIO CRAM SPI Master Out Slave In (MOSI)
PIN_CRAM_SCK = 6   # GPIO CRAM SPI Clock (SCK)

# --- Sensor Pins (Shared SPI Bus) ---
# These RP2350 GPIOs correspond to the standard peripheral headers used
# to communicate with the ISM330DHCX sensor. The FPGA acts as a listener/router
# on these pins after it is configured.
SENSOR_CS   = 33  # GPIO SPI Chip Select for the sensor (FPGA pin )
SENSOR_MOSI = 35  # GPIO Master Out (RP2350/FPGA to Sensor) (FPGA pin )
SENSOR_SCK  = 34  # GPIO SPI Clock (FPGA pin 
SENSOR_MISO = 32  # GPIO Master In (Sensor to FPGA/RP2350) (FPGA pin )

# ==========================================
# 2. FPGA LOADER
# ==========================================

def load_bitstream(filename):
    """Initializes the FPGA interface and loads the bitstream into CRAM."""
    print(f"[FPGA] Starting CRAM load for {filename}...")

    try:
        # 1. Initialize the FPGA object using the correct RP2350 GPIO pins.
        fpga = ice.fpga(
            cdone=Pin(PIN_CDONE),
            clock=Pin(PIN_CLOCK),
            creset=Pin(PIN_CRESET_B),
            cram_cs=Pin(PIN_CRAM_CS),
            cram_mosi=Pin(PIN_CRAM_MOSI),
            cram_sck=Pin(PIN_CRAM_SCK),
            frequency=48 # Set CRAM programming frequency to 48 MHz
        )

        # 2. Start the configuration sequence (resets FPGA and prepares bus)
        fpga.start()

        # 3. Open the bitstream file
        with open(filename, "rb") as f:
            # 4. Program the CRAM with the bitstream data
            fpga.cram(f)

        # The 'cram' function handles the CDONE signal and synchronization
        print("[FPGA] Bitstream loaded successfully. FPGA is now running.")
        return True
        
    except OSError:
        print(f"[FPGA] ERROR: Could not find '{filename}'. Check file name.")
        return False
    except Exception as e:
        print(f"[FPGA] ERROR during configuration: {e}")
        return False
        

# ==========================================
# 3. SENSOR INITIALIZATION (Shared SPI)
# ==========================================

def init_sensor():
    """Configures the ISM330DHCX sensor via the shared SPI bus."""
    print("[SENSOR] Configuring ISM330DHCX...")
    
    # 1. Setup Chip Select Pin
    # Must be configured as output and held high (inactive) initially.
    cs = Pin(SENSOR_CS, Pin.OUT, value=1)
    
    # 2. Initialize Hardware SPI (SPI ID 1 on the RP2350)
    # The FPGA is configured to listen passively to this bus, allowing the
    # RP2350 to set up the sensor without contention.
    spi = SPI(0, 
              baudrate=5_000_000, # 5 MHz communication speed
              polarity=0,         # CPOL=0
              phase=0,            # CPHA=0
              sck=Pin(SENSOR_SCK, mode=Pin.OUT),
              mosi=Pin(SENSOR_MOSI, mode=Pin.OUT),
              miso=Pin(SENSOR_MISO, mode=Pin.OUT))
    
    # Helper to write register (address & data)
    def write_reg(reg, val):
        try:
            cs.value(0) # CS Low (Start transaction)
            spi.write(bytearray([reg & 0x7F, val])) # Address 0x7F masks R/W bit to 0 (Write)
            #spi.write(b"\xb4")
        finally:
            cs.value(1) # CS High (End transaction)

    # Helper to read register (address & data)
    def read_reg(reg):
        cs.value(0)
        spi.write(bytearray([reg | 0x80])) # Address 0x80 sets R/W bit to 1 (Read)
        val = spi.read(1)                  # Read 1 byte of data
        cs.value(1)
        return val[0]
    
    def read_accel():
        cs.value(0)
        spi.write(bytearray([0x28 | 0x80]))
        data = spi.read(6)
        cs.value(1)
        return data
    write_reg(0x12, 0x01) 					#Software RESET
    time.sleep_ms(30)
    write_reg(0x10, 0x5C)					#Config. Accel.
    whoami = read_reg(0x0F)
    if whoami != 0x6B:
        print(f"ERROR: WHO_AM_I 0x{whoami:02X}")
        return
    print("Success: WHO_AM_I 0x6B")
    sensitivity = 8/65536  # ±4 g /range(1 byte)
    print("Accel loop: Rotate to test (Ctrl+C stop)")
    try:
        while True:
            data = read_accel()
            # Raw unsigned 16-bit
            x_raw = int.from_bytes(data[0:2], 'little')
            y_raw = int.from_bytes(data[2:4], 'little')
            z_raw = int.from_bytes(data[4:6], 'little')

            # Manual signed conversion (for 16-bit two's complement)
            def to_signed(n, bits=16):
                if n >= (1 << (bits - 1)):
                    n -= (1 << bits)
                return n

            x_raw = to_signed(x_raw)
            y_raw = to_signed(y_raw)
            z_raw = to_signed(z_raw)

            # Scale to g (±4 g mode)
            sensitivity = 8/65536
            x = x_raw * sensitivity
            y = y_raw * sensitivity
            z = z_raw * sensitivity
            
            print(f"X:{x:.3f} Y:{y:.3f} Z:{z:.3f} | Raw: {data.hex()}")
            time.sleep_ms(2)
    except KeyboardInterrupt:
        print("Stopped")

    
# ==========================================
# MAIN EXECUTION
# ==========================================

if __name__ == "__main__":
    # Step 1: Program the FPGA
    # The FPGA must be configured first to set its I/O pins correctly for
    # data routing before the sensor is told to start streaming.
    success = load_bitstream("sensor_stream.bin")

    
    if success:
        # Step 2: Initialize the Sensor
        init_sensor()
