
`include "bsg_defines.v"

  // Operations
  //   r_incr_i: Increment rcptr by 1
  //   r_rewind_i: Reset rptr to rcptr
  //   r_forward_i: Forward rcptr to rptr
  //   w_clear_i: Move wptr, wcptr to rptr, i.e., clear all the data
  // between rptr and wptr
  //   commit: Forward wcptr to wptr
  //   drop: Reset wptr to wcptr

  /* Operation Table */

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  // from\to  //  wptr    //  wptr+1  //  rptr    //  rptr+1  //  wcptr   //  rcptr   //  rcptr+1 //
  //          //          //          //          //          //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  wptr    //    -     //    -     //  clr     //  clr     //  drop    //    -     //    -     //
  //          //          //          //  (~deq)  //  (deq)   //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  rptr    //    -     //    -     //    -     //    -     //    -     // rollback // rollback //
  //          //          //          //          //          //          //  (~incr) //  (incr)  //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  wcptr   //  commit  //  commit  //  clr     //  clr     //    -     //    -     //    -     //
  //          //  (~enq)  //  (enq)   //  (~deq)  //  (deq)   //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  rcptr   //    -     //    -     //   ack    //    -     //    -     //    -     //    -     //
  //          //          //          //          //          //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////


module bsg_fifo_1r1w_rolly_hardened
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(lg_size_p)
    , parameter ready_THEN_valid_p = 0
    , localparam els_lp = (1 << lg_size_p)
    )
  (input                  clk_i
   , input                reset_i

   // read side
   , input                r_incr_i
   , input                r_rewind_i
   , input                r_forward_i
   , input                r_clear_i // new

   // write side
   , input                w_incr_i // new
   , input                w_rewind_i
   , input                w_forward_i
   , input                w_clear_i

   , input [width_p-1:0]  data_i
   , input                v_i
   , output               ready_o

   , output [width_p-1:0] data_o
   , output               v_o
   , input                yumi_i
   );

  // one read pointer, one write pointer
  logic [lg_size_p-1:0] rptr_r, wptr_r;
  // one read checkpoint pointer, one write checkpoint pointer
  logic [lg_size_p-1:0] rcptr_r, wcptr_r;
  logic                 full, empty;
  // rptr_n is one cycle earlier than rptr_r
  logic [lg_size_p-1:0] rptr_n;

  wire enq       = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire deq       = yumi_i;

  assign ready_o = ~w_clear_i & ~full;
  assign v_o     = ~r_rewind_i & ~empty;

  bsg_fifo_rolly_tracker
   #(.lg_size_p(lg_size_p))
   ft
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.enq_i(enq)
     ,.deq_i(deq)

     ,.wptr_r_o(wptr_r)
     ,.rptr_r_o(rptr_r)
     ,.wcptr_r_o(wcptr_r)
     ,.rcptr_r_o(rcptr_r)

     ,.rptr_n_o(rptr_n)
     ,.full_o(full)
     ,.empty_o(empty)
     ,.*
     );

  logic [width_p-1:0] data_o_mem, data_o_reg;
  logic read_write_same_addr_r, read_write_same_addr_n;

  bsg_mem_1r1w_sync
  #(.width_p(width_p)
    ,.els_p(els_lp)
    ,.read_write_same_addr_p(0)
    ,.disable_collision_warning_p(0)
    ,.harden_p(1))
  fifo_mem
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r)
    ,.w_data_i(data_i)
    ,.r_v_i(~read_write_same_addr_n)
    ,.r_addr_i(rptr_n)
    ,.r_data_o(data_o_mem)
    );

  bsg_dff_en
  #(.width_p(width_p))
  bypass_reg
   (.clk_i(clk_i)
    ,.data_i(data_i)
    ,.en_i  (read_write_same_addr_n)
    ,.data_o(data_o_reg)
    );

  assign read_write_same_addr_n = enq & (wptr_r == rptr_n);
  always_ff @(posedge clk_i)
    read_write_same_addr_r <= read_write_same_addr_n;
  assign data_o = (read_write_same_addr_r) ? data_o_reg : data_o_mem;

  // synopsys translate_off

//  assert property (@(posedge clk_i) (reset_i != 1'b0 ||
//        ~((r_rewind_i && r_forward_i) || (r_incr_i && r_forward_i))))
//    else $error("%m error: invalid read operations at time %t", $time);
  assert property (@(posedge clk_i) (reset_i != 1'b0 ||
        ~((r_rewind_i && r_forward_i) || (r_incr_i && r_forward_i))))
    else $finish;

  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly_hardened)

