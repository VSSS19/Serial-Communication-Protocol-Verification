`timescale 1ns/1ps

module tb_top;

import uvm_pkg::*;
import uart_pkg::*;

logic clk = 0;

always #5 clk = ~clk;

uart_if vif(clk);

uart_tx DUT
(
    .clk(clk),
    .rst(vif.rst),

    .tx_start(vif.tx_start),
    .tx_data(vif.tx_data),

    .tx(vif.tx),
    .tx_busy(vif.tx_busy)
);

initial
begin

    uvm_config_db#
    (virtual uart_if)::set
    (null,"*","vif",vif);

    run_test("uart_test");

end

initial
begin

    vif.rst = 1;

    vif.tx_start = 0;
    vif.tx_data = 0;

    #50;

    vif.rst = 0;

end

endmodule
