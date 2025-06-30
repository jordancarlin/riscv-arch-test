///////////////////////////////////////////
// priv-endian.h
//
// Written: mbellido@hmc.edu 18 february 2025
// Adapted for to support both RV32 and RV64 mbellido@hmc.edu
//
// Purpose: has the fuctions to store and load for endianness
// Feed in: provide the endianness for the reads the writes and the privilege
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
//
// Registers used:
//   s1: a 1 in bit specific to SBE or UBE to set/clear mstatus, mstatush or status
//   s3: scratch address
//   s4: endianness for write test
//   s5: endianness for read test
//   s6: return address for calls to endiantest
//   s7: return address for calls to endianaccess
//   s8: stored endianess value
//   s9: return address for calls to setendianness
//   s10: 0 to set/clear sstatus.UBE  (any other value otherwisse )
//   s11: To switch back to running privilege mode once set/clear endianness
////////////////////////////////////////////////////////////////////////////////////////////////
// Library used for EndianU, EndianM and EndianS
// will store and load using the provided read and write endianness

endiantest: //Write to memory function
    # Try each size of stores with the write endianness, and then the loads with the read endianness
    mv s8, s4       # setEndianness(write)
    jal s9, setendianness
    # Test storing bytes
    li t0, 0x01
    sb t0, 0(s3)
    lb t3, 0(s3)         
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x02
    sb t0, 1(s3)
    lb t3, 1(s3)         
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x03
    sb t0, 2(s3)
    lb t3, 2(s3)          
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x04
    sb t0, 3(s3)
    lb t3, 3(s3)          
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x05
    sb t0, 4(s3)
    lb t3, 4(s3)         
    RVTEST_SIGWRITE(x3, t3) 
    li t0, 0x06
    sb t0, 5(s3)
    lb t3, 5(s3)          
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x07
    sb t0, 6(s3)
    lb t3, 6(s3)          
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x08
    sb t0, 7(s3)
    lb t3, 7(s3)     
    RVTEST_SIGWRITE(x3, t3)
    jal s7, endianaccess

    mv s8, s4       # setEndianness(write)
    jal s9, setendianness
    li t0, 0x1112
    sh t0, 0(s3)    
    lh t3, 0(s3)     
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x1314
    sh t0, 2(s3)    
    lh t3, 2(s3)     
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x1516  
    sh t0, 4(s3) 
    lh t3, 4(s3)          
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x1718
    sh t0, 6(s3)  
    lh t3, 6(s3)       
    RVTEST_SIGWRITE(x3, t3)
    jal s7, endianaccess

    mv s8, s4       # setEndianness(write)
    jal s9, setendianness
    li t0, 0x21222324
    sw t0, 0(s3)       
    lw t3, 0(s3)  
    RVTEST_SIGWRITE(x3, t3)
    li t0, 0x25262728
    sw t0, 4(s3)  
    lw t3, 4(s3)          
    RVTEST_SIGWRITE(x3, t3) 
    jal s7, endianaccess

    #ifdef __riscv_xlen
        #if __riscv_xlen == 64
            mv s8, s4       # setEndianness(write)
            jal s9, setendianness
            li t0, 0x3132333435363738
            sd t0, 0(s3)  
            ld t3, 0(s3)             
            RVTEST_SIGWRITE(x3, t3)
            jal s7, endianaccess
        #endif
    #else
        ERROR: __riscv_xlen not defined
    #endif
     # set up PMP so user and supervisor mode can access full address space

    RVTEST_GOTO_MMODE   # set up everything in M-mode
    jr s6   # return to endianM/S/U file (return address was stored in s6)





