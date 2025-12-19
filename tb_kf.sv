`timescale 1ns / 1ps

module tb;

  // -------------------------------------------------------------------------
  // Signal Declarations
  // -------------------------------------------------------------------------
  logic               clk;
  logic               reset_n;
  logic signed [15:0] z;  // Noisy Measurement
  logic               z_valid;
  logic signed [15:0] x;  // Filtered Output
  logic               x_valid;

  // Simulation variables
  integer             file_handle;
  logic signed [15:0] true_value;
  logic signed [15:0] noise;
  int                 i;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  kalman_filter u_dut (
      .clk    (clk),
      .reset_n(reset_n),
      .z      (z),
      .z_valid(z_valid),
      .x      (x),
      .x_valid(x_valid)
  );

  // -------------------------------------------------------------------------
  // Clock Generation (100MHz)
  // -------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // -------------------------------------------------------------------------
  // Stimulus and Verification
  // -------------------------------------------------------------------------
  initial begin
    // 1. Initialize
    reset_n = 0;
    z = 0;
    z_valid = 0;
    true_value = 0;

    // Open CSV file for logging
    file_handle = $fopen("kalman_data.csv", "w");
    $fwrite(file_handle, "Time,TrueValue,Measured_Z,Filtered_X\n");

    // 2. Apply Reset
    #50;
    @(posedge clk);
    reset_n = 1;
    $display("--- Simulation Start ---");

    // 3. Loop: Zero value with noise (Iterations 0 to 49)
    // This checks if the filter stays near 0 despite noise
    true_value = 16'sd0;
    run_simulation_steps(50);

    // 4. Loop: Step response (Iterations 50 to 199)
    // Jump to 1000. Checks convergence speed.
    true_value = 16'sd1000;
    run_simulation_steps(150);

    // 5. Loop: Negative Step response (Iterations 200 to 300)
    // Jump to -500. Checks signed arithmetic handling.
    true_value = -16'sd500;
    run_simulation_steps(100);

    $display("--- Simulation Done. Results saved to kalman_data.csv ---");
    $fclose(file_handle);
    $finish;
  end

  // -------------------------------------------------------------------------
  // Task to run simulation cycles
  // -------------------------------------------------------------------------
  task run_simulation_steps(input int steps);
    begin
      for (i = 0; i < steps; i++) begin
        @(posedge clk);

        // Generate simple noise roughly within +/- 100 range
        // Note: $urandom returns unsigned, so we cast and mask carefully
        // Subtracting 100 centers the noise around 0.
        noise = $signed($urandom_range(200)) - 16'sd100;

        // Drive Measurement
        z <= true_value + noise;
        z_valid <= 1'b1;

        @(posedge clk);
        z_valid <= 1'b0;

        // Wait for Output Valid
        wait (x_valid);

        // Log to CSV
        $fwrite(file_handle, "%0t,%0d,%0d,%0d\n", $time, true_value, z, x);

        // Optional: Print to console every 50 steps
        if (i % 50 == 0) begin
          $display("Time: %0t | True: %d | Z (Noisy): %d | X (Filtered): %d", $time, true_value, z,
                   x);
        end

        // Add some idle time between samples to simulate real data rates
        repeat (5) @(posedge clk);
      end
    end
  endtask

endmodule
