// -----------------------------------------------------------------------------
// Module: fpga_logic
// Description: Placeholder for custom logic processing.
//              Currently acts as a direct wire (Passthrough).
// Inputs:      raw_data_in (Serial bitstream from sensor)
// Outputs:     filtered_data_out (Processed bitstream)
// -----------------------------------------------------------------------------

module fpga_logic (
    input  logic raw_data_in,
    input  logic spi_sck,      // SPI clock
    input  logic spi_cs,       // SPI chip select
    input  logic spi_miso,     // SPI MISO

    output logic filtered_data_out,
    output logic led_blue_n
);

    // Internal wire for the parallel input data
    logic [15:0] raw_sensor_data;
    logic        input_valid_pulse;

    // Instantiate the deserializer
    serial_2_parallel u_serial_2_parallel (
        .spi_sck      (spi_sck),      // Physical Pin
        .spi_cs       (spi_cs),       // Physical Pin
        .spi_miso     (spi_miso),     // Physical Pin
        .Filter_Input (raw_sensor_data), // Parallel output wire
        .data_ready   (input_valid_pulse) // Valid parallel data input to FPGA indicator
    );

    assign led_blue_n = ~input_valid_pulse; //LED indicator of successful serial to parallel conversion

    //Internal wire for the serial output data
    logic [15:0] filtered_data;
    logic        filter_output_ready; 
    
    // Connect deserialized data to serializer (passthrough for now)
    assign filtered_data = raw_sensor_data;
    
    // Instantiate the Parallel-to-Serial converter
    parallel_2_serial u_parallel_2_serial (
        .spi_sck             (spi_sck),             // Connect to the shared clock
        .filtered_data       (filtered_data),       // The 16-bit data to send
        .Filter_Output       (filtered_data_out)             // The physical serial output pin (Master Out)
    );

    // TODO: Insert your Kalman Filter or custom logic here later with output of "Filter_Output".

    // For testing, we simply relay the signal unchanged.
    // assign filtered_data_out = raw_data_in;         // Direct Passthrough

    //assign filtered_data_out = Filter_Output;

endmodule