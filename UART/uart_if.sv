interface uart_if(input logic clk);

    logic rst;

    logic tx_start;
    logic [7:0] tx_data;

    logic tx;
    logic tx_busy;

endinterface
