
`default_nettype none

`include "bsg_defines.v"

program bsg_fifo_1r1w_rolly_hardened_cov
 #(parameter `BSG_INV_PARAM(lg_size_p)
  )

  (input clk_i
  ,input reset_i

  // interface signals
  ,input v_i
  ,input yumi_i

  // control signals
  ,input incr_v_i
  ,input rollback_v_i
  ,input ack_v_i
  ,input clr_v_i
  ,input commit_not_drop_v_i
  ,input commit_not_drop_i

  // internal signals
  ,input [lg_size_p+1-1:0] rptr_r
  ,input [lg_size_p+1-1:0] wptr_r
  ,input [lg_size_p+1-1:0] rcptr_r
  ,input [lg_size_p+1-1:0] wcptr_r
  ,input full
  ,input empty

  ,input ready_o
  );

  clocking cb @(posedge clk_i);
    input reset_i;

    input v_i;
    input yumi_i;

    input incr_v_i;
    input rollback_v_i;
    input ack_v_i;
    input clr_v_i;
    input commit_not_drop_v_i;
    input commit_not_drop_i;

    input rptr_r;
    input wptr_r;
    input rcptr_r;
    input wcptr_r;
    input full;
    input empty;
    input ready_o;
  endclocking

  function automatic bit check_ptrs_helper (
      int unsigned front_ptr
    , int unsigned back_ptr
    , ref bit has_wrapped
    , int unsigned lg_size
  );
    int unsigned front_ptr_msb = (front_ptr >> lg_size);
    int unsigned back_ptr_msb = (back_ptr >> lg_size);
    int unsigned front_ptr_main = (front_ptr % (1 << lg_size));
    int unsigned back_ptr_main = (back_ptr % (1 << lg_size));
    if(front_ptr_msb != back_ptr_msb) begin
      if(front_ptr_main < back_ptr_main)
        return 1'b0;
      if(has_wrapped) begin
        return 1'b0;
      end else begin
        has_wrapped = 1'b1;
        return 1'b1;
      end
    end else begin
      return front_ptr_main <= back_ptr_main;
    end

  endfunction

  // true if valid
  function automatic bit check_ptrs (
      int unsigned wptr
    , int unsigned wcptr
    , int unsigned rptr
    , int unsigned rcptr
    , int unsigned lg_size
  );
    bit has_wrapped = 0;
    assert(wptr < 2 * (1 << lg_size));
    assert(wcptr < 2 * (1 << lg_size));
    assert(rptr < 2 * (1 << lg_size));
    assert(rcptr < 2 * (1 << lg_size));
    if(!check_ptrs_helper(rcptr, rptr, has_wrapped, lg_size))
      return 0;
    if(!check_ptrs_helper(rptr, wcptr, has_wrapped, lg_size))
      return 0;
    if(!check_ptrs_helper(wcptr, wptr, has_wrapped, lg_size))
      return 0;
    if(has_wrapped) begin
      return (wptr % (1 << lg_size)) <= (rcptr % (1 << lg_size));
    end
    return 1;
  endfunction


  covergroup cg @(cb iff ~cb.reset_i);
    cp_v:    coverpoint cb.v_i;
    cp_yumi: coverpoint cb.yumi_i;

    cp_rptr:  coverpoint cb.rptr_r;
    cp_wptr:  coverpoint cb.wptr_r;
    cp_rcptr: coverpoint cb.rcptr_r;
    cp_wcptr: coverpoint cb.wcptr_r;

    cp_incr:     coverpoint cb.incr_v_i;
    cp_rollback: coverpoint cb.rollback_v_i;
    // ack is wired to 0
    cp_ack:      coverpoint cb.ack_v_i {illegal_bins ilg = {1};}

    cp_clr:               coverpoint cb.clr_v_i;
    // wired to 1
    cp_commit_not_drop_v: coverpoint cb.commit_not_drop_v_i {illegal_bins ilg = {0};}
    // wired to 1
    cp_commit_not_drop:   coverpoint cb.commit_not_drop_i {illegal_bins ilg = {0};}

    cross_all: cross cp_v, cp_yumi
        , cp_rptr, cp_wptr, cp_rcptr, cp_wcptr
        , cp_incr, cp_rollback
        , cp_clr {
      illegal_bins bins_0 = cross_all with (
         // remove all invalid combinations
         (~check_ptrs(cp_wptr, cp_wcptr, cp_rptr, cp_rcptr, lg_size_p)));
      illegal_bins bins_1 = cross_all with (
         // if empty -> yumi == 1'b0
         ((cp_rptr == cp_wcptr) && cp_yumi));
      illegal_bins bins_2 = cross_all with (
         // This illegal case would allow rcptr to go past rptr.
         (cp_incr && (cp_rptr == cp_rcptr) && ((cp_yumi == 1'b0) || cp_rollback))
      );
      // In this use case commit is always on
      illegal_bins bins_3 = cross_all with (
         (cp_wptr != cp_wcptr)
      );
      illegal_bins bins_4 = cross_all with (
         // if rollback -> yumi == 1'b0
         ((cp_rollback && cp_yumi))
      );
    }
    endgroup

  // create cover groups
  cg cg_inst = new;

  initial begin
    forever begin
        for(int i = 0;i < 100000;i++) begin
          @(cb);
        end
        $display("Functional coverage is %f%%", cg_inst.cross_all.get_coverage());
    end
  end

  // print coverages when simulation is done
  final begin
    $display("");
    $display("Instance: %m");
    $display("---------------------- Functional Coverage Results ----------------------");
    $display("Cross_all coverage is %f%%", cg_inst.cross_all.get_coverage());
    $display("Functional coverage is %f%%", cg_inst.get_coverage());
    $display("-------------------------------------------------------------------------");
    $display("");
  end

endprogram
