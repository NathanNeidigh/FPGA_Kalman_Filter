// -----------------------------------------------------------------------------
// Module: parallel_2_serial (Triggered by CS, Data Handshaking)
// Description: Latches 16-bit filtered_data when filter_done is asserted.
//              Transmits latched data when rpi_cs goes low (if data is ready).
//              Prevents duplicate transmissions via handshaking.
// Clock Domain: Driven by rpi_sck (from raspberry pi)
// -----------------------------------------------------------------------------
module parallel_2_serial (
    input logic [15:0] filtered_data,  // Parallel data from Kalman filter
    input logic filter_done,  // Strobe: new filtered data is ready
    input logic rpi_sck,  // Serial clock from RP2350 (drives state machine)
    input logic rpi_cs,  // Chip Select from RP2350 (active low, triggers transmission)

    output logic rpi_miso  // Serial output (MSB first, idle high)
);

  logic [15:0] shift_reg;  // Shift register for serialization

  // Output is MSB during transmission, idle high otherwise
  assign rpi_miso = shift_reg[15];

  always_comb begin
      if (rpi_cs && filter_done) begin
        shift_reg = filtered_data;
    end
  end

  always_ff @(negedge rpi_sck) begin
    if (!rpi_cs) begin
      shift_reg <= {shift_reg[14:0], shift_reg[15]};
    end
  end

  // Optional: initialize to avoid X in simulation
  initial begin
    shift_reg = 16'd0;
  end

endmodule

