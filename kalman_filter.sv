module kalman_filter (
    input  wire logic signed [15:0] z,        // Measurement input
    input  wire logic               z_valid,  // Valid signal for z
    output logic signed      [15:0] x,        // Filtered state output
    output logic                    x_valid   // Valid signal for x
);

  // -------------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------------
  // Calculated Steady State Gain K = 0.4232 from Ricatti equation
  // Represented in Q1.15 format (1.0 = 32768)
  // K_FIXED = 0.4232 * 32768 = 13868
  localparam signed [15:0] K_FIXED = 16'sd13868;

  // -------------------------------------------------------------------------
  // Internal Signals
  // -------------------------------------------------------------------------
  logic signed [15:0] x_reg = 0;
  logic signed [16:0] error;  // 17 bits to handle overflow of (z - x)
  logic signed [31:0] product;  // 32 bits for (17-bit * 16-bit)
  logic signed [15:0] correction;

  // -------------------------------------------------------------------------
  // Update Logic
  // -------------------------------------------------------------------------
  always @(posedge z_valid) begin
    x_valid <= 1'b0;

    // 1. Calculate the residual (innovation): z - x
    // We expand to 17 bits to prevent overflow during subtraction 
    // (e.g., if z is Max positive and x is Max negative)
    error = {z[15], z} - {x_reg[15], x_reg};

    // 2. Calculate Correction: K * error
    // Result is Q1.15 (from K) * Q16.0 (from error) = Q17.15
    product = error * K_FIXED;

    // 3. Normalize: Shift right by 15 to get back to integer/Q0 scale
    // We assume the LSBs dropped are noise. 
    // >>> is arithmetic shift (preserves sign)
    correction = product >>> 15;

    // 4. Update State: x = x + correction
    x_reg   <= x_reg + correction;

    // Assert valid output
    x_valid <= 1'b1;
  end

  // Assign output
  assign x = x_reg;

endmodule
