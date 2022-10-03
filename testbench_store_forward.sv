
`include "bsg_defines.v"

`default_nettype none

// Testbench for the "store-and-forward" mode of hardened bsg_fifo_1r1w_rolly

program testbench #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(lg_size_p)
    , localparam els_lp = (1 << lg_size_p)
)
(
     input                      clk_i
   , output logic               reset_o

   // read side
   , output                     incr_v_o // unused
   , output                     rollback_v_o // unused
   , output                     ack_v_o // unused

   // write side
   , output logic               clr_v_o // unused
   , output logic               commit_not_drop_v_o
   , output logic               commit_not_drop_o

   , output logic [width_p-1:0] data_o
   , output logic               v_o
   , input                      ready_i

   , input [width_p-1:0]        data_i
   , input                      v_i
   , output logic               yumi_o
);

  // total packet count
  parameter packet_count_p = 8192;

  logic ready_lo;
  assign yumi_o = v_i & ready_lo;
  assign rollback_v_o = 1'b0;
  assign ack_v_o = 1'b0;
  assign clr_v_o = 1'b0;
  assign incr_v_o = yumi_o;

  localparam mtu_lp = els_lp;
  //   As long as the buffer size is large enough to track all the written data in DUT,
  // any size will work
  localparam buffer_size = 2 * els_lp;

  bit [width_p-1:0] buffer [buffer_size];

  clocking cb @(posedge clk_i);
    input  ready_i;
    input  data_i;
    input  v_i;
  endclocking

  task automatic send_and_check_packet(
      input int mtu
    , input int count
  );
    int unsigned packet_size;
    bit commit;
    bit last_sent;
    bit handshaking_next;
    for(int unsigned idx = 0;idx < count;) begin
      // Get random size
      if((count - idx) <= mtu)
        packet_size = count - idx;
      else
        packet_size = $urandom() % (mtu + 1);

//      $display("packet size: %0x", packet_size);
      if(packet_size == 0) begin
        commit_not_drop_v_o = $urandom();
        commit_not_drop_o = $urandom();
      end else begin
        commit = $urandom();
        last_sent = 1'b0;
        for(int j = 0;j < packet_size;) begin
          v_o = $urandom();
          if(v_o == 1'b1) begin
            data_o = (width_p)'($urandom());

            handshaking_next = v_o & ready_i;
            commit_not_drop_v_o = (j == packet_size - 1) & ($urandom() % 2) & handshaking_next;
            assert(last_sent == 1'b0) else $finish;
            if(commit_not_drop_v_o == 1'b1) begin
              commit_not_drop_o = commit;
//              $display("here: %0x %0x at %t", v_o, ready_i, $time);
              last_sent = 1'b1;
            end else begin
              // check if the valid signal really guards the control
              commit_not_drop_o = $urandom();
            end
          end
          @(cb);
          // check the sampled data
//          $display("here2: %0x %0x at %t", v_o, cb.ready_i, $time);
          if(cb.ready_i == 1'b1 & v_o == 1'b1) begin
            // handshaking completed
//            $display("handshaking: %x with commit %x at time %t", data_o, commit, $time);
            if(commit == 1'b1) begin
              buffer[(idx + j) % buffer_size] = data_o;
            end
            j++;
            v_o = 1'b0;
          end else begin
            // handshaking not completed
          end
        end
        while(last_sent == 1'b0) begin
          commit_not_drop_v_o = $urandom();
          commit_not_drop_o = commit;
          @(cb);
          if(commit_not_drop_v_o) begin
            last_sent = 1'b1;
          end
        end
//        $display("last_sent at time %t", $time);
        if(commit == 1'b1) begin
          idx += packet_size;
        end
      end
    end
    v_o = 1'b0;
  endtask

  task automatic receive_and_check_packet(
      input int count
  );
    int idx = 0;
    // keep receiving until 'count' elements are received
    forever begin
      ready_lo = $urandom() % 2;
      @(cb);
      if(cb.v_i & ready_lo) begin
        // received a beat: check it
//        $display("expected: %x actual: %x", buffer[(idx) % buffer_size], cb.data_i);
        assert(buffer[idx % buffer_size] == cb.data_i) else $finish;
        idx++;
      end
      if(idx == count)
        break;
    end
  endtask

  int unsigned count;
  initial begin
    reset_o = 1'b1;
    v_o = 1'b0;
    ready_lo = 1'b0;
    @(cb);
    reset_o = 1'b0;
    count = packet_count_p * mtu_lp;
    fork
      send_and_check_packet(mtu_lp, count);
      receive_and_check_packet(count);
    join
    $display("Test completed");
    $finish;
  end

endprogram
