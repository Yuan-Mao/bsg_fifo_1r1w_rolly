

`include "bsg_defines.v"

// TODO: May use paramter to make different assumptions
// Assumption:
// * The following are illegal:
//  incr     & ack
//  rollback & ack
//  drop & commit
// * rollback || empty -> !deq
// * clr > drop, commit
// * clr and drop will discard the current write if any

//   TODO: Add comments for the round trip between
// ready_o and commit_not_drop_v_i
module bsg_fifo_rolly_tracker
  #(parameter `BSG_INV_PARAM(lg_size_p)
  , localparam els_lp = (1 << lg_size_p)
  )
  (input  clk_i
  , input reset_i

  , input enq_i
  , input incr_i
  , input deq_i
  , input rollback_i
  , input ack_i
  , input clr_i
  , input commit_i
  , input drop_i

  , output [lg_size_p-1:0] wptr_r_o
  , output [lg_size_p-1:0] rptr_r_o
  , output [lg_size_p-1:0] wcptr_r_o
  , output [lg_size_p-1:0] rcptr_r_o
  , output [lg_size_p-1:0] rptr_n_o

  , output full_o
  , output empty_o
  );

  // One read pointer, one write pointer, two checkpoint pointers
  // ptr_width + 1 for wrap bit
  logic [lg_size_p:0] rptr_r, rcptr_r;
  logic [lg_size_p:0] wptr_r, wcptr_r;
  logic [lg_size_p:0] rptr_n;

  // Used to catch up on various read/write operations
  logic [lg_size_p:0] rptr_jmp, rcptr_jmp, wptr_jmp, wcptr_jmp;

  assign rptr_jmp = rollback_i
                    ? (rcptr_r - rptr_r + (lg_size_p+1)'(incr_i))
                    : ((lg_size_p+1)'(deq_i));

  assign wptr_jmp = clr_i
                    ? (rptr_r - wptr_r + (lg_size_p+1)'(deq_i))
                    : drop_i
                       ? (wcptr_r - wptr_r)
                       : ((lg_size_p+1)'(enq_i));

  assign rcptr_jmp = ack_i
                    // ack_i also acks the current read
                    ? (rptr_r - rcptr_r + (lg_size_p+1)'(deq_i))
                    : ((lg_size_p+1)'(incr_i));

  assign wcptr_jmp = clr_i
                    ? (rptr_r - wcptr_r + (lg_size_p+1)'(deq_i))
                    : commit_i
                       // commit_i also commits the current write
                       ? (wptr_r - wcptr_r) + (lg_size_p+1)'(enq_i)
                       : ((lg_size_p+1)'(0));

  bsg_circular_ptr
   #(.slots_p(2*els_lp), .max_add_p(2*els_lp-1))
   wcptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wcptr_jmp)
     ,.o(wcptr_r)
     ,.n_o() // UNUSED
     );

  bsg_circular_ptr
   #(.slots_p(2*els_lp), .max_add_p(2*els_lp-1))
   rcptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(rcptr_jmp)
     ,.o(rcptr_r)
     ,.n_o() // UNUSED
     );

  bsg_circular_ptr
   #(.slots_p(2*els_lp),.max_add_p(2*els_lp-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o() // UNUSED
     );

  bsg_circular_ptr
  #(.slots_p(2*els_lp), .max_add_p(2*els_lp-1))
  rptr
   (.clk(clk_i)
    ,.reset_i(reset_i)
    ,.add_i(rptr_jmp)
    ,.o(rptr_r)
    ,.n_o(rptr_n)
    );

  assign full_o = (rcptr_r[0+:lg_size_p] == wptr_r[0+:lg_size_p])
              & (rcptr_r[lg_size_p] != wptr_r[lg_size_p]);

  assign empty_o = (rptr_r[0+:lg_size_p] == wcptr_r[0+:lg_size_p])
               & (rptr_r[lg_size_p] == wcptr_r[lg_size_p]);

  assign wptr_r_o = wptr_r[0+:lg_size_p];
  assign rptr_r_o = rptr_r[0+:lg_size_p];
  assign wcptr_r_o = wcptr_r[0+:lg_size_p];
  assign rcptr_r_o = rcptr_r[0+:lg_size_p];

  assign rptr_n_o = rptr_n[0+:lg_size_p];

  // synopsys translate_off
  assert property (@(posedge clk_i) (reset_i != 1'b0 || ~(commit_i & drop_i)))
    else $error("%m error: request both commit and drop at time %t", $time);
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_rolly_tracker)
