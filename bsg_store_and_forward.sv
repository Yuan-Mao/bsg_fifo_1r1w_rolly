
`include "bsg_defines.v"

module bsg_store_and_forward
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    //   write_no_backpressure_p:
    // If 1, the upstream master is unable to accept
    // back-pressure, and ready_o will always be high.
    , parameter `BSG_INV_PARAM(write_no_backpressure_p)
    , parameter harden_p = 0
    , parameter ready_THEN_valid_p = 0

    , localparam ptr_width_lp = `BSG_SAFE_CLOG2(els_p)
    )
  (input                  clk_i
   , input                reset_i

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
   , output               good_packet_o
   , output               incomplete_packet_o
   , output               bad_packet_o
   );

  logic                 commit_not_drop_v_li;
  logic                 commit_not_drop_li;
  logic [width_p+1-1:0] fifo_data_li;
  logic                 fifo_v_li;
  logic                 fifo_ready_lo;
  logic [width_p+1-1:0] fifo_data_lo;
  logic                 fifo_v_lo;
  logic                 fifo_yumi_li;

  // Operations
  wire enq  = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire full = ~fifo_ready_lo;
  wire empty = ~fifo_v_lo;
  wire overflow = full & empty;
  wire last = v_i & last_i;
  wire error = error_i;

  // Status
  logic good_packet_r, good_packet_n;
  logic incomplete_packet_r, incomplete_packet_n;
  logic bad_packet_r, bad_packet_n;

  assign commit_not_drop_v_li = last & enq;
  assign commit_not_drop_li   = good_packet_n;
  assign fifo_data_li = {data_i, last_i};
  assign fifo_yumi_li = yumi_i;

  bsg_fifo_1r1w_rolly #(
      .width_p(width_p+1)
     ,.els_p(els_p)
     ,.harden_p(harden_p)
     ,.ready_THEN_valid_p(ready_THEN_valid_p)
  ) fifo (
      .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.deq_v_i(fifo_yumi_li)
     ,.rollback_v_i(1'b0)
     ,.ack_v_i(1'b0)
 
     ,.clr_v_i(1'b0)
     ,.commit_not_drop_v_i(commit_not_drop_v_li)
     ,.commit_not_drop_i(commit_not_drop_li)

     ,.data_i(fifo_data_li)
     ,.v_i(fifo_v_li)
     ,.ready_o(fifo_ready_lo)

     ,.data_o(fifo_data_lo)
     ,.v_o(fifo_v_lo)
     ,.yumi_i(fifo_yumi_li)
  );

  logic dropping_state_r, dropping_state_n;

  bsg_dff_reset #(
      .width_p(2)
  ) state_reg (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(dropping_state_n)
     ,.data_o(dropping_state_r)
  );

  always_comb begin
    dropping_state_n = dropping_state_r;
    case (dropping_state_r)
      1'b0: begin
        if (enq && !last) begin
          if (full && write_no_backpressure_p)
            dropping_state_n = 1'b1;
        end
      end
      1'b1: begin
        if (enq && last)
          dropping_state_n = 1'b0;
      end
    endcase
  end

  always_comb begin
    fifo_v_li = 1'b0;
    if (enq) begin
      if ((full && write_no_backpressure_p) || overflow || dropping_state_r) begin
      end else begin
        fifo_v_li = 1'b1;
      end
    end
  end


  // ready_o will be high until finishing dropping a packet
  assign ready_o = write_no_backpressure_p || dropping_state_r || overflow || !full;
  assign v_o     = fifo_v_lo;
  assign {data_o, last_o}  = fifo_data_lo;

  bsg_dff_reset
   #(.width_p(3))
   status_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({good_packet_n, incomplete_packet_n, bad_packet_n})
     ,.data_o({good_packet_r, incomplete_packet_r, bad_packet_r})
     );

  always_comb begin
    {good_packet_n, incomplete_packet_n, bad_packet_n} = 3'b0;
    if (enq && last) begin
      if ((full && write_no_backpressure_p) || overflow || dropping_state_r) begin
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

  assign good_packet_o = good_packet_r;
  assign incomplete_packet_o = incomplete_packet_r;
  assign bad_packet_o = bad_packet_r;

endmodule

`BSG_ABSTRACT_MODULE(bsg_store_and_forward)

