
`include "bsg_defines.v"

module bsg_fifo_1r1w_rolly
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    , parameter ready_THEN_valid_p = 0

    , localparam ptr_width_lp = `BSG_SAFE_CLOG2(els_p)
    )
  (input                  clk_i
   , input                reset_i

   // read side
   , input                clr_v_i
   , input                deq_v_i
   , input                roll_v_i

   // write side
   , input                commit_not_drop_v_i
   , input                commit_not_drop_i

   , input [width_p-1:0]  data_i
   , input                v_i
   , output               ready_o

   , output [width_p-1:0] data_o
   , output               v_o
   , input                yumi_i
   );

  // One read pointer, one write pointer, two checkpoint pointers
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] rptr_r, rcptr_r;
  logic [ptr_width_lp:0] wptr_r, wcptr_r;

  // Used to catch up on roll, clear, commit and drop
  logic [ptr_width_lp:0] rptr_jmp, wptr_jmp, wcptr_jmp;

  // Operations
  wire enq  = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire deq  = deq_v_i;
  wire read = yumi_i;
  wire clr  = clr_v_i;
  wire roll = roll_v_i;
  wire commit = commit_not_drop_v_i & commit_not_drop_i;
  wire drop   = commit_not_drop_v_i & ~commit_not_drop_i;

  assign rptr_jmp = roll
                    ? (rcptr_r - rptr_r + (ptr_width_lp+1)'(deq))
                    : read
                       ? ((ptr_width_lp+1)'(1))
                       : ((ptr_width_lp+1)'(0));

  assign wptr_jmp = clr
                    ? (rptr_r - wptr_r + (ptr_width_lp+1)'(read))
                    : drop
                       ? (wcptr_r - wptr_r)
                       : enq
                          ? ((ptr_width_lp+1)'(1))
                          : ((ptr_width_lp+1)'(0));
  assign wcptr_jmp = clr
                    ? (rptr_r - wcptr_r + (ptr_width_lp+1)'(read))
                    : commit
                       ? (wptr_r - wcptr_r) + (ptr_width_lp+1)'(enq)
                       : ((ptr_width_lp+1)'(0));


  wire empty = (rptr_r[0+:ptr_width_lp] == wcptr_r[0+:ptr_width_lp])
               & (rptr_r[ptr_width_lp] == wcptr_r[ptr_width_lp]);
  wire full = (rcptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
              & (rcptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);

  assign ready_o = ~clr & ~full;
  assign v_o     = ~roll & ~empty;

  bsg_circular_ptr
   #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
   wcptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wcptr_jmp)
    ,.o(wcptr_r)
    ,.n_o()
     );

  bsg_circular_ptr
   #(.slots_p(2*els_p), .max_add_p(1))
   rcptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(deq_v_i)
    ,.o(rcptr_r)
    ,.n_o()
     );

  bsg_circular_ptr
   #(.slots_p(2*els_p),.max_add_p(2*els_p-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o()
     );

  bsg_circular_ptr
  #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
  rptr
   (.clk(clk_i)
    ,.reset_i(reset_i)
    ,.add_i(rptr_jmp)
    ,.o(rptr_r)
    ,.n_o()
    );

  bsg_mem_1r1w
  #(.width_p(width_p), .els_p(els_p))
  fifo_mem
   (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r[0+:ptr_width_lp])
    ,.w_data_i(data_i)
    ,.r_v_i(read)
    ,.r_addr_i(rptr_r[0+:ptr_width_lp])
    ,.r_data_o(data_o)
    );

// TODO: warn when dequeueing an empty FIFO

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly)

