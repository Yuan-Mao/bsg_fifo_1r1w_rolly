

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

