// -----------------------------------------------------------------------------
// Module: top_level
// Description: Top-level entry point for pico2-ice FPGA.
//              Routes SPI MISO signals to LEDs and external headers.
// -----------------------------------------------------------------------------

module top (
    // SPI Interface (Shared with RP2350 and Sensor)
    input logic rp2350_miso,  // Pin 27: Data from Sensor
    input logic rp2350_cs,    // Pin 19: Same CS as Sensor
    input logic rp2350_sck,   // Pin 26: Same Clock as Sensor

    // For Testing Only
    input logic spi_mosi,

    // Outputs
    output logic led_red_n,     // Pin 41: Active-Low Red LED
    output logic led_green_n,   // Pin 39: Active-Low Green LED
    output logic led_blue_n,    // Pin 40: Active-Low Blue LED
    output logic rpi_miso,      // Pin 23: Post-Logic Output
    output logic rpi_cs,
    output logic rpi_sck
);
  logic [15:0] z;
  logic        z_valid;
  // Flash LEDs
  assign led_red_n   = ~rp2350_miso;
  assign led_blue_n  = ~z_valid;  //LED indicator of successful serial to parallel conversion
  assign led_green_n = ~rpi_miso;  // Flash Green LED with processed data (Active-Low)

  // Instantiate the deserializer
  serial_2_parallel u_serial_2_parallel (
      .rp2350_sck     (rp2350_sck),   // Physical Pin
      .rp2350_cs      (rp2350_cs),    // Physical Pin
      .rp2350_miso    (rp2350_miso),  // Physical Pin
      .Filter_Input(z),            // Parallel output wire
      .data_ready  (z_valid)       // Valid parallel data input to FPGA indicator
  );

  //Internal wire for the serial output data
  logic [15:0] filtered_data;
  logic x_valid;

  // kalman_filter kalman_filter (
  //     .clk(z_valid),
  //     .z_in(z),
  //     .x_out(filtered_data),
  //     .x_valid(x_valid)
  // );
    assign filtered_data = z;   // Bypass Kalman filter for testing
    assign x_valid = z_valid;   // Bypass Kalman filter for testing

  // Instantiate the Parallel-to-Serial converter
  parallel_2_serial u_parallel_2_serial (
      .filtered_data(filtered_data),  // The 16-bit data to send
      .filter_done  (x_valid),
      .rpi_sck      (rpi_sck),
      .rpi_cs       (rpi_cs),
      .rpi_miso     (rpi_miso)       // The physical serial output pin (Master Out)
  );

endmodule

