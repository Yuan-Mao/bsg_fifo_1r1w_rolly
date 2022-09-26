
`include "bsg_defines.v"

  // Operations
  //   deq_v_i: Increment rcptr by 1
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
  //          //          //          //  (~read) //  (read)  //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  rptr    //    -     //    -     //    -     //    -     //    -     // rollback // rollback //
  //          //          //          //          //          //          //  (~deq)  //  (deq)   //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  wcptr   //  commit  //  commit  //  clr     //  clr     //    -     //    -     //    -     //
  //          //  (~enq)  //  (enq)   //  (~read) //  (read)  //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  rcptr   //    -     //    -     //   ack    //    -     //    -     //    -     //    -     //
  //          //          //          //          //          //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////


module bsg_fifo_1r1w_rolly_unhardened
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    , parameter ready_THEN_valid_p = 0
    , localparam ptr_width_lp = `BSG_SAFE_CLOG2(els_p)
    )
  (input                  clk_i
   , input                reset_i

   // read side
   , input                deq_v_i
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
  logic [ptr_width_lp-1:0] rptr_r, wptr_r;
  // one read checkpoint pointer, one write checkpoint pointer
  logic [ptr_width_lp-1:0] rcptr_r, wcptr_r;
  logic                    full, empty;
  // rptr_n is one cycle earlier than rptr_r
  logic [ptr_width_lp-1:0] rptr_n;

  wire enq      = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire deq      = deq_v_i & ~(rptr_r == rcptr_r);
  wire read     = yumi_i;
  wire rollback = rollback_v_i;
  wire ack      = ack_v_i;
  wire clr      = clr_v_i;
  wire commit   = commit_not_drop_v_i & commit_not_drop_i;
  wire drop     = commit_not_drop_v_i & ~commit_not_drop_i;

  assign ready_o = ~clr & ~full;
  assign v_o     = ~rollback & ~empty;

  bsg_fifo_rolly_tracker
   #(.els_p(els_p))
   ft
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.enq_i(enq)
     ,.deq_i(deq)
     ,.read_i(read)
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

  bsg_mem_1r1w
  #(.width_p(width_p), .els_p(els_p))
  fifo_mem
   (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r)
    ,.w_data_i(data_i)
    ,.r_v_i(read)
    ,.r_addr_i(rptr_r)
    ,.r_data_o(data_o)
    );

  // synopsys translate_off
  assert property (@(posedge clk_i) (reset_i != 1'b0 || ~(deq_v_i & (rptr_r == rcptr_r))))
    else $error("%m error: deque empty fifo at time %t", $time);

  assert property (@(posedge clk_i) (reset_i != 1'b0 ||
        (rollback_v_i && ack_v_i) || (deq_v_i && ack_v_i)))
    else $error("%m error: invalid read operations at time %t", $time);

  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly_unhardened)

