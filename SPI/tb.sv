
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import spi_uvm_pkg::*;

module tb;

    // ----------------------------------------------------------
    //  Clock ? 10 ns period (100 MHz)
    // ----------------------------------------------------------
    logic clk;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------
    //  Interface
    // ----------------------------------------------------------
    spi_if dut_if (.clk(clk));

    // ----------------------------------------------------------
    //  DUT : SPI Master
    // ----------------------------------------------------------
    spi_master u_master (
        .clk         (clk),
        .rst_n       (dut_if.rst_n),
        .start       (dut_if.start),
        .data_in     (dut_if.master_data_in),
        .CPOL        (dut_if.CPOL),
        .CPHA        (dut_if.CPHA),
        .SCLK        (dut_if.SCLK),
        .MOSI        (dut_if.MOSI),
        .SS_n        (dut_if.SS_n),
        .MISO        (dut_if.MISO),
        .done        (dut_if.done),
        .data_out    (dut_if.master_data_out)
    );

    // ----------------------------------------------------------
    //  DUT : SPI Slave
    // ----------------------------------------------------------
    spi_slave u_slave (
        .SCLK        (dut_if.SCLK),
        .SS_n        (dut_if.SS_n),
        .MOSI        (dut_if.MOSI),
        .MISO        (dut_if.MISO),
        .CPOL        (dut_if.CPOL),
        .CPHA        (dut_if.CPHA),
        .data_in     (dut_if.slave_data_in),
        .data_out    (dut_if.slave_data_out)
    );

    // ----------------------------------------------------------
    //  UVM config_db ? publish virtual interfaces
    // ----------------------------------------------------------
    initial begin
        // Driver gets the driver clocking-block modport
        uvm_config_db #(virtual spi_if.drv_mp)::set(
            null,
            "uvm_test_top.env.agent.drv",
            "vif",
            dut_if.drv_mp);

        // Monitor gets the monitor clocking-block modport
        uvm_config_db #(virtual spi_if.mon_mp)::set(
            null,
            "uvm_test_top.env.agent.mon",
            "vif",
            dut_if.mon_mp);

        // Select test via +UVM_TESTNAME on command line
        run_test();
    end

    // ----------------------------------------------------------
    //  Simulation timeout safety net (10 µs)
    // ----------------------------------------------------------
    initial begin
        #10_000_000;
        `uvm_fatal("SIM_TIMEOUT",
            "Simulation exceeded 10 µs ? check for hung transactions")
    end

    // ----------------------------------------------------------
    //  Optional VCD dump  (+define+DUMP_VCD)
    // ----------------------------------------------------------
`ifdef DUMP_VCD
    initial begin
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, tb_top);
    end
`endif

endmodule : tb
