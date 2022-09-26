

`include "bsg_defines.v"

module bsg_fifo_rolly_tracker
  #(parameter `BSG_INV_PARAM(els_p)
  , localparam ptr_width_lp = `BSG_SAFE_CLOG2(els_p)
  )
  (input  clk_i
  , input reset_i

  , input enq_i
  , input deq_i
  , input read_i
  , input rollback_i
  , input ack_i
  , input clr_i
  , input commit_i
  , input drop_i

  , output [ptr_width_lp-1:0] wptr_r_o
  , output [ptr_width_lp-1:0] rptr_r_o
  , output [ptr_width_lp-1:0] wcptr_r_o
  , output [ptr_width_lp-1:0] rcptr_r_o
  , output [ptr_width_lp-1:0] rptr_n_o

  , output full_o
  , output empty_o
  );

  // One read pointer, one write pointer, two checkpoint pointers
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] rptr_r, rcptr_r;
  logic [ptr_width_lp:0] wptr_r, wcptr_r;
  logic [ptr_width_lp:0] rptr_n;

  // Used to catch up on various read/write operations
  logic [ptr_width_lp:0] rptr_jmp, rcptr_jmp, wptr_jmp, wcptr_jmp;

  assign rptr_jmp = rollback_i
                    ? (rcptr_r - rptr_r + (ptr_width_lp+1)'(deq_i))
                    : ((ptr_width_lp+1)'(read_i));

  assign wptr_jmp = clr_i
                    ? (rptr_r - wptr_r + (ptr_width_lp+1)'(read_i))
                    : drop_i
                       ? (wcptr_r - wptr_r)
                       : ((ptr_width_lp+1)'(enq_i));

  assign rcptr_jmp = ack_i
                    // ack_i also acks the current read
                    ? (rptr_r - rcptr_r + (ptr_width_lp+1)'(read_i))
                    : ((ptr_width_lp+1)'(deq_i));

  assign wcptr_jmp = clr_i
                    ? (rptr_r - wcptr_r + (ptr_width_lp+1)'(read_i))
                    : commit_i
                       // commit_i also commits the current write
                       ? (wptr_r - wcptr_r) + (ptr_width_lp+1)'(enq_i)
                       : ((ptr_width_lp+1)'(0));

  bsg_circular_ptr
   #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
   wcptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wcptr_jmp)
     ,.o(wcptr_r)
     ,.n_o() // UNUSED
     );

  bsg_circular_ptr
   #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
   rcptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(rcptr_jmp)
     ,.o(rcptr_r)
     ,.n_o() // UNUSED
     );

  bsg_circular_ptr
   #(.slots_p(2*els_p),.max_add_p(2*els_p-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o() // UNUSED
     );

  bsg_circular_ptr
  #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
  rptr
   (.clk(clk_i)
    ,.reset_i(reset_i)
    ,.add_i(rptr_jmp)
    ,.o(rptr_r)
    ,.n_o(rptr_n)
    );

  //   full: rcptr == wptr
  //   all transistions to above condition:
  // 1. init
  // 2. clr (X)
  // 3. enq an element (O)
  // 4. drop (X)
  //   empty: rptr == wcptr
  //   all transistions to above condition:
  // 1. init
  // 2. deq an element (O)
  // 3. clr (O)
  // 4. commit (X)
  assign full_o = (rcptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
              & (rcptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);

  assign empty_o = (rptr_r[0+:ptr_width_lp] == wcptr_r[0+:ptr_width_lp])
               & (rptr_r[ptr_width_lp] == wcptr_r[ptr_width_lp]);

  assign wptr_r_o = wptr_r[0+:ptr_width_lp];
  assign rptr_r_o = rptr_r[0+:ptr_width_lp];
  assign wcptr_r_o = wcptr_r[0+:ptr_width_lp];
  assign rcptr_r_o = rcptr_r[0+:ptr_width_lp];

  assign rptr_n_o = rptr_n[0+:ptr_width_lp];

  // synopsys translate_off
  assert property (@(posedge clk_i) (reset_i != 1'b0 || ~(commit_i & drop_i)))
    else $error("%m error: request both commit and drop at time %t", $time);
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_rolly_tracker)
