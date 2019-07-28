library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.opcodes.all;

-- Testbench Name: 
--   REG_TEST_TB
--
-- Description: 
--   This is a testbench that thoroughly tests the general purpose register array unit by using the testvectors.
--   The testvectors include IR test vector, RegIn test vector, RegAOut test vector, and RegBOut test vector.
--   The IR testvectors go through all of instructions listed in Homework 2 (except MUL, which is for extra credit).    
--   Since REG_TEST module does not include ALU unit, we do not assume that the RegIn testvectors actually match
--   the result of ALU operations. The purpose of this testbench is to test the functionality and timing of 
--   loading data to register array and register outputs, not to test if it actually calculates the output(RegIn)
--   correctly. We use the for-loop to go through all instructions and use assert statements on RegAOut and RegBOut
--   right before the rising edge of a clock to check if both operands are ready on bus A and bus B for instructions
--   executions.
-- Revision History
--   01/24/2019  Sung Hoon Choi  Created
--   01/25/2019  Sung Hoon Choi  Completed the code
--   01/27/2019  Sung Hoon Choi  Ran the first simulation
--   02/01/2019  Sung Hoon Choi  Wrote the testvectors for IR, RegIn,, RegAOut, and RegBOut
--   02/03/2019  Sung Hoon Choi  Added comments

entity REG_TEST_TB is

end REG_TEST_TB;

architecture Behavioral of REG_TEST_TB is

signal IR: opcode_word; -- Current instruction to be executed
signal CLK : std_logic := '1'; -- Source clock
signal Regin: std_logic_vector(7 downto 0) := "00000000"; -- The result to be written to register array
signal RegAOut: std_logic_vector(7 downto 0) := "00000000"; -- The value to be output on operand bus A
signal RegBOut: std_logic_vector(7 downto 0) := "00000000"; -- The value to be output on operand bus B
signal END_SIM: boolean := FALSE;

constant IR_SIZE: integer := 16;     -- Number of bits per instruction
constant REGIN_SIZE: integer := 8;   -- Number of bits of RegIn
constant VECTOR_SIZE: integer := 62; -- Number of testvectors
constant NUM_REGS: integer := 32;    -- Number of general purpose registers in Register Array

-- Type definitions for testvectors
type IR_Test_Vector_Type is array (0 to VECTOR_SIZE-1) of opcode_word; -- IR
type RegIn_Test_Vector_Type is array (0 to VECTOR_SIZE-1) of std_logic_vector(REGIN_SIZE-1 downto 0); --RegIn
type RegOut_Test_Vector_Type is array (0 to VECTOR_SIZE-1) of std_logic_vector(REGIN_SIZE-1 downto 0); --RegOut

