

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
  //          //          //          //  (~read) //  (read)  //          //          //          //
  //          //          //          //          //          //          //          //          //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  //          //          //          //          //          //          //          //          //
  //  rptr    //    -     //    -     //    -     //    -     //    -     // rollback // rollback //
  //          //          //          //          //          //          //  (~incr) //  (incr)  //
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


module bsg_fifo_1r1w_rolly
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(lg_size_p)
    , parameter ready_THEN_valid_p = 0
    , parameter harden_p = 0
    )
  (input                  clk_i
   , input                reset_i

   // read side
   , input                r_incr_i
   , input                r_rewind_i
   , input                r_forward_i
   , input                r_clear_i

   // write side
   , input                w_incr_i
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

  if (harden_p == 0)
    begin: unhardened
      bsg_fifo_1r1w_rolly_unhardened #(.width_p(width_p)
                                      ,.lg_size_p(lg_size_p)
                                      ,.ready_THEN_valid_p(ready_THEN_valid_p)
                                      ) fifo
      (.*);
    end
  else
    begin: hardened
      bsg_fifo_1r1w_rolly_hardened #(.width_p(width_p)
                                    ,.lg_size_p(lg_size_p)
                                    ,.ready_THEN_valid_p(ready_THEN_valid_p)
                                    ) fifo
      (.*);
    end


endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly)

