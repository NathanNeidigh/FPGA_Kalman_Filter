from machine import Pin
import ice

# Set frequency to 1 MHz
fpga = ice.fpga(cdone=Pin(40), clock=Pin(21), creset=Pin(31), cram_cs=Pin(5), cram_mosi=Pin(4), cram_sck=Pin(6), frequency=1)
fpga.start()
