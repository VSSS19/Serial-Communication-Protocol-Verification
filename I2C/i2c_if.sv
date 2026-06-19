interface i2c_if;
   logic clk;
   logic rst;
   logic start;
   logic rw;
   logic [6:0] slave_addr;
   logic [7:0] wr_data;
   logic [7:0] rd_data;
   logic busy;
   logic done;
   logic ack_error;
   logic scl;
   wire sda;
   logic sda_out;
   logic sda_oe;
   logic slave_sda_out;
   logic slave_sda_oe;

   assign sda =
      (sda_oe == 1'b1) ?
      sda_out :
      ((slave_sda_oe == 1'b1) ?
      slave_sda_out :
      1'bz);

   clocking drv_cb @(posedge clk);
      output start;
      output rw;
      output slave_addr;
      output wr_data;
      input busy;
      input done;
      input rd_data;
      input ack_error;
   endclocking

   clocking mon_cb @(posedge clk);
      input start;
      input rw;
      input slave_addr;
      input wr_data;
      input rd_data;
      input busy;
      input done;
      input ack_error;
      input scl;
      input sda;
   endclocking

   modport DRIVER
   (
      clocking drv_cb,
      input clk,
      input rst
   );

   modport MONITOR
   (
      clocking mon_cb,
      input clk,
      input rst
   );
endinterface
