package i2c_pkg;

import uvm_pkg::*;
`include "uvm_macros.svh"

////////////////////////////////////////////////////////////
// TRANSACTION
////////////////////////////////////////////////////////////

class i2c_txn extends uvm_sequence_item;

   rand bit rw;

   rand bit [6:0] slave_addr;

   rand bit [7:0] wr_data;

   bit [7:0] rd_data;

   bit ack_error;

   `uvm_object_utils_begin(i2c_txn)

      `uvm_field_int(rw,UVM_ALL_ON)
      `uvm_field_int(slave_addr,UVM_ALL_ON)
      `uvm_field_int(wr_data,UVM_ALL_ON)
      `uvm_field_int(rd_data,UVM_ALL_ON)
      `uvm_field_int(ack_error,UVM_ALL_ON)

   `uvm_object_utils_end

   function new(string name="i2c_txn");
      super.new(name);
   endfunction

endclass

////////////////////////////////////////////////////////////
// SEQUENCE
////////////////////////////////////////////////////////////

class i2c_sequence extends uvm_sequence #(i2c_txn);

   `uvm_object_utils(i2c_sequence)

   function new(string name="i2c_sequence");
      super.new(name);
   endfunction

   task body();

      repeat(20)
      begin

         i2c_txn tx;

         tx = i2c_txn::type_id::create("tx");

         start_item(tx);

         assert(tx.randomize());

         finish_item(tx);

      end

   endtask

endclass

////////////////////////////////////////////////////////////
// SEQUENCER
////////////////////////////////////////////////////////////

class i2c_sequencer extends uvm_sequencer #(i2c_txn);

   `uvm_component_utils(i2c_sequencer)

   function new(string name,
                uvm_component parent);

      super.new(name,parent);

   endfunction

endclass

////////////////////////////////////////////////////////////
// DRIVER
////////////////////////////////////////////////////////////

class i2c_driver extends uvm_driver #(i2c_txn);

   `uvm_component_utils(i2c_driver)

   virtual i2c_if vif;

   function new(string name,
                uvm_component parent);

      super.new(name,parent);

   endfunction

   function void build_phase(uvm_phase phase);

      super.build_phase(phase);

      if(!uvm_config_db#
         (virtual i2c_if)::get
         (this,"","vif",vif))
      begin

         `uvm_fatal("DRV",
         "INTERFACE NOT FOUND")

      end

   endfunction

   task run_phase(uvm_phase phase);

      i2c_txn tr;

      wait(vif.rst == 0);

      forever
      begin

         seq_item_port.get_next_item(tr);

         @(posedge vif.clk);

         vif.slave_addr <= tr.slave_addr;
         vif.rw         <= tr.rw;
         vif.wr_data    <= tr.wr_data;

         vif.start <= 1;

         @(posedge vif.clk);

         vif.start <= 0;

         wait(vif.done == 1);

         tr.rd_data   = vif.rd_data;
         tr.ack_error = vif.ack_error;

         if(tr.rw == 0)
         begin

            `uvm_info
            (
               "DRV",

               $sformatf
               (
                  "WRITE Addr=%0h Data=%0h AckErr=%0b",

                  tr.slave_addr,
                  tr.wr_data,
                  tr.ack_error
               ),

               UVM_LOW
            );

         end
         else
         begin

            `uvm_info
            (
               "DRV",

               $sformatf
               (
                  "READ Addr=%0h Data=%0h AckErr=%0b",

                  tr.slave_addr,
                  tr.rd_data,
                  tr.ack_error
               ),

               UVM_LOW
            );

         end

         seq_item_port.item_done();

      end

   endtask

endclass

////////////////////////////////////////////////////////////
// MONITOR
////////////////////////////////////////////////////////////

