
`include "bsg_defines.v"

module bsg_fifo_1r1w_rolly
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    //   write_no_backpressure_p:
    // If 1, the upstream master is unable to accept
    // back-pressure, and ready_o will always be high.
    , parameter `BSG_INV_PARAM(write_no_backpressure_p)
    , parameter ready_THEN_valid_p = 0

    , localparam ptr_width_lp = `BSG_SAFE_CLOG2(els_p)
    )
  (input                  clk_i
   , input                reset_i

   , input                clr_v_i
   , input                deq_v_i
   , input                roll_v_i

   , input [width_p-1:0]  data_i
   , input                v_i
   , input                last_i
   , input                error_i
   , output               ready_o

   , output [width_p-1:0] data_o
   , output               v_o
   , output               last_o
   , input                yumi_i

   //   This module will drop packets when
   // 1. the size of the incoming packet is simply too
   // large to store in FIFO.
   // 2. the upstream master does not support
   // back-pressure and this module runs out of FIFO
   // space during the receiving of a packet.
   // 3. clr_v_i happens during the receiving of a
   // packet.
   , output               good_packet_o
   , output               incomplete_packet_o
   , output               bad_packet_o
   );

  logic empty, full, overflow;
  logic fifo_mem_w_v_li;

  // Both read and write have a current pointer and a checkpoint pointer
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] rptr_r, rcptr_r;
  logic [ptr_width_lp:0] wptr_r, wcptr_r;

  // Used to catch up on roll, clear, error
  logic [ptr_width_lp:0] rptr_jmp, wcptr_jmp, wptr_jmp;

  // Operations
  // clr_v_i: Clear all the data between rptr and wptr
  //   (Move wptr, wcptr to rptr). clr_v_i will also drop
  //   the current receiving packet, if any.
  // deq_v_i: Increment rcptr by 1
  // roll_v_i: Reset rptr to rcptr
  // last_i (with error_i == 1'b0): Received a good packet: forward wcptr to wptr
  // last_i (with error_i == 1'b1): Received a bad packet: reset wptr to wcptr
  //
  wire enq  = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire deq  = deq_v_i;
  wire read = yumi_i;
  wire clr  = clr_v_i;
  wire roll = roll_v_i;
  wire last = v_i & last_i;
  wire error = last & error_i;

  assign rptr_jmp = roll
                    ? (rcptr_r - rptr_r + (ptr_width_lp+1)'(deq))
                    : read
                       ? ((ptr_width_lp+1)'(1'b1))
                       : ((ptr_width_lp+1)'(1'b0));

  assign empty = (rptr_r[0+:ptr_width_lp] == wcptr_r[0+:ptr_width_lp])
               & (rptr_r[ptr_width_lp] == wcptr_r[ptr_width_lp]);

  // ** Difference between full and overflow ** //
  //   full: running out of write space, and there is 
  // some read data in the FIFO
  //   overflow: running out write space, and there is
  // no read data in the FIFO, i.e., even for the entire
  // FIFO the packet is still too large to store.

  assign full = (rcptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
              & (rcptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);
  // overflow: incoming packet size alone > the FIFO memory size
  assign overflow = (wcptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
              & (wcptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);

  logic good_packet_r, good_packet_n;
  logic incomplete_packet_r, incomplete_packet_n;
  logic bad_packet_r, bad_packet_n;
  bsg_dff_reset
   #(.width_p(3))
   status_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({good_packet_n, incomplete_packet_n, bad_packet_n})
     ,.data_o({good_packet_r, incomplete_packet_r, bad_packet_r})
     );
  assign good_packet_o = good_packet_r;
  assign incomplete_packet_o = incomplete_packet_r;
  assign bad_packet_o = bad_packet_r;

  enum logic [1:0] {e_ready, e_receiving, e_dropping} state_r, state_n;

  bsg_dff_reset #(
      .width_p(2)
  ) state_reg (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(state_n)
     ,.data_o(state_r)
  );

  always_comb begin
    state_n = state_r;
    case (state_r)
      e_ready: begin
        if (enq && !last) begin
          if (overflow || clr || (full && write_no_backpressure_p))
            state_n = e_dropping;
          else
            state_n = e_receiving;
        end
      end
      e_receiving: begin
        if (enq && last)
          state_n = e_ready;
        else if (clr || (enq && (full && write_no_backpressure_p)) || overflow)
          state_n = e_dropping;
      end
      e_dropping: begin
        if (enq && last)
          state_n = e_ready;
      end
    endcase
  end

  always_comb begin
    wptr_jmp  = '0;
    wcptr_jmp = '0;
    fifo_mem_w_v_li = 1'b0;
    if (clr) begin
      wptr_jmp  = (rptr_r - wptr_r + (ptr_width_lp+1)'(read));
      wcptr_jmp = (rptr_r - wcptr_r + (ptr_width_lp+1)'(read));
    end else if (enq) begin
      if ((full && write_no_backpressure_p) || overflow || state_r == e_dropping) begin
        // insufficient FIFO space: drop the entire frame
        if (last) begin
          // end of frame: reset write pointer
          wptr_jmp = wcptr_r - wptr_r;
        end
      end else begin
        wptr_jmp = (ptr_width_lp+1)'(1);
        fifo_mem_w_v_li = 1'b1;
        // end of frame
        if (last) begin
          if (error) begin
            // bad packet: reset write pointer
            wptr_jmp = wcptr_r - wptr_r;
          end else begin
            // good packet: update write pointer
            wcptr_jmp = wptr_r - wcptr_r + (ptr_width_lp+1)'(1'b1);
          end
        end
      end
    end
  end

  // Status
  always_comb begin
    {good_packet_n, incomplete_packet_n, bad_packet_n} = 3'b0;
    if (enq && last) begin
      if (clr || (full && write_no_backpressure_p) || overflow || state_r == e_dropping) begin
        incomplete_packet_n = 1'b1;
      end else begin
        // complete packet
        if (error)
          bad_packet_n = 1'b1;
        else
          good_packet_n = 1'b1;
      end
    end
  end
  // ready_o will be high until finishing dropping a packet
  assign ready_o = write_no_backpressure_p || (state_r == e_dropping) || overflow || (!full && !clr);
  assign v_o     = ~roll & ~empty;

  bsg_circular_ptr
   #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o()
     );

  bsg_circular_ptr
   #(.slots_p(2*els_p),.max_add_p(2*els_p-1))
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
  #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
  rptr
   (.clk(clk_i)
    ,.reset_i(reset_i)
    ,.add_i(rptr_jmp)
    ,.o(rptr_r)
    ,.n_o()
    );

  bsg_mem_1r1w
  #(.width_p(width_p+1), .els_p(els_p))
  fifo_mem
   (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_v_i(fifo_mem_w_v_li)
    ,.w_addr_i(wptr_r[0+:ptr_width_lp])
    ,.w_data_i({data_i, last_i})
    ,.r_v_i(read)
    ,.r_addr_i(rptr_r[0+:ptr_width_lp])
    ,.r_data_o({data_o, last_o})
    );

// TODO: warn when dequeueing an empty FIFO, when bad packet, overflow occur

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly)

