# -----------------------------------------------------------------------------
# Makefile for pico2-ice Project
# Generates .bin bitstream for iCE40UP5K
# -----------------------------------------------------------------------------

PROJ = sensor_stream
PIN_DEF = pico2_ice_pins.pcf
DEVICE = up5k
PACKAGE = sg48

# Source files
SRCS = top_level.sv fpga_logic.sv serial_2_parallel.sv parallel_2_serial.sv

all: $(PROJ).bin

# 1. Synthesis (SystemVerilog -> JSON)
$(PROJ).json: $(SRCS)
	yosys -p 'synth_ice40 -top top_level -json $@' $(SRCS)

# 2. Place and Route (JSON -> ASC)
$(PROJ).asc: $(PROJ).json $(PIN_DEF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --pcf $(PIN_DEF) --json $< --asc $@

# 3. Bitstream Generation (ASC -> BIN)
$(PROJ).bin: $(PROJ).asc
	icepack $< $@

# Cleanup
clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

.PHONY: all clean