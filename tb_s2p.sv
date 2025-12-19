`timescale 1ns / 1ps

module tb ();
  // Test Signals
  logic sim_miso;
  logic sim_mosi;
  logic sim_sck;
  logic sim_cs;
  logic [15:0] result;
  logic is_valid;

  serial_2_parallel uut (
      .rp2350_miso(sim_miso),
      .rp2350_sck(sim_sck),
      .rp2350_cs(sim_cs),
      .data_out(result),
      .data_ready(is_valid)
  );

  // Test stimulus generation tasks
  task send_spi_word(input logic [15:0] data);
    logic [15:0] bit_stream;
    integer i;
    begin
      bit_stream = data;
      $display("Sending SPI word: 0x%04X (0b%b)", data, data);

      // Start transaction: CS goes low
      sim_cs = 1'b0;
      #20;  // Setup time

      // Send 16 bits, MSB first
      for (i = 15; i >= 0; i--) begin
        sim_miso = bit_stream[i];

        // Toggle clock
        sim_sck  = 1'b1;
        #50;  // Half-period = 50ns (clock = 20MHz)
        sim_sck = 1'b0;
        #50;
        $display("  Clock cycle %2d: MISO = %b, Output = 0x%04X (0b%b), data ready? %b", 15 - i,
                 bit_stream[i], result, result, is_valid);
      end

      // End transaction: CS goes high
      #20;
      sim_cs = 1'b1;
      #20;
      $display("Output = 0x%04X (0b%b), data ready? %b", result, result, is_valid);
    end
  endtask

  initial begin
    $dumpfile("tb_s2p.vcd");
    $dumpvars(0, tb);
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
    sim_miso = 1'b0;
    sim_mosi = 1'b0;
    sim_sck  = 1'b0;
    sim_cs   = 1'b1;

    #100;

    // ==============================================
    // Test 2: Single SPI Word Transaction (0x1234)
    // ==============================================
    $display("[TEST 2] SPI Serial-to-Parallel Conversion");
    $display(
        "╔══════════════════════════════════════════════════════════╗");
    $display("║  Expected: 16 bits shifted in, data_ready pulse on 16th  ║");
    $display("║         data_out stabilizes with bit-swapped data        ║");
    $display(
        "╚══════════════════════════════════════════════════════════╝");
    $display("Sending 16-bit word: 0x1234 (binary: 0001_0010_0011_0100)");
    $display("Expected data_out: 0x3412 (bytes swapped for big-endian)\n");

    send_spi_word(16'h1234);

    $display("Sending 16-bit word: 0x5678 (binary: 0101'01010'0111'1000)");
    $display("Expected data_out: 0x7856 (bytes swapped for big-endian)\n");
    send_spi_word(16'h5678);

    #200;  // Allow deserializer to process
    $display("Transaction complete. Check waveform for data_out and data_ready pulse.\n");

    $dumpflush;  // Flush VCD to disk
    $finish;     // End simulation properly

  end
endmodule

