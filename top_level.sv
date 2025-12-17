// -----------------------------------------------------------------------------
// Module: top_level
// Description: Top-level entry point for pico2-ice FPGA.
//              Routes SPI MISO signals to LEDs and external headers.
// -----------------------------------------------------------------------------

module top_level (
    // SPI Interface (Shared with RP2350 and Sensor)
    input  logic spi_miso,      // Pin 27: Data from Sensor
    input  logic spi_cs,        // Pin 26: Same Clock as Sensor
    input  logic spi_sck,       // Pin 19: Same CS as Sensor

    // For Testing Only
    input  logic spi_mosi,


    // Outputs
    output logic led_red_n,     // FPGA Pin 41: Active-Low Red LED
    output logic led_green_n,   // Pin 39: Active-Low Green LED
    output logic miso_raw,      // Pin 25: Raw MISO copy
    output logic data_out_logic // Pin 23: Post-Logic Output
);

    // Internal Signals
    logic logic_result;

    // -------------------------------------------------------------------------
    // 1. Raw Data Routing
    // -------------------------------------------------------------------------
    // Send raw sensor data to external Pin 25
    assign miso_raw = spi_miso;

    // Flash Red LED with raw data.
    // Note: LEDs are Active-Low (0 = ON). We invert the signal so:
    // High Data (1) -> LED ON (0).
    assign led_red_n = ~spi_miso;

    // -------------------------------------------------------------------------
    // 2. Logic Processing
    // -------------------------------------------------------------------------
    // Instantiate the logic module (currently a wire)
    fpga_logic u_logic (
        .raw_data_in       (spi_miso),
        .spi_sck           (spi_sck),
        .spi_cs            (spi_cs),
        .spi_miso          (spi_miso),
        .filtered_data_out (logic_result),
        .led_blue_n        ()  // Unused for now
    );

    // -------------------------------------------------------------------------
    // 3. Processed Data Routing
    // -------------------------------------------------------------------------
    // Send processed data to external Pin 23
    assign data_out_logic = logic_result;

    // Flash Green LED with processed data (Active-Low)
    assign led_green_n = ~logic_result;

endmodule