
`include "bsg_defines.v"

module bsg_fifo_1r1w_rolly
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    , parameter ready_THEN_valid_p = 0
    , parameter harden_p = 0
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

  // One read pointer, one write pointer, two checkpoint pointers
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] rptr_r, rcptr_r;
  logic [ptr_width_lp:0] wptr_r, wcptr_r;
  logic [ptr_width_lp:0] rptr_n;

  // Used to catch up on various read/write operations
  logic [ptr_width_lp:0] rptr_jmp, rcptr_jmp, wptr_jmp, wcptr_jmp;

  // Status
  logic empty, full;

  // Operations
  //   clr_v_i: Move wptr, wcptr to rptr, i.e., clear all the data
  // between rptr and wptr
  //   deq_v_i: Increment rcptr by 1
  //   rollback_v_i: Reset rptr to rcptr
  //   commit: Forward wcptr to wptr
  //   drop: Reset wptr to wcptr

  wire enq      = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire deq      = deq_v_i & ~empty;
  wire read     = yumi_i;
  wire rollback = rollback_v_i;
  wire ack      = ack_v_i;
  wire clr      = clr_v_i;
  wire commit   = commit_not_drop_v_i & commit_not_drop_i;
  wire drop     = commit_not_drop_v_i & ~commit_not_drop_i;

  assign rptr_jmp = rollback
                    ? (rcptr_r - rptr_r + (ptr_width_lp+1)'(deq))
                    : ((ptr_width_lp+1)'(read));

  assign wptr_jmp = clr
                    ? (rptr_r - wptr_r + (ptr_width_lp+1)'(read))
                    : drop
                       ? (wcptr_r - wptr_r)
                       : ((ptr_width_lp+1)'(enq));

  assign rcptr_jmp = ack
                    ? (rptr_r - rcptr_r)
                    : ((ptr_width_lp+1)'(deq));

  assign wcptr_jmp = clr
                    ? (rptr_r - wcptr_r + (ptr_width_lp+1)'(read))
                    : commit
                       ? (wptr_r - wcptr_r) + (ptr_width_lp+1)'(enq)
                       : ((ptr_width_lp+1)'(0));


  assign empty = (rptr_r[0+:ptr_width_lp] == wcptr_r[0+:ptr_width_lp])
               & (rptr_r[ptr_width_lp] == wcptr_r[ptr_width_lp]);
  assign full = (rcptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
              & (rcptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);

  assign ready_o = ~clr & ~full;
  assign v_o     = ~rollback & ~empty;

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
   #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
   rcptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(rcptr_jmp)
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
    ,.n_o(rptr_n)
    );
if (harden_p == 0) begin
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
end else begin
  logic [width_p-1:0] data_o_mem, data_o_reg;
  logic read_write_same_addr_r, read_write_same_addr_n;

  bsg_mem_1r1w_sync
  #(.width_p(width_p)
    ,.els_p(els_p)
    ,.read_write_same_addr_p(0)
    ,.disable_collision_warning_p(0)
    ,.harden_p(1))
  fifo_mem
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r[0+:ptr_width_lp])
    ,.w_data_i(data_i)
    ,.r_v_i(~read_write_same_addr_n)
    ,.r_addr_i(rptr_n[0+:ptr_width_lp])
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

  assign read_write_same_addr_n = enq & (wptr_r[0+:ptr_width_lp] == rptr_n[0+:ptr_width_lp]);
  always_ff @(posedge clk_i)
    read_write_same_addr_r <= read_write_same_addr_n;
  assign data_o = (read_write_same_addr_r) ? data_o_reg : data_o_mem;
end
  // synopsys translate_off
  assert property (@(posedge clk_i) (reset_i != 1'b0 || ~(deq_v_i & empty)))
    else $error("%m error: deque empty fifo at time %t", $time);

  assert property (@(posedge clk_i) (reset_i != 1'b0 ||
        ($countones({deq_v_i, rollback_v_i, ack_v_i}) <= 1)))
    else $error("%m error: request more than one read operations at time %t", $time);
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly)

