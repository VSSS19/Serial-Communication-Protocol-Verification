// ============================================================
//  spi_if.sv  ?  SPI SystemVerilog Interface
// ============================================================
`timescale 1ns/1ps

interface spi_if (input logic clk);

    logic        rst_n;
    logic        start;
    logic [7:0]  master_data_in;
    logic        CPOL;
    logic        CPHA;

    logic        SCLK;
    logic        MOSI;
    logic        SS_n;
    logic        MISO;

    logic        done;
    logic [7:0]  master_data_out;

    logic [7:0]  slave_data_in;
    logic [7:0]  slave_data_out;

    // ----------------------------------------------------------
    //  Clocking blocks
    // ----------------------------------------------------------
    clocking driver_cb @(posedge clk);
        default input  #1step;
        default output #1ns;
        output rst_n;
        output start;
        output master_data_in;
        output CPOL;
        output CPHA;
        output slave_data_in;
        input  done;
        input  master_data_out;
        input  slave_data_out;
        input  SCLK;
        input  SS_n;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n;
        input start;
        input master_data_in;
        input CPOL;
        input CPHA;
        input slave_data_in;
        input done;
        input master_data_out;
        input slave_data_out;
        input SCLK;
        input MOSI;
        input SS_n;
        input MISO;
    endclocking

    modport drv_mp (clocking driver_cb,  import task wait_clks(int n));
    modport mon_mp (clocking monitor_cb, import task wait_clks(int n));

    task automatic wait_clks(int n);
        repeat(n) @(posedge clk);
    endtask

endinterface : spi_if
