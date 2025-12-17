TOP = top
TEST = tb.sv

SRC = $(TOP).sv
PCF = $(TOP).pcf

JSON = bin/$(TOP).json
ASC = bin/$(TOP).asc
BIN = bin/bitstream.bin

DEVICE = up5k
PACKAGE = sg48
PNR_SEED =

#INCLUDE_PATH = /home/neidna/ENGR_433/99-common/
#OBJECTS = $(INCLUDE_PATH)debounce.v $(INCLUDE_PATH)color_mixer.v
INCLUDE_PATH =
OBJECTS = serial_2_parallel.sv parallel_2_serial.sv kalman_filter.sv

RAM = true
RP2350 = false

all: $(BIN)

flash: $(BIN)			#Change the path below to match your mounted USB drive
	cp -u $(BIN) /media/$$USER/5221-0000/bitstream.bin || (sleep 2 && cp -u $(BIN) /media/$$USER/5221-0000/bitstream.bin)
	sleep 1
	if [ "$(RP2350)" = "true" ]; then \
		sudo ~/.local/bin/mpremote connect /dev/ttyACM0 run main.py; \
	elif [ "$(RAM)" = "true" ]; then \
		sudo ~/.local/bin/mpremote connect /dev/ttyACM0 run flash_RAM.py; \
	else \
		sudo ~/.local/bin/mpremote connect /dev/ttyACM0 run flash.py; \
	fi

test: $(TEST)
	iverilog -g2012 $(SRC) $(OBJECTS) $(TEST) -DSIMULATION -o bin/test
	./bin/test

$(JSON): $(SRC)
	yosys -q -p 'read -sv $(OBJECTS) $(SRC) ; synth_ice40 -top $(TOP) -json $(JSON)'

$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 -q --$(DEVICE) \
		$(if $(PACKAGE), --package $(PACKAGE)) \
		--json $(JSON) \
		--pcf $(PCF) \
		--asc $(ASC) \
		$(if $(PNR_SEED), --seed $(PNR_SEED))

$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

clean:
	-@rm -f bin/*
	-@rm -f /run/media/$$USER/5221-0000/bitstream.bin
	-@rm -f dump.vcd
