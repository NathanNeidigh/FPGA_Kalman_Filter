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
    output logic rpi_sck,

    output logic a0,
    output logic a1,
    output logic a2,
    output logic a3,
    output logic a4,
    output logic a5,
    output logic a6,
    output logic a7
);
  logic [15:0] z;                 // Measurement variable, not z-axis
  logic        z_valid;           // Parallel data input latch trigger
  // Flash Indicator LEDs
  assign led_red_n   = ~rp2350_miso;  // Indicates FPGA "sees" data from sensor
  assign led_blue_n  = ~z_valid;      // Indicates successful latching of serial to parallel data 
  assign led_green_n = ~rpi_miso;     // Indicates FPGA sends (serial) data to Raspberry Pi
  
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
    assign a0 = z[0];
    assign a1 = z[1];
    assign a2 = z[2];
    assign a3 = z[3];
    assign a4 = z[4];
    assign a5 = z[5];
    assign a6 = z[6];
    assign a7 = z[7];


  // Instantiate the Parallel-to-Serial converter
  parallel_2_serial u_parallel_2_serial (
      .filtered_data(filtered_data),  // The 16-bit data to send
      .filter_done  (x_valid),
      .rpi_sck      (rp2350_sck),
      .rpi_cs       (rpi_cs),
      .rpi_miso     (rpi_miso)       // The physical serial output pin (Master Out)
  );
  assign rpi_sck = rp2350_sck;  // Directly connect clock
  assign test_sck = rp2350_sck;

endmodule

