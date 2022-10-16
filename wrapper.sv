
module wrapper();

  // change parameters here:
  parameter width_p = 32;
  parameter lg_size_p = 2;

  bit                 clk_i;
  logic               reset_lo;

  logic               incr_v_lo;
  logic               rollback_v_lo;
  logic               ack_v_lo;

  logic               clr_v_lo;
  logic               commit_not_drop_v_lo;
  logic               commit_not_drop_lo;

  logic [width_p-1:0] data_lo;
  logic               v_lo;
  logic               ready_li;

  logic [width_p-1:0] data_li;
  logic               v_li;
  logic               yumi_lo;


  always #1 clk_i = ~clk_i;

  initial begin
//      $vcdplusfile("dump.vpd");
//      $vcdpluson();
  end

  testbench #(
     .width_p(width_p)
    ,.lg_size_p(lg_size_p)
  ) testbench (
     .clk_i(clk_i)
    ,.reset_o(reset_lo)
 
    ,.incr_v_o(incr_v_lo)
    ,.rollback_v_o(rollback_v_lo)
    ,.ack_v_o(ack_v_lo)
 
    ,.clr_v_o(clr_v_lo)
    ,.commit_not_drop_v_o(commit_not_drop_v_lo)
    ,.commit_not_drop_o(commit_not_drop_lo)
 
    ,.data_o(data_lo)
    ,.v_o(v_lo)
    ,.ready_i(ready_li)
 
    ,.data_i(data_li)
    ,.v_i(v_li)
    ,.yumi_o(yumi_lo)
  );

  bsg_fifo_1r1w_rolly_hardened #(
     .width_p(width_p)
    ,.lg_size_p(lg_size_p)
  ) dut (
     .clk_i(clk_i)
    ,.reset_i(reset_lo)

    ,.incr_v_i(incr_v_lo)
    ,.rollback_v_i(rollback_v_lo)
    ,.ack_v_i(ack_v_lo)

    ,.clr_v_i(clr_v_lo)
    ,.commit_not_drop_v_i(commit_not_drop_v_lo)
    ,.commit_not_drop_i(commit_not_drop_lo)

    ,.data_i(data_lo)
    ,.v_i(v_lo)
    ,.ready_o(ready_li)

    ,.data_o(data_li)
    ,.v_o(v_li)
    ,.yumi_i(yumi_lo)
  );

  bind bsg_fifo_1r1w_rolly_hardened bsg_fifo_1r1w_rolly_hardened_cov #(
     .lg_size_p(lg_size_p)
  ) cov_inst (
     .*
    ,.rptr_r(ft.rptr_r)
    ,.wptr_r(ft.wptr_r)
    ,.rcptr_r(ft.rcptr_r)
    ,.wcptr_r(ft.wcptr_r)
 );

endmodule
