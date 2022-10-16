.PHONY: all wave cov clean

export CUR_DIR := $(shell pwd)
export BASEJUMP_STL_DIR := /mnt/users/ssd3/homes/ymchueh/tmp/basejump_stl
export TESTBENCH_FILE := testbench_speculation.sv
export COV_FILE := bsg_speculation_cov.sv


TOP_MODULE := wrapper

VCS_OPTS := -full64
VCS_OPTS += -f flist.vcs
VCS_OPTS += -sverilog
VCS_OPTS += +lint=all +lint=noVCDE +lint=noNS
VCS_OPTS += -top $(TOP_MODULE)
VCS_OPTS += +incdir+$(BASEJUMP_STL_DIR)/bsg_misc
VCS_OPTS += +incdir+$(BASEJUMP_STL_DIR)/bsg_tag
VCS_OPTS += -assert svaext
VCS_OPTS += -debug_all


all: flist.vcs
	vcs $(VCS_OPTS)
wave:
	dve -full64 -vpd dump.vpd
cov:
	dve -full64 -cov -covdir simv.vdb
flist.vcs: flist.template
	cat $^ | envsubst > $@

clean:
	rm -rf simv.daidir/ simv csrc/ flist.vcs ucli.key vc_hdrs.h