class i2c_monitor extends uvm_monitor;

   `uvm_component_utils(i2c_monitor)

   virtual i2c_if vif;

   uvm_analysis_port #(i2c_txn) ap;

   function new(string name,
                uvm_component parent);

      super.new(name,parent);

      ap = new("ap",this);

   endfunction

   function void build_phase(uvm_phase phase);

      if(!uvm_config_db#
         (virtual i2c_if)::get
         (this,"","vif",vif))
      begin

         `uvm_fatal("MON",
         "INTERFACE NOT FOUND")
      end

   endfunction

   task run_phase(uvm_phase phase);

      i2c_txn tx;

      forever
      begin

         @(posedge vif.start);

         tx =
         i2c_txn::type_id::create("tx");

         tx.slave_addr = vif.slave_addr;
         tx.rw         = vif.rw;
         tx.wr_data    = vif.wr_data;

         wait(vif.done == 1);

         tx.rd_data    = vif.rd_data;
         tx.ack_error  = vif.ack_error;

         ap.write(tx);

         if(tx.rw == 0)
         begin

            `uvm_info
            (
               "MON",

               $sformatf
               (
                  "WRITE Addr=%0h Data=%0h AckErr=%0b",

                  tx.slave_addr,
                  tx.wr_data,
                  tx.ack_error
               ),

               UVM_LOW
            );

         end
         else
         begin

            `uvm_info
            (
               "MON",

               $sformatf
               (
                  "READ Addr=%0h Data=%0h AckErr=%0b",

                  tx.slave_addr,
                  tx.rd_data,
                  tx.ack_error
               ),

               UVM_LOW
            );

         end

      end

   endtask

endclass

////////////////////////////////////////////////////////////
// SCOREBOARD
////////////////////////////////////////////////////////////

class i2c_scoreboard extends uvm_scoreboard;

   `uvm_component_utils(i2c_scoreboard)

   uvm_analysis_imp
   #(i2c_txn,i2c_scoreboard) imp;

   int total;
   int pass;
   int fail;

   function new(string name,
                uvm_component parent);

      super.new(name,parent);

      imp = new("imp",this);

   endfunction

   function void write(i2c_txn tx);

      total++;

      if(tx.ack_error == 0)
      begin

         pass++;

         `uvm_info
         (
            "SCB",

            $sformatf
            (
               "PASS Addr=%0h RW=%0b",

               tx.slave_addr,
               tx.rw
            ),

            UVM_LOW
         );

      end
      else
      begin

         fail++;

         `uvm_error
         (
            "SCB",

            $sformatf
            (
               "FAIL Addr=%0h",

               tx.slave_addr
            )
         );

      end

   endfunction

   function void report_phase(uvm_phase phase);

      `uvm_info
      (
         "SCB",

         $sformatf
         (
            "TOTAL=%0d PASS=%0d FAIL=%0d",

            total,
            pass,
            fail
         ),

         UVM_NONE
      );

   endfunction

endclass

////////////////////////////////////////////////////////////
// AGENT
////////////////////////////////////////////////////////////

class i2c_agent extends uvm_agent;

   `uvm_component_utils(i2c_agent)

   i2c_driver drv;
   i2c_monitor mon;
   i2c_sequencer seqr;

   function new(string name,
                uvm_component parent);

      super.new(name,parent);

   endfunction

   function void build_phase(uvm_phase phase);

      drv =
      i2c_driver::type_id::create
      ("drv",this);

      mon =
      i2c_monitor::type_id::create
      ("mon",this);

      seqr =
      i2c_sequencer::type_id::create
      ("seqr",this);

   endfunction

   function void connect_phase
      (uvm_phase phase);

      drv.seq_item_port.connect
      (seqr.seq_item_export);

   endfunction

endclass

////////////////////////////////////////////////////////////
// ENVIRONMENT
////////////////////////////////////////////////////////////

class i2c_env extends uvm_env;

   `uvm_component_utils(i2c_env)

   i2c_agent agt;
   i2c_scoreboard scb;

   function new(string name,
                uvm_component parent);

      super.new(name,parent);

   endfunction

   function void build_phase(uvm_phase phase);

      agt =
      i2c_agent::type_id::create
      ("agt",this);

      scb =
      i2c_scoreboard::type_id::create
      ("scb",this);

   endfunction

   function void connect_phase
      (uvm_phase phase);

      agt.mon.ap.connect
      (scb.imp);

   endfunction

endclass

////////////////////////////////////////////////////////////
// TEST
////////////////////////////////////////////////////////////

class i2c_test extends uvm_test;

   `uvm_component_utils(i2c_test)

   i2c_env env;

   function new(string name,
                uvm_component parent);

      super.new(name,parent);

   endfunction

   function void build_phase(uvm_phase phase);

      env =
      i2c_env::type_id::create
      ("env",this);

   endfunction

   task run_phase(uvm_phase phase);

      i2c_sequence seq;

      phase.raise_objection(this);

      seq =
      i2c_sequence::type_id::create
      ("seq");

      seq.start(env.agt.seqr);

      #10000;

      phase.drop_objection(this);

   endtask

endclass

endpackage
