`timescale 1ns/1ps

module tb_top;

import uvm_pkg::*;
import i2c_pkg::*;

///////////////////////////////////////////////////////////
// CLOCK
///////////////////////////////////////////////////////////

logic clk;

initial
begin
   clk = 0;
end

always #5 clk = ~clk;

///////////////////////////////////////////////////////////
// INTERFACE
///////////////////////////////////////////////////////////

i2c_if vif();

assign vif.clk = clk;

///////////////////////////////////////////////////////////
// DUT
///////////////////////////////////////////////////////////

i2c_master DUT
(
   .clk        (vif.clk),
   .rst        (vif.rst),

   .start      (vif.start),
   .rw         (vif.rw),

   .slave_addr (vif.slave_addr),
   .wr_data    (vif.wr_data),

   .rd_data    (vif.rd_data),

   .busy       (vif.busy),
   .done       (vif.done),

   .ack_error  (vif.ack_error),

   .scl        (vif.scl),

   .sda_out    (vif.sda_out),
   .sda_oe     (vif.sda_oe),
   .sda_in     (vif.sda)
);

///////////////////////////////////////////////////////////
// SIMPLE I2C SLAVE MODEL
///////////////////////////////////////////////////////////

initial
begin

   vif.slave_sda_out = 1'b1;
   vif.slave_sda_oe  = 1'b0;

end

///////////////////////////////////////////////////////////
// ACK GENERATION
///////////////////////////////////////////////////////////

always @(negedge vif.scl)
begin

   if(vif.busy)
   begin

      vif.slave_sda_out <= 1'b0;
      vif.slave_sda_oe  <= 1'b1;

      #20;

      vif.slave_sda_oe <= 1'b0;

   end

end

///////////////////////////////////////////////////////////
// READ DATA GENERATION
///////////////////////////////////////////////////////////

always @(posedge vif.busy)
begin

   if(vif.rw)
   begin

      force vif.rd_data = 8'h3C;

      #200;

      release vif.rd_data;

   end

end

///////////////////////////////////////////////////////////
// CONFIG DB
///////////////////////////////////////////////////////////

initial
begin

   uvm_config_db#
   (
      virtual i2c_if
   )::set
   (
      null,
      "*",
      "vif",
      vif
   );

   run_test("i2c_test");

end

///////////////////////////////////////////////////////////
// RESET
///////////////////////////////////////////////////////////

initial
begin

   vif.rst = 1'b1;

   vif.start = 0;

   vif.rw = 0;

   vif.slave_addr = 7'h00;

   vif.wr_data = 8'h00;

   #100;

   vif.rst = 0;

end

///////////////////////////////////////////////////////////
// DEBUG
///////////////////////////////////////////////////////////

initial
begin

   $display("-------------------------------------");
   $display(" I2C UVM TEST STARTED ");
   $display("-------------------------------------");

end

endmodule
