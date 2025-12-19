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

`ifdef SIMULATION
    // For Testing Only
    output logic [15:0] z,  // Big endian data from Sensor
    output logic z_valid,
    output logic [15:0] posterior,  //Big endian filtered data
    output logic posterior_valid,
`endif

    // Outputs
    output logic rpi_miso,  // Pin 23: Post-Logic Output
    output logic rpi_cs,
    output logic rpi_sck
);
`ifndef SIMULATION
  logic [15:0] z;
  logic        z_valid;
`endif

  // Instantiate the deserializer
  serial_2_parallel u_serial_2_parallel (
      .rp2350_sck (rp2350_sck),   // Physical Pin
      .rp2350_cs  (rp2350_cs),    // Physical Pin
      .rp2350_miso(rp2350_miso),  // Physical Pin
      .data_out   (z),            // Parallel output wire
      .data_ready (z_valid)       // Valid parallel data input to FPGA indicator
  );

  //Internal wire for the serial output data
`ifndef SIMULATION
  logic [15:0] posterior;
  logic posterior_valid;
`endif

  kalman_filter kalman_filter (
      .clk(z_valid),
      .z_in(z),
      .x_out(posterior),
      .x_valid(posterior_valid)
  );

  // Instantiate the Parallel-to-Serial converter
  parallel_2_serial u_parallel_2_serial (
      .filtered_data(posterior),        // The 16-bit data to send
      .filter_done  (posterior_valid),
      .rpi_sck      (rpi_sck),
      .rpi_cs       (rpi_cs),
      .rpi_miso     (rpi_miso)          // The physical serial output pin (Master Out)
  );

endmodule