-- Test Description
-- 1. For the instructions that only require one operand, we do not care about the value of RegBOut. This is because
--    our design has a MUX outside the register array unit, which allows selecting immediate values instead of 
--    RegBOut as the second operand (operand B bus)
-- 2. For the instructions that do not save the result in a register (e.g. BSET, BCLR, CP, CPC, CPI), we set RegIn to
--    zero. This is because we turn off EnableIn signal of the register array to disable writing into registers set
--    when executing these instructions. Thus, we don't care about RegIn values for these instructions.
-- 3. Since REGTESTE does not include an ALU unit, we do not assume RegIn to actually match the result of actual
--    arithmetic operations. In this testbench, we are not trying to examine if ALU operations work, but to examine 
--    if the register set successfully loads data and outputs the correct data through RegAOut and RegBOut at correct 
--    timing.
--
--               RegAOut RegBOut    RegIn  
-- ADD r0, r0       U      U         r0=x20   When we begin the simulation, every register has "undefined" values. 
-- ADD r1, r1       U      U         r1=x21   Thus, we need to load data to all registers first.
-- ADD r2, r2       U      U         r2=x22
-- ADD r3, r3       U      U         r3=x23
-- ADD r4, r4       U      U         r4=x24
-- ADD r5, r5       U      U         r5=x25
-- ADD r6, r6       U      U         r6=x26
-- ADD r7, r7       U      U         r7=x27
-- ADD r8, r8       U      U         r8=x28
-- ADD r9, r9       U      U         r9=x29
-- ADD r10, r10     U      U         r10=x2A
-- ADD r11, r11     U      U         r11=x2B
-- ADD r12, r12     U      U         r12=x2C
-- ADD r13, r13     U      U         r13=x2D
-- ADD r14, r14     U      U         r14=x2E
-- ADD r15, r15     U      U         r15=x2F
-- ADD r16, r16     U      U         r16=x30
-- ADD r17, r17     U      U         r17=x31
-- ADD r18, r18     U      U         r18=x32
-- ADD r19, r19     U      U         r19=x33
-- ADD r20, r20     U      U         r20=x34                                                        
-- ADD r21, r21     U      U         r21=x35
-- ADD r22, r22     U      U         r22=x36
-- ADD r23, r23     U      U         r23=x37
-- ADD r24, r24     U      U         r24=x38
-- ADD r25, r25     U      U         r25=x39
-- ADD r26, r26     U      U         r26=x3A
-- ADD r27, r27     U      U         r27=x3B
-- ADD r28, r28     U      U         r28=x3C
-- ADD r29, r29     U      U         r29=x3D
-- ADD r30, r30     U      U         r30=x3E 
-- ADD r31, r31     U      U         r31=x3F   Finished loading data to all registers
-- ADC r0, r1       r0=x20 r1=x21    r0=x41
-- ADD r1, r3       r1=x21 r3=x23    r1=x44
-- AND r2, r5       r2=x22 r5=x25    r2=xA3
-- ANDI r16, x1F    r16=x30 r15=x2F  r15=xBE
-- ASR r17          r17=x31 r5=x25   r17=x18
-- BSET 6           r6=x26  r8=x28   (00000000) EnableIn off
-- BCLR 0           r8=x28 r8=x28    (00000000) EnableIn off
-- BLD r3, 2        r3=x23 r2=xA3    r3=x27
-- BST r4, 7        r4=x24 r23=x37   (00000000) EnableIn off
-- COM r5           r5=x25 r0=x41    r5=xDA
-- CP r6, r8        r6=x26 r8=x28    (00000000) EnableIn off
-- CPC r7, r10      r7=x27 r10=x2A   (00000000) EnableIn Off
-- CPI r24, xFF     r24=x38 r31=x3F  (00000000) EnableIn Off
-- DEC r9           r9=x29 r10=x2A   r9=x28
-- EOR r10, r15     r10=x2A r15=x2F  r10=x2A
-- INC r11          r11=x2B r3=x27   r11=x2C
-- LSR r12          r12=x2C r6=x26   r12=x1E
-- NEG r13          r13=x2D r1=x44   r13=xD3
-- OR r14, r16      r14=x2E r16=xBE  r14=xAE
-- ORI r16, xFF     r16=xBE r31=x3f  r16=xFF
-- ROR r16          r16=xFF r7=x27   r16=x1A 
-- SBC r19, r17     r19=x33 r17=x18  r19=x19
-- SBCI r21,xAA     r21=x35 r26=x3A  r21=x1C
-- SUB r25, r23     r25=x39 r23=x37  r25=x02
-- SUBI r28, x08    r28=x3C r8=x28   r28=x34
-- SWAP r31         r31=x3F r2=xA3   r31=xF3     
-- ADIW r27:r26, x0F r26=x3A r31=xF3 r26=x29 (Since ADIW takes two cycles, same IR is given twice)
-- ADIW r27:r26, x0F r27=x3B r31=xF3 r27=x3B 
-- SBIW r29:r28, x21 r28=x34 r17=x18 r28=x13 (Since SBIW takes two cycles, same IR is given twice)
-- SBIW r29:r28, x21 r29=x3D r17=x18 r29=x3D

