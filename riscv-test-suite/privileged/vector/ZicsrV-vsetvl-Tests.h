// Tests for cp_vsetvl_i_rd_nx0_rs1_x0
	li t0, 1    // Set up t0 = 1 for resetting vl
	// SEW = 8, LMUL = 1
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e8, m1, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 8, LMUL = 2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e8, m2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 8, LMUL = 4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e8, m4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 8, LMUL = 8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e8, m8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 8, LMUL = f2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e8, mf2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 8, LMUL = f4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e8, mf4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 8, LMUL = f8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e8, mf8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 16, LMUL = 1
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e16, m1, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 16, LMUL = 2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e16, m2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 16, LMUL = 4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e16, m4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 16, LMUL = 8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e16, m8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 16, LMUL = f2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e16, mf2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 16, LMUL = f4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e16, mf4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 16, LMUL = f8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e16, mf8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 32, LMUL = 1
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e32, m1, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 32, LMUL = 2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e32, m2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 32, LMUL = 4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e32, m4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 32, LMUL = 8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e32, m8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 32, LMUL = f2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e32, mf2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 32, LMUL = f4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e32, mf4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 32, LMUL = f8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e32, mf8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 64, LMUL = 1
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e64, m1, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 64, LMUL = 2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e64, m2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 64, LMUL = 4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e64, m4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 64, LMUL = 8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e64, m8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 64, LMUL = f2
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e64, mf2, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 64, LMUL = f4
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e64, mf4, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// SEW = 64, LMUL = f8
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	vsetvli  x8, x0, e64, mf8, tu, mu
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_000_000
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x0
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_000_001
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x1
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_000_010
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x2
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_000_011
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x3
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_000_101
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x5
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_000_110
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x6
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_000_111
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x7
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_001_000
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x8
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_001_001
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x9
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_001_010
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0xa
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_001_011
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0xb
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_001_101
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0xd
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_001_110
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0xe
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_001_111
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0xf
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_010_000
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x10
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_010_001
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x11
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_010_010
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x12
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_010_011
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x13
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_010_101
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x15
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_010_110
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x16
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_010_111
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x17
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_011_000
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x18
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_011_001
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x19
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_011_010
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x1a
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_011_011
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x1b
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_011_101
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x1d
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_011_110
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x1e
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

	// vtype[7:0] = 0_0_011_111
	vsetvli  x6, t0, e8, m1, tu, mu   // Reset vl = 1 and vtype
	li       t2, 0x1f
	vsetvl   x8, x0, t2
	csrr     x1, vl
	RVTEST_SIGUPD(x3, x1)

