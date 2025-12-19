// -----------------------------------------------------------------------------
// Module: serial_2_parallel (Deserializer)
// Function: Converts SPI MISO stream (16 bits, Low Byte first) into a parallel word.
// Output: Corrected Big-Endian (High Byte | Low Byte) 16-bit data.
// -----------------------------------------------------------------------------
module serial_2_parallel (
    input logic rp2350_sck,  // SPI Clock: All operations are synchronized to the rising edge.
    input logic rp2350_cs,   // Chip Select: Active Low signal controlling the transaction state.
    input logic rp2350_miso, // SPI Data In: Serial data line from the sensor (ISM330DHCX SDO).

    output logic [15:0] data_out,  // Output Register: 16-bit parallel data for the filter logic (signed, big-endian).
    output logic        data_ready     // Output Pulse: High for one rp2350_sck cycle when data_out is stable (after 16 bits).
);

  // -------------------------------------------------------------------------
  // Internal Registers
  // -------------------------------------------------------------------------
  logic [15:0] shift_reg;  // 16-bit shift register to capture the serial stream.
  logic [ 4:0] bit_count;  // Counter (0-16) to track the 16 bits of a word.

  // -------------------------------------------------------------------------
  // Data Ready Logic
  // -------------------------------------------------------------------------
  // data_ready is high exactly when the 16th bit has just been shifted in.
  // This creates a clean one-cycle pulse that downstream logic can use.
  assign data_ready = (bit_count == 4'b1111);

  // -------------------------------------------------------------------------
  // Sequential Logic (Synchronous Block)
  // -------------------------------------------------------------------------
  always_ff @(posedge rp2350_sck) begin
    if (rp2350_cs || bit_count == 4'b1111) begin  // CS HIGH = inactive/idle
      bit_count <= 5'd0;  // Reset counter for the next transaction
      shift_reg <= 16'd0;  // Optional: clear shift register (helps simulation)
    end else begin  // CS LOW = active SPI transaction
      // 1. Shift Data In
      // Shift left, insert new bit at LSB (bit 0).
      // This is MSB-first reception (standard for ISM330DHCX).
      shift_reg <= {shift_reg[14:0], rp2350_miso};

      // 2. Increment bit counter
      bit_count <= bit_count + 1'b1;

      // 3. Final Latch and Byte Swap
      // When the 16th bit (count == 15 → next cycle count == 16) is being received:
      //   - Low byte  (first received) is now in shift_reg[15:8]
      //   - High byte (second received) is now in shift_reg[7:0]
      // We swap them to produce a normal big-endian signed integer.
      if (bit_count == 5'd15) begin
        data_out <= {shift_reg[7:0], shift_reg[15:8]};
      end
    end
  end

endmodule