-- Testvector for instruction register
signal IR_Test_Vector : IR_Test_Vector_Type := ("0000110000000000", --  ADD r0, r0 
                                                "0000110000010001", --  ADD r1, r1  
                                                "0000110000100010", --  ADD r2, r2  
                                                "0000110000110011", --  ADD r3, r3  
                                                "0000110001000100", --  ADD r4, r4  
                                                "0000110001010101", --  ADD r5, r5  
                                                "0000110001100110", --  ADD r6, r6  
                                                "0000110001110111", -- ADD r7, r7   
                                                "0000110010001000", -- ADD r8, r8   
                                                "0000110010011001", -- ADD r9, r9   
                                                "0000110010101010", -- ADD r10, r10 
                                                "0000110010111011", -- ADD r11, r11 
                                                "0000110011001100", -- ADD r12, r12 
                                                "0000110011011101", -- ADD r13, r13 
                                                "0000110011101110", -- ADD r14, r14 
                                                "0000110011111111", -- ADD r15, r15 
                                                "0000111100000000", -- ADD r16, r16 
                                                "0000111100010001", -- ADD r17, r17 
                                                "0000111100100010", -- ADD r18, r18 
                                                "0000111100110011", -- ADD r19, r19 
                                                "0000111101000100", -- ADD r20, r20 
                                                "0000111101010101", -- ADD r21, r21 
                                                "0000111101100110", -- ADD r22, r22 
                                                "0000111101110111", -- ADD r23, r23 
                                                "0000111110001000", -- ADD r24, r24 
                                                "0000111110011001", -- ADD r25, r25 
                                                "0000111110101010", -- ADD r26, r26 
                                                "0000111110111011", -- ADD r27, r27 
                                                "0000111111001100", -- ADD r28, r28 
                                                "0000111111011101", -- ADD r29, r29 
                                                "0000111111101110", -- ADD r30, r30 
                                                "0000111111111111", -- ADD r31, r31   --RegAOut RegBOut  RegIn--  
                                                "0001110000000001", -- ADC r0, r1       r0=x20 r1=x21    r0=x41
                                                "0000110000010011", -- ADD r1, r3       r1=x21 r3=x23    r1=x44
                                                "0010000000100101", -- AND r2, r5       r2=x22 r5=x25    r2=xA3
                                                "0111000100001111", -- ANDI r16, x1F    r16=x30 r15=x2F  r15=xBE
                                                "1001010100010101", -- ASR r17          r17=x31 r5=x25   r17=x18
                                                "1001010001101000", -- BSET 6           r6=x26  r8=x28   (00000000) EnableIn off
                                                "1001010010001000", -- BCLR 0           r8=x28 r8=x28    (00000000) EnableIn off
                                                "1111100000110010", -- BLD r3, 2        r3=x23 r2=xA3    r3=x27
                                                "1111101001000111", -- BST r4, 7        r4=x24 r23=x37   (00000000) EnableIn off
                                                "1001010001010000", -- COM r5           r5=x25 r0=x41    r5=xDA
                                                "0001010001101000", -- CP r6, r8        r6=x26 r8=x28    (00000000) EnableIn off
                                                "0000010001111010", -- CPC r7, r10      r7=x27 r10=x2A   (00000000) EnableIn Off
                                                "0011111110001111", -- CPI r24, xFF     r24=x38 r31=x3F  (00000000) EnableIn Off
                                                "1001010010011010", -- DEC r9           r9=x29 r10=x2A   r9=x28
                                                "0010010010101111", -- EOR r10, r15     r10=x2A r15=x2F  r10=x2A
                                                "1001010010110011", -- INC r11          r11=x2B r3=x27   r11=x2C
                                                "1001010011000110", -- LSR r12          r12=x2C r6=x26   r12=x1E
                                                "1001010011010001", -- NEG r13          r13=x2D r1=x44   r13=xD3
                                                "0010101011100000", -- OR r14, r16      r14=x2E r16=xBE  r14=xAE
                                                "0110111100001111", -- ORI r16, xFF     r16=xBE r31=x3f  r16=xFF
                                                "1001010100000111", -- ROR r16          r16=xFF r7=x27   r16=x1A 
                                                "0000101100110001", -- SBC r19, r17     r19=x33 r17=x18  r19=x19
                                                "0100101001011010", -- SBCI r21,xAA     r21=x35 r26=x3A  r21=x1C
                                                "0001101110010111", -- SUB r25, r23     r25=x39 r23=x37  r25=x02
                                                "0101000011001000", -- SUBI r28, x08    r28=x3C r8=x28   r28=x34
                                                "1001010111110010", -- SWAP r31         r31=x3F r2=xA3   r31=xF3
                                                "1001011000011111", -- ADIW r27:r26, x0F r26=x3A r31=xF3 r26=x29
                                                "1001011000011111", -- ADIW r27:r26, x0F r27=x3B r31=xF3 r27=x3B 
                                                "1001011110100001", -- SBIW r29:r28, x21 r28=x34 r17=x18 r28=x13
                                                "1001011110100001"  -- SBIW r29:r28, x21 r29=x3D r17=x18 r29=x3D
                                                 );

