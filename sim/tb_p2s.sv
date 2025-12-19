// -----------------------------------------------------------------------------
// Module: tb
// Description: Comprehensive testbench for ENGR433 Kalman filter FPGA project's accessory modules.
//              Tests serial-to-parallel, parallel-to-serial, and signal routing
//              Simulates ISM330DHCX accelerometer SPI protocol (16-bit MSB-first)
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb;

  // Test Signals
  logic sim_miso;
  logic sim_sck;
  logic sim_cs;

  // Outputs to Monitor
  logic [15:0] z;
  logic z_valid;
  logic [15:0] x;
  logic x_valid;

  // Test result tracking
  integer test_count = 0;
  integer fail_count = 0;
  string failed_tests[64];  // Array to store failed test names

  parallel_2_serial uut (
      .filtered_data(x),
      .filter_done(x_valid),
      .rpi_sck(sim_sck),
      .rpi_cs(sim_cs),
      .rpi_miso(sim_miso)
  );

  // Test stimulus generation tasks
  task send_spi_word(input logic [15:0] data);
    logic [15:0] bit_stream;
    integer i;
    begin
      x = data;
      x_valid = 1'b1;
      #100;
      $display("Sending SPI word: 0x%04X (0b%b)", data, data);

      // Start transaction: CS goes low
      sim_cs = 1'b0;
      #20;  // Setup time

      // Send 16 bits, MSB first
      for (i = 15; i >= 0; i--) begin
        bit_stream[i] = sim_miso;
        $display("  Clock cycle %2d: MISO = %b", 15 - i, bit_stream[i]);

        // Toggle clock
        sim_sck = 1'b1;
        #50;  // Half-period = 50ns (clock = 20MHz)
        sim_sck = 1'b0;
        #50;
      end

      // End transaction: CS goes high
      #20;
      sim_cs = 1'b1;
      #20;
    end
  endtask

  initial begin
    // ==============================================
    // TEST SUITE: ENGR433 FPGA Project
    // ==============================================
    $display("\n");
    $display(
        "╔═══════════════════════════════════════════════════════════╗");
    $display("║   ENGR433 Final Project - FPGA Interface Module Testbench ║");
    $display("║   Testing: ISM330DHCX SPI Interface & Data Pipeline       ║");
    $display(
        "╚═══════════════════════════════════════════════════════════╝");
    $display("\n");

    // Initialize
    sim_sck  = 1'b0;
    sim_cs   = 1'b1;

    #100;

    // ==============================================
    // Test 2: Single SPI Word Transaction (0x1234)
    // ==============================================
    $display("[TEST 2] SPI Parallel-to-Serial Conversion");
    $display(
        "╔══════════════════════════════════════════════════════════╗");
    $display("║ Expected: 16 bits shifted in, data_ready pulse on 16th  ║");
    $display("║           Filter_Input stabilizes with bit-swapped data ║");
    $display(
        "╚══════════════════════════════════════════════════════════╝");
    $display("Sending 16-bit word: 0x1234 (binary: 0001_0010_0011_0100)");
    $display("Expected Filter_Input: 0x3412 \n");

    send_spi_word(16'h1234);

    $display("Sending 16-bit word: 0x5678 (binary: 0101'0110'0111'1000)");
    $display("Expected Filter_Input: 0x5678 \n");

    send_spi_word(16'h5678);

    #200;  // Allow deserializer to process
    $display("Transaction complete. Check waveform for Filter_Input and data_ready pulse.\n");

  end
endmodule