setendianness:  //function to set/clear the bits depending on the endianness specified by the covergroups
    RVTEST_GOTO_MMODE   # set up everything in M-mode    
    beq s10, x0, onlysstatus3 //branch if endianness is given from sstatus (3 bc used by 3rd cp in endianS)
    beqz s8, littleendian      # # if s8 = 1, bigendian, otherwise littleendian
    #ifdef __riscv_xlen
        #if __riscv_xlen == 64
            csrrs t6, mstatus, s1   # for RV64, set mstatus
            csrr  t4, mstatus        # get the *updated* value after setting
            RVTEST_SIGWRITE(x3, t4)    
        #elif __riscv_xlen == 32
            csrrs t6, mstatush, s1  # for RV32, set mstatush
            csrr t4, mstatush       # get the *updated* value after setting
            RVTEST_SIGWRITE(x3, t4)   
        #endif
    #else
        ERROR: __riscv_xlen not defined
    #endif
    j change

    littleendian:
        #ifdef __riscv_xlen
            #if __riscv_xlen == 64
                csrrc t6, mstatus, s1   # for RV64, clear mstatus            
                csrr t4, mstatus        # get the *updated* value after setting
                RVTEST_SIGWRITE(x3, t4) 
            #elif __riscv_xlen == 32
                csrrc t6, mstatush, s1  # for RV32, clear mstatush
                csrr t4, mstatush       # get the *updated* value after setting
                RVTEST_SIGWRITE(x3, t4) 
            #endif
        #else
            ERROR: __riscv_xlen not defined
        #endif
        j change


    onlysstatus3: //used for 3rd EndianS coverpoint: cp_sstatus_ube_endianness_* (endianness given in sstatus.UBE)
        li a0, 1         # a0 = 1, change to supervisor mode ->to write to sstatus
        RVTEST_GOTO_LOWER_MODE Smode 
        nop
        beqz s8, littleendian3      # little endian
        csrrs t6, sstatus, s1   # set sstatus.UBE
        nop
        csrr t4, sstatus       # get the *updated* value after setting
        RVTEST_SIGWRITE(x3, t4) 
        j change

        littleendian3:
            csrrc t6, sstatus, s1   # clear sstatus.UBE
            csrr t4, sstatus        # get the *updated* value after setting
            RVTEST_SIGWRITE(x3, t4) 
            j change

    change: // Switch privilege mode
        RVTEST_GOTO_MMODE   # set up everything in M-mode
        li t2, 0
        beq s11, t2, use_umode
        li t2, 1
        beq s11, t2, use_smode
        li t2, 3
        beq s11, t2, use_mmode

        use_umode:
            RVTEST_GOTO_LOWER_MODE Umode
            RVTEST_SIGWRITE(x3, s11) 
            jr s9
        use_smode:
            RVTEST_GOTO_LOWER_MODE Smode
            RVTEST_SIGWRITE(x3, s11)
            jr s9
        use_mmode:
            RVTEST_GOTO_MMODE
            RVTEST_SIGWRITE(x3, s11) 
            jr s9


endianaccess:
    // Try all the accesses to make sure they work for the endianness
    mv s8, s5   # setEndianness(read)
    jal s9, setendianness
    lb  t3, 0(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lb  t3, 1(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lb  t3, 2(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lb  t3, 3(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lb  t3, 4(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lb  t3, 5(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lb  t3, 6(s3)
    RVTEST_SIGWRITE(x3, t3)
    lb  t3, 7(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 0(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 1(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 2(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 3(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 4(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 5(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 6(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lbu t3, 7(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lh  t3, 0(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lh  t3, 2(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lh  t3, 4(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lh  t3, 6(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lhu t3, 0(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lhu t3, 2(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lhu t3, 4(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lhu t3, 6(s3)
    RVTEST_SIGWRITE(x3, t3) 
    lw t3, (s3)
    RVTEST_SIGWRITE(x3, t3) 
    lw t3, 4(s3)
    RVTEST_SIGWRITE(x3, t3) 
    #ifdef __riscv_xlen
        #if __riscv_xlen == 64
            lwu  t3, 0(s3) # long loads for RV64
            RVTEST_SIGWRITE(x3, t3) 
            lwu  t3, 4(s3)
            RVTEST_SIGWRITE(x3, t3) 
            ld   t3, 0(s3)
            RVTEST_SIGWRITE(x3, t3) 
        #endif
    #else
        ERROR: __riscv_xlen not defined
    #endif
    jr s7   # return (return address was stored in s7)