-- Testvector for RegIn                                                 
signal RegIn_Test_Vector: RegIn_Test_Vector_Type := ("00100000",-- x20
                                                    "00100001", -- x21
                                                    "00100010", -- x22
                                                    "00100011", -- x23
                                                    "00100100", -- x24
                                                    "00100101", -- x25
                                                    "00100110", -- x26
                                                    "00100111", -- x27
                                                    "00101000", -- x28
                                                    "00101001", -- x29
                                                    "00101010", -- x2A
                                                    "00101011", -- x2B
                                                    "00101100", -- x2C
                                                    "00101101", -- x2D
                                                    "00101110", -- x2E
                                                    "00101111", -- x2F
                                                    "00110000", -- x30
                                                    "00110001", -- x31
                                                    "00110010", -- x32
                                                    "00110011", -- x33
                                                    "00110100", -- x34
                                                    "00110101", -- x35
                                                    "00110110", -- x36
                                                    "00110111", -- x37
                                                    "00111000", -- x38
                                                    "00111001", -- x39
                                                    "00111010", -- x3A
                                                    "00111011", -- x3B 
                                                    "00111100", -- x3C
                                                    "00111101", -- x3D
                                                    "00111110", -- x3E
                                                    "00111111", -- x3F
                                                    "01000001", -- x41
                                                    "01000100", -- x44
                                                    "10100011", -- xA3
                                                    "10111110", -- xBE
                                                    "00011000", -- x18
                                                    "00000000", -- none
                                                    "00000000", -- none
                                                    "00100111", -- x27
                                                    "00000000", -- none
                                                    "11011010", -- xDA
                                                    "00000000", -- none
                                                    "00000000", -- none
                                                    "00000000", -- none
                                                    "00101000", -- x28
                                                    "00101010", -- x2A
                                                    "00101100", -- x2C
                                                    "00011110", -- x1E
                                                    "11010011", -- xD3
                                                    "10101110", -- xAE
                                                    "11111111", -- xFF
                                                    "00011010", -- x1A
                                                    "00011001", -- x19
                                                    "00011100", -- x1C
                                                    "00000010", -- x02
                                                    "00110100", -- x34
                                                    "11110011", -- xF3
                                                    "00101001", -- x29
                                                    "00111011", -- x3B
                                                    "00010011", -- x13
                                                    "00111101"  -- x3D
                                                    );
                                                    
-- Testvector for RegAOut                                               
signal RegAOut_Test_Vector : RegOut_Test_Vector_Type := ("00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000", -- loading register set complete.
                                                         "00100000", -- x20
                                                         "00100001", -- x21
                                                         "00100010", -- x22
                                                         "00110000", -- x30
                                                         "00110001", -- x31
                                                         "00100110", -- x26
                                                         "00101000", -- x28
                                                         "00100011", -- x23
                                                         "00100100", -- x24
                                                         "00100101", -- x25
                                                         "00100110", -- x26
                                                         "00100111", -- x27
                                                         "00111000", -- x38
                                                         "00101001", -- x29
                                                         "00101010", -- x2A
                                                         "00101011", -- x2B
                                                         "00101100", -- x2C
                                                         "00101101", -- x2D
                                                         "00101110", -- x2E
                                                         "10111110", -- xBE
                                                         "11111111", -- xFF
                                                         "00110011", -- x33
                                                         "00110101", -- x35
                                                         "00111001", -- x39
                                                         "00111100", -- x3C
                                                         "00111111", -- x3F
                                                         "00111010", -- x3A
                                                         "00111011", -- x3B
                                                         "00110100", -- x34
                                                         "00111101" -- x3D
                                                         );

-- Testvector for RegBOut                                                       
signal RegBOut_Test_Vector : RegOut_Test_Vector_Type := ("00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000",
                                                         "00000000", -- loading register set complete.
                                                         "00100001", --x21
                                                         "00100011", --x23
                                                         "00100101", --x25
                                                         "00101111", --x2F
                                                         "00100101", --x25
                                                         "00101000", --x28
                                                         "00101000", --x28
                                                         "10100011", --xA3
                                                         "00110111", --x37
                                                         "01000001", --x41
                                                         "00101000", --x28
                                                         "00101010", --x2A
                                                         "00111111", --x3F
                                                         "00101010", --x2A
                                                         "00101111", --x2F
                                                         "00100111", --x27
                                                         "00100110", --x26
                                                         "01000100", --x44
                                                         "10111110", --xBE
                                                         "00111111", --x3F
                                                         "00100111", --x27
                                                         "00011000", --x18
                                                         "00111010", --x3A
                                                         "00110111", --x37
                                                         "00101000", --x28
                                                         "10100011", --xA3
                                                         "11110011", --xF3
                                                         "11110011", --xF3
                                                         "00011000", --x18
                                                         "00011000"  --x18
                                                         );
                                                                                                                 
component  REG_TEST  is
    
    port(
        IR       :  in  opcode_word;                        -- Instruction Register
        RegIn    :  in  std_logic_vector(7 downto 0);       -- input register bus
        clock    :  in  std_logic;                          -- system clock
        RegAOut  :  out std_logic_vector(7 downto 0);       -- register bus A out
        RegBOut  :  out std_logic_vector(7 downto 0)        -- register bus B out
    );
    end  component;
    
begin

CLK <= not CLK after 50 ns; -- clock generation

    -- Instantiate the test module
    UUT: REG_TEST
    port map(
        IR => IR,
        RegIn => RegIn,
        clock => CLK,
        RegAOut => RegAOut,
        RegBOut => RegBOut
        );
    
-- Run the simulation to test if correct RegAOut and RegBout are being output at correct timings, using 
-- the testvectors and assert statements. RegIn is input 10ns before the next rising edge of the clock. 
-- OperandA and OperandB are checked 5 ns before the next rising edge of the clock.
-- Note that for the first NUM_REGS test cases, we initialize the register array. Thus, we don't check
-- OperandA and OperandB in this initialization stage.
run_simulation: process
begin
    END_SIM <= FALSE;
    wait for 10 ns;
    for i in 0 to VECTOR_SIZE-1 loop
        IR <= IR_Test_Vector(i); -- Input IR after the rising edge of clock
        wait for 80 ns;
        RegIn <= RegIn_Test_Vector(i); -- Input RegIn before the rising edge of clock
        wait for 5 ns;
          if(i >= NUM_REGS) then -- For i = 0~NUM_REGS-1, we are loading initial data to register array.
            assert(std_match(RegAOut,RegAOut_Test_Vector(i)))
                report "RegAOut error at test case i = " & integer'image(i)
                severity ERROR;
            assert(std_match(RegBOut,RegBOut_Test_Vector(i)))
                report "RegBOut error at test case i = " & integer'image(i)
                severity ERROR;
          end if;
        wait for 15 ns;
    end loop;
    END_SIM <= TRUE;
    wait;
 end process;

end Behavioral;
