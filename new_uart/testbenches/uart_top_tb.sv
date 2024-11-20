`timescale 1ns / 1ps

module uart_top_tb;

    // Testbench parameters
    localparam SYS_CLK_KHZ = 100_000;    // 100 MHz System clock
    localparam BAUD_RATE_HZ = 9600;      // 9600 Baud rate
    localparam OVER_SAMPLING = 16;       // Oversampling factor
    localparam PARITY_BIT_LENGTH = 0;    // 1 for parity bit
    localparam STOP_BIT_LENGTH = 1;      // 1 stop bit
    localparam DATA_FRAME_LENGTH = 8;    // 8 data bits (standard UART)
    
    // Derived parameters
    localparam BIT_PERIOD_NS = (1000000 / BAUD_RATE_HZ) * 1000;  // 104,167 ns for 9600 baud
    localparam DATA_BITS_DELAY = BIT_PERIOD_NS * (PARITY_BIT_LENGTH + STOP_BIT_LENGTH + DATA_FRAME_LENGTH + 2);
    localparam integer TOLERANCE_NS = BIT_PERIOD_NS / 100;       // ±1% of baud rate

    // Testbench signals for DUTs
    reg dut_1_clk, dut_2_clk;
    reg [DATA_FRAME_LENGTH-1:0] dut_1_tx_data, dut_2_tx_data;
    reg dut_1_tx_data_en, dut_1_rx_data_en;
    reg dut_2_tx_data_en, dut_2_rx_data_en;
    wire dut_1_tx, dut_2_tx;
    wire [DATA_FRAME_LENGTH-1:0] dut_1_rx_data, dut_2_rx_data;
    wire dut_1_tx_data_done, dut_2_tx_data_done;
    wire dut_1_rx_data_done, dut_2_rx_data_done;
    wire dut_1_parity_err, dut_2_parity_err;

    // Instantiate DUTs
    uart_top #(
        .SYS_CLK_KHZ(SYS_CLK_KHZ),
        .BAUD_RATE_HZ(BAUD_RATE_HZ),
        .OVER_SAMPLING(OVER_SAMPLING),
        .PARITY_BIT_LENGTH(PARITY_BIT_LENGTH),
        .STOP_BIT_LENGTH(STOP_BIT_LENGTH),
        .DATA_FRAME_LENGTH(DATA_FRAME_LENGTH)
    ) DUT_1 (
        .clk(dut_1_clk),
        .tx(dut_1_tx),
        .rx(dut_2_tx),
        .tx_data(dut_1_tx_data),
        .rx_data(dut_1_rx_data),
        .tx_data_en(dut_1_tx_data_en),
        .tx_data_done(dut_1_tx_data_done),
        .rx_data_en(dut_1_rx_data_en),
        .rx_data_done(dut_1_rx_data_done),
        .parity_err(dut_1_parity_err)
    );

    uart_top #(
        .SYS_CLK_KHZ(SYS_CLK_KHZ),
        .BAUD_RATE_HZ(BAUD_RATE_HZ + 60),
        .OVER_SAMPLING(OVER_SAMPLING),
        .PARITY_BIT_LENGTH(PARITY_BIT_LENGTH),
        .STOP_BIT_LENGTH(STOP_BIT_LENGTH),
        .DATA_FRAME_LENGTH(DATA_FRAME_LENGTH)
    ) DUT_2 (
        .clk(dut_2_clk),
        .tx(dut_2_tx),
        .rx(dut_1_tx),
        .tx_data(dut_2_tx_data),
        .rx_data(dut_2_rx_data),
        .tx_data_en(dut_2_tx_data_en),
        .tx_data_done(dut_2_tx_data_done),
        .rx_data_en(dut_2_rx_data_en),
        .rx_data_done(dut_2_rx_data_done),
        .parity_err(dut_2_parity_err)
    );

    // Generate 100 MHz clocks for DUTs
    always #5 dut_1_clk = ~dut_1_clk;
    always #5 dut_2_clk = ~dut_2_clk;

    // Tasks for reusable operations
    task check_signal_within_tolerance(
        input logic signal,
        input string signal_name
    );
        automatic int timeout = 0;
        while (!signal && (timeout < TOLERANCE_NS)) begin
            timeout += 1;
            #1;
        end
        if (!signal) begin
            $fatal("Error: %s did not assert within tolerance (%0d ns).", signal_name, TOLERANCE_NS);
        end
    endtask

    task check_data(
        input [DATA_FRAME_LENGTH-1:0] expected_data,
        input [DATA_FRAME_LENGTH-1:0] received_data
    );
        if (expected_data !== received_data) begin
            $fatal("Error: Data mismatch. Expected: %b, Got: %b", expected_data, received_data);
        end
    endtask

    task check_parity_error(input logic parity_err);
        if (parity_err) begin
            $fatal("Error: Parity error detected.");
        end
    endtask

    //  // Generic clock generation procedure
    // task generate_clk(
    //     input clk_frequency_khz, // Clock frequency in KHz
    //     output reg clk_signal
    // );
    //     integer period_ns;
    //     begin
    //         period_ns = 1000000 / clk_frequency_khz; // Convert frequency to period in ns
    //         forever begin
    //             #period_ns clk_signal = ~clk_signal;  // Toggle clock signal every half period
    //         end
    //     end
    // endtask

    // // Generate the system clocks for dut_1 and dut_2
    // initial begin
    //     dut_1_clk = 0;
    //     dut_2_clk = 0;
    //     generate_clk(SYS_CLK_KHZ, dut_1_clk);  // Generate clock for DUT_1
    //     generate_clk(SYS_CLK_KHZ, dut_2_clk);  // Generate clock for DUT_2
    // end

    // Test Cases
    initial begin
        // Initialize signals
        dut_1_clk = 0; dut_2_clk = 0;
        dut_1_tx_data = 8'b10101011; dut_2_tx_data = 8'b11001100;
        dut_1_tx_data_en = 0; dut_2_tx_data_en = 0;
        dut_1_rx_data_en = 0; dut_2_rx_data_en = 0;

        // Test Case 1: DUT_1 sends data to DUT_2
        #10;
        dut_1_tx_data_en = 1;
        dut_2_rx_data_en = 1;
        #BIT_PERIOD_NS;
        dut_1_tx_data_en = 0;
        dut_2_rx_data_en = 0;

        #(DATA_BITS_DELAY - (1 * BIT_PERIOD_NS));
        check_signal_within_tolerance(dut_2_rx_data_done, "dut_2_rx_data_done");
        check_data(dut_1_tx_data, dut_2_rx_data);
        check_parity_error(dut_2_parity_err);

        $display("Test Case 1 Passed: DUT_1 sent data successfully to DUT_2.");

        // Test Case 2: DUT_2 sends data to DUT_1
        #BIT_PERIOD_NS;
        dut_2_tx_data_en = 1;
        dut_1_rx_data_en = 1;
        #BIT_PERIOD_NS;
        dut_2_tx_data_en = 0;
        dut_1_rx_data_en = 0;

        #(DATA_BITS_DELAY - (1 * BIT_PERIOD_NS));
        check_signal_within_tolerance(dut_1_rx_data_done, "dut_1_rx_data_done");
        check_data(dut_2_tx_data, dut_1_rx_data);
        check_parity_error(dut_1_parity_err);

        $display("Test Case 2 Passed: DUT_2 sent data successfully to DUT_1.");

        // End simulation
        #DATA_BITS_DELAY;
        $display("All test cases passed successfully.");
        $stop;
    end

    // Monitor signals for debugging
    initial begin
        $monitor("Time: %0t | DUT_1 tx: %b | DUT_2 tx: %b | DUT_1 rx: %b | DUT_2 rx: %b",
                 $time, dut_1_tx, dut_2_tx, dut_1_rx_data, dut_2_rx_data);
    end

endmodule
