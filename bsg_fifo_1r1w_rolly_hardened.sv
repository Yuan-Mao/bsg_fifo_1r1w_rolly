
`include "bsg_defines.v"

  // Operations
  //   incr_v_i: Increment rcptr by 1
  //   rollback_v_i: Reset rptr to rcptr
  //   ack_v_i: Forward rcptr to rptr
  //   clr_v_i: Move wptr, wcptr to rptr, i.e., clear all the data
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
   , input                incr_v_i
   , input                rollback_v_i
   , input                ack_v_i

   // write side
   , input                clr_v_i
   , input                commit_not_drop_v_i
   , input                commit_not_drop_i

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

  wire enq      = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire deq      = yumi_i;
  wire incr     = incr_v_i;
  wire rollback = rollback_v_i;
  wire ack      = ack_v_i;
  wire clr      = clr_v_i;
  wire commit   = commit_not_drop_v_i & commit_not_drop_i;
  wire drop     = commit_not_drop_v_i & ~commit_not_drop_i;

  assign ready_o = ~clr & ~full;
  assign v_o     = ~rollback & ~empty;

  bsg_fifo_rolly_tracker
   #(.lg_size_p(lg_size_p))
   ft
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.enq_i(enq)
     ,.deq_i(deq)
     ,.incr_i(incr)
     ,.rollback_i(rollback)
     ,.ack_i(ack)
     ,.clr_i(clr)
     ,.commit_i(commit)
     ,.drop_i(drop)

     ,.wptr_r_o(wptr_r)
     ,.rptr_r_o(rptr_r)
     ,.wcptr_r_o(wcptr_r)
     ,.rcptr_r_o(rcptr_r)

     ,.rptr_n_o(rptr_n)
     ,.full_o(full)
     ,.empty_o(empty)
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
//        ~((rollback_v_i && ack_v_i) || (incr_v_i && ack_v_i))))
//    else $error("%m error: invalid read operations at time %t", $time);
  assert property (@(posedge clk_i) (reset_i != 1'b0 ||
        ~((rollback_v_i && ack_v_i) || (incr_v_i && ack_v_i))))
    else $finish;

  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly_hardened)

