// -----------------------------------------------------------------------------
// Module: parallel_2_serial (Triggered by CS, Data Handshaking)
// Description: Latches 16-bit filtered_data when filter_done is asserted.
//              Transmits latched data when rpi_cs goes low (if data is ready).
//              Sends 0xFFFF as a "waiting" signal if filter_done was not set.
//              Prevents duplicate transmissions via handshaking.
// Clock Domain: Driven by rpi_sck (from RP2350)
// -----------------------------------------------------------------------------
module parallel_2_serial (
    input  logic [15:0] filtered_data,        // Parallel data from Kalman filter
    input  logic        filter_done,          // Strobe: new filtered data is ready
    input  logic        rpi_sck,              // Serial clock from RP2350 (drives state machine)
    input  logic        rpi_cs,               // Chip Select from RP2350 (active low, triggers transmission)

    output logic        rpi_miso              // Serial output (MSB first, idle high)
);

    // Internal state machine and registers
    logic [15:0] latched_data;      // Holds filtered data when filter_done is asserted
    logic        data_available;    // Flag: new data has been latched and not yet transmitted
    logic [3:0]  tx_bit_count;      // Bit counter (0 to 15)
    logic [15:0] shift_reg;         // Shift register for serialization
    logic        cs_prev;           // Previous CS state for edge detection
    logic        transmitting;      // Flag: currently transmitting data

    // Output is MSB during transmission, idle high otherwise
    assign rpi_miso = shift_reg[15];

    always_ff @(posedge rpi_sck) begin
        // Edge detection: detect CS falling edge (1 to 0 transition)
        logic cs_falling_edge;
        cs_falling_edge = cs_prev & ~rpi_cs;
        cs_prev <= rpi_cs;

        // =========================================================================
        // PHASE 1: Latch data when filter_done is asserted
        // =========================================================================
        if (filter_done) begin
            latched_data <= filtered_data;   // Capture new filtered data in holding register
            if (!data_available) begin
                data_available <= 1'b1;      // Mark data as ready to send (only on first strobe)
            end
        end

        // =========================================================================
        // PHASE 2: Start transmission when CS goes low
        // =========================================================================
        if (cs_falling_edge) begin
            transmitting <= 1'b1;            // Begin transmission
            tx_bit_count <= 4'd0;            // Reset bit counter
            
            // Load shift register from latched data or 0xFFFF if waiting
            if (data_available) begin
                shift_reg <= latched_data;   // Load latched data for transmission
            end else begin
                shift_reg <= 16'hFFFF;       // Load waiting signal
            end
        end

        // =========================================================================
        // PHASE 3: Shift data out during transmission
        // =========================================================================
        if (transmitting && !rpi_cs) begin
            if (tx_bit_count < 4'd15) begin
                // Continue shifting: shift left, shift in 1 for idle high
                shift_reg <= {shift_reg[14:0], 1'b1};
                tx_bit_count <= tx_bit_count + 1;
            end else if (tx_bit_count == 4'd15) begin
                // Last bit transmitted
                shift_reg <= {shift_reg[14:0], 1'b1};   // Shift in 1 for idle
                tx_bit_count <= tx_bit_count + 1;
            end else begin
                // Transmission complete (count == 16)
                transmitting <= 1'b0;
                data_available <= 1'b0;     // Clear flag: data has been sent
            end
        end else if (transmitting && rpi_cs) begin
            // CS released during transmission - abort and clear data_available
            transmitting <= 1'b0;
            data_available <= 1'b0;         // Allow new data to be latched immediately
        end
    end

    // Optional: initialize to avoid X in simulation
    initial begin
        latched_data = 16'd0;
        data_available = 1'b0;
        tx_bit_count = 4'd0;
        shift_reg = 16'd0;
        cs_prev = 1'b1;
        transmitting = 1'b0;
    end

endmodule