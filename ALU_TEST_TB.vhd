--------------------------------------------------------------------------------
--
-- ALU_TEST_TB.vhd
--
-- This is the testbench for testing the arithmetic and logic unit. The 
-- stimulus signals consist of the actual signals that would feed into the 
-- ALU block (and associated muxes) in the full CPU. These are the instruction 
-- register (which needs to be decoded by the control unit), OperandA and 
-- OperandB (from the register array), and the system clock. The ALU is 
-- expected to output a result appropriate for the instruction being executed 
-- and update the status flags appropriately.
--
-- Revision History:
--     02/04/19    Garret Sullivan    Initial revision
--     02/04/19    Garret Sullivan    Updated comments and constants
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.opcodes.all;
use xil_defaultlib.constants.all;


--
-- ALU_TEST_TB
--
-- Description:
--     This is the ALU testbench entity. As such, there are no inputs or 
--     outputs. The architecture consists of generating stimulus signals for 
--     the ALUTESTE entity, which contains all of the necessary blocks for the 
--     ALU to function, and checking that the outputs of the entity are 
--     correct. The testbench works by putting an instruction on IR, along with 
--     values on OperandA and OperandB, slightly after the rising edge of a 
--     clock. The value of OperandB may be X for single operand instructions, 
--     and, since the register array is not present in this test bench, the 
--     bits in IR corresponding to register selection may also be undefined.
--     The control unit is then expected to decode the instruction and 
--     communicate with the ALU appropriately to generate the correct result, 
--     which is checked just before the next rising edge. The status bits 
--     should be updated after that next rising edge and thus are checked just 
--     before the following rising edge (i.e., one clock later than the result).
--
-- Inputs:
--     None
--
-- Outputs:
--     None
--

entity ALU_TEST_TB is

end ALU_TEST_TB;


architecture TB_ARCHITECTURE of ALU_TEST_TB is

    -- testing signals to connect directly to ALUTESTE
    signal IR       : opcode_word;                           -- current instruction
    signal OperandA : std_logic_vector(REG_SIZE-1 downto 0); -- value on A bus
    signal OperandB : std_logic_vector(REG_SIZE-1 downto 0); -- value on B bus
    signal CLK      : std_logic;                             -- system clock
    signal Result   : std_logic_vector(REG_SIZE-1 downto 0); -- ALU calc result
    signal StatReg  : std_logic_vector(REG_SIZE-1 downto 0); -- ALU status flags

    -- whether the simulation is finished or not
    signal END_SIM  : BOOLEAN := FALSE;
    
    -- number of test vectors
    constant NUM_VECTORS : integer := 51;
    
    -- array type definitions to hold the test vectors
    type IRTestVectorType is array (0 to NUM_VECTORS-1) of opcode_word;
    type BusTestVectorType is array (0 to NUM_VECTORS-1) of std_logic_vector(7 downto 0);
    
    -- IR test vectors: the comment specifies the instruction and an immediate 
    -- operand if present
    signal IRTestVector : IRTestVectorType := ("1001010001001000", -- BSET 4
                                               "1001010000101000", -- BSET 2
                                               "1001010001111000", -- BSET 7
                                               "1001010000001000", -- BSET 0
                                               "1001010001101000", -- BSET 6
                                               "1001010000011000", -- BSET 1
                                               "1001010000111000", -- BSET 3
                                               "1001010001011000", -- BSET 5
                                               
                                               "1001010011001000", -- BCLR 4
                                               "1001010010101000", -- BCLR 2
                                               "1001010011111000", -- BCLR 7
                                               "1001010010001000", -- BCLR 0
                                               "1001010011101000", -- BCLR 6
                                               "1001010010011000", -- BCLR 1
                                               "1001010010111000", -- BCLR 3
                                               "1001010011011000", -- BCLR 5
                                               
                                               OpADD,              -- ADD
                                               OpADC,              -- ADC
                                               OpADC,              -- ADC
                                               OpADD,              -- ADD
                                               OpADD,              -- ADD
                                               OpADD,              -- ADD
                                               OpADD,              -- ADD
                                               "1001011010XX0110", -- ADIW 38 (2 cycles)
                                               "1001011010XX0110", -- ADIW 38 (2 cycles)
                                               
                                               OpSUB,              -- SUB
                                               OpSBC,              -- SBC
                                               "01010011XXXX1011", -- SUBI 59
                                               "01010110XXXX1100", -- SUBI 108
                                               "1001011111XX1111", -- SBIW 63 (2 cycles)
                                               "1001011111XX1111", -- SBIW 63 (2 cycles)
                                               
                                               OpCP,               -- CP
                                               OpCPC,              -- CPC
                                               "00110110XXXX0100", -- CPI 100
                                               
                                               OpINC,              -- INC
                                               OpDEC,              -- DEC
                                               
                                               OpAND,              -- AND
                                               "01110101XXXX0101", -- ANDI 01010101
                                               OpCOM,              -- COM
                                               OpEOR,              -- EOR
                                               OpOR,               -- OR
                                               "01101010XXXX1010", -- ORI 10101010
                                               
                                               OpASR,              -- ASR
                                               OpLSR,              -- LSR
                                               OpROR,              -- ROR
                                               OpROR,              -- ROR
                                               
                                               OpNEG,              -- NEG
                                               OpSWAP,             -- SWAP
                                               
                                               "1111101XXXXXX011", -- BST 3
                                               "1111101XXXXXX101", -- BST 5
                                               "1111100XXXXX0001"  -- BLD 1
                                              );

    -- OperandA test vectors: the comment specifies the instruction and the 
    -- first operand (with parenthesis indicating one byte of a two-byte value)                            
    signal OperandATestVector : BusTestVectorType := ("XXXXXXXX", -- BSET
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      
                                                      "XXXXXXXX", -- BCLR
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      
                                                      "10111011", -- ADD 187
                                                      "00110001", -- ADC 49
                                                      "10110100", -- ADC -76
                                                      "10000000", -- ADD -128
                                                      "10000000", -- ADD -128
                                                      "11001000", -- ADD -56
                                                      "01010100", -- ADD 84
                                                      "11111100", -- ADIW 508 (252)
                                                      "00000001", -- ADIW 508 (1)
                                                      
                                                      "00101011", -- SUB 43
                                                      "01010111", -- SBC 87
                                                      "00011100", -- SUBI 28
                                                      "01101101", -- SBCI 109
                                                      "00010000", -- SBIW 1040 (16)
                                                      "00000100", -- SBIW 1040 (4)
                                                      "11101100", -- CP -20
                                                      "00011011", -- CPC 27
                                                      "01100011", -- CPI 99
                                                      
                                                      "00110110", -- INC 54
                                                      "00110110", -- DEC 54
                                                      
                                                      "00001111", -- AND
                                                      "01110100", -- ANDI
                                                      "00111101", -- COM
                                                      "10011100", -- EOR
                                                      "11011101", -- OR
                                                      "00001001", -- ORI
                                                      
                                                      "11000100", -- ASR
                                                      "11000100", -- LSR
                                                      "00111101", -- ROR
                                                      "00111101", -- ROR
                                                      
                                                      "01111111", -- NEG 127
                                                      "01011010", -- SWAP
                                                      "00001000", -- BST 3
                                                      "11011111", -- BST 5
                                                      "11111111"  -- BLD 1
                                                     );
                                   
    -- OperandB test vectors: the comment indicates the instruction and the 
    -- second operand if present. The second operand is X if it is unused, 
    -- except in the case of COM (in which case X is invalid)
    signal OperandBTestVector : BusTestVectorType := ("XXXXXXXX", -- BSET
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      
                                                      "XXXXXXXX", -- BCLR
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      "XXXXXXXX",
                                                      
                                                      "01100111", -- ADD 103
                                                      "10010001", -- ADC 145
                                                      "01001100", -- ADC 76
                                                      "10000000", -- ADD -128
                                                      "11111111", -- ADD -1
                                                      "00011011", -- ADD 27
                                                      "10011101", -- ADD -99
                                                      "XXXXXXXX", -- ADIW
                                                      "XXXXXXXX", -- ADIW
                                                      
                                                      "00101011", -- SUB 43
                                                      "00111000", -- SBC 56
                                                      "XXXXXXXX", -- SUBI
                                                      "XXXXXXXX", -- SUBI
                                                      "XXXXXXXX", -- SBIW
                                                      "XXXXXXXX", -- SBIW
                                                      
                                                      "11100111", -- CP -25
                                                      "00110010", -- CPC 50
                                                      "XXXXXXXX", -- CPI
                                                      
                                                      "XXXXXXXX", -- INC
                                                      "XXXXXXXX", -- DEC
                                                      
                                                      "00111100", -- AND
                                                      "XXXXXXXX", -- ANDI
                                                      "00001111", -- COM (can't use X here)
                                                      "00110011", -- EOR
                                                      "00001110", -- OR
                                                      "XXXXXXXX", -- ORI
                                                      
                                                      "XXXXXXXX", -- ASR
                                                      "XXXXXXXX", -- LSR
                                                      "XXXXXXXX", -- ROR
                                                      "XXXXXXXX", -- ROR
                                                      
                                                      "XXXXXXXX", -- NEG
                                                      "XXXXXXXX", -- SWAP
                                                      "XXXXXXXX", -- BST
                                                      "XXXXXXXX", -- BST
                                                      "XXXXXXXX"  -- BLD
                                                     );
    
    -- Result test vectors: the comment indicates the instruction and the 
    -- result of the instruction (except for logical operations, in which case 
    -- the result is the literal bit pattern)
    signal ResultTestVector : BusTestVectorType := ("--------", -- BSET
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    
                                                    "--------", -- BCLR
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    "--------",
                                                    
                                                    "00100010", -- ADD 187 + 103 = 290 (34)
                                                    "11000011", -- ADC 49 + 145 + 1 = 195
                                                    "00000000", -- ADC -76 + 76 = 0
                                                    "00000000", -- ADD -128 + -128 = -256 (0)
                                                    "01111111", -- ADD -128 + -1 = -129 (127)
                                                    "11100011", -- ADD -56 + 27 = -29
                                                    "11110001", -- ADD 84 + -99 = -15
                                                    "00100010", -- ADIW 508 + 38 = 548 (34)
                                                    "00000010", -- ADIW 508 + 38 = 548 (2)
                                                    
                                                    "00000000", -- SUB 43 - 43 = 0
                                                    "00011111", -- SBC 87 - 56 = 31
                                                    "11100001", -- SUBI 28 - 59 = -31
                                                    "00000001", -- SUBI 109 - 108 = 1
                                                    "11010001", -- SBIW 1040 - 63 = 977 (209)
                                                    "00000011", -- SBIW 1040 - 63 = 977 (3)
                                                    "--------", -- CP
                                                    "--------", -- CPC
                                                    "--------", -- CPI
                                                    
                                                    "00110111", -- INC 54 = 55
                                                    "00110101", -- DEC 54 = 53
                                                    
                                                    "00001100", -- AND
                                                    "01010100", -- ANDI
                                                    "11000010", -- COM
                                                    "10101111", -- EOR
                                                    "11011111", -- OR
                                                    "10101011", -- ORI
                                                    "11100010", -- ASR
                                                    "01100010", -- LSR
                                                    "00011110", -- ROR
                                                    "10011110", -- ROR
                                                    
                                                    "10000001", -- NEG 127 = -127
                                                    "10100101", -- SWAP
                                                    "--------", -- BST
                                                    "--------", -- BST
                                                    "11111101"  -- BLD
                                                   );
    
    -- Status Register test vectors: the comment indicates the instruction. 
    -- These vectors will not be checked until the cycle after the instruction 
    -- executes since the status flags must be latched first
    signal StatRegTestVector : BusTestVectorType := ("---1----", -- BSET
                                                     "---1-1--",
                                                     "1--1-1--",
                                                     "1--1-1-1",
                                                     "11-1-1-1",
                                                     "11-1-111",
                                                     "11-11111",
                                                     "11111111",
                                                     
                                                     "11101111", -- BCLR
                                                     "11101011",
                                                     "01101011",
                                                     "01101010",
                                                     "00101010",
                                                     "00101000",
                                                     "00100000",
                                                     "00000000",
                                                     
                                                     "--100001", -- ADD
                                                     "--010100", -- ADC
                                                     "--100011", -- ADC
                                                     "--011011", -- ADD
                                                     "--011001", -- ADD
                                                     "--110100", -- ADD
                                                     "--110100", -- ADD
                                                     "--------", -- ADIW
                                                     "---00000", -- ADIW
                                                     
                                                     "--100011", -- SUB
                                                     "--000001", -- SBC
                                                     "--110100", -- SUBI
                                                     "--100001", -- SBCI
                                                     "--------", -- SBIW
                                                     "---00001", -- SBIW
                                                     
                                                     "--100001", -- CP
                                                     "--110100", -- CPC
                                                     "--010100", -- CPI
                                                     
                                                     "---0000-", -- INC
                                                     "---0000-", -- DEC
                                                     
                                                     "---0000-", -- AND
                                                     "---0000-", -- ANDI
                                                     "---10101", -- COM
                                                     "---1010-", -- EOR
                                                     "---1010-", -- OR
                                                     "---1010-", -- ORI
                                                     
                                                     "---01100", -- ASR
                                                     "---00000", -- LSR
                                                     "---11001", -- ROR
                                                     "---10101", -- ROR
                                                     
                                                     "--010100", -- NEG
                                                     "--------", -- SWAP
                                                     "-1------", -- BST
                                                     "-0------", -- BST
                                                     "-0------"  -- BLD
                                                    );

    -- the ALU test entity
    component ALU_TEST is
        port (
            IR        :  in  opcode_word;                           -- Instruction Register
            OperandA  :  in  std_logic_vector(REG_SIZE-1 downto 0); -- first operand
            OperandB  :  in  std_logic_vector(REG_SIZE-1 downto 0); -- second operand
            clock     :  in  std_logic;                             -- system clock
            Result    :  out std_logic_vector(REG_SIZE-1 downto 0); -- ALU result
            StatReg   :  out std_logic_vector(REG_SIZE-1 downto 0)  -- status register
        );
    end component;

begin

    UUT: ALU_TEST
    port map (
        IR => IR,
        OperandA => OperandA,
        OperandB => OperandB,
        clock => CLK,
        Result => Result,
        StatReg => StatReg
    );
    
    -- stimulus process: output the stimulus signals just after the rising 
    -- clock edge and check the results just before the next rising clock edge
    process
    begin
        -- initial wait since clock starts low
        wait for 50 ns;
        
        -- loop through all the test vectors, plus 1 for final status check
        for i in 0 to NUM_VECTORS loop
            -- wait slightly after the rising clock edge
            wait for 10 ns;
            
            if i < NUM_VECTORS then
                -- output stimulus signals
                IR <= IRTestVector(i);
                OperandA <= OperandATestVector(i);
                OperandB <= OperandBTestVector(i);
            end if;
            
            wait for 80 ns;
            
            if i < NUM_VECTORS then
                -- check result accuracy
                assert(std_match(Result, ResultTestVector(i)))
                    report "Result error at test vector " & integer'image(i)
                    severity ERROR;
            end if;
                
            if i > 0 then
                -- check status accuracy (delayed by 1 clock)
                assert(std_match(StatReg, StatRegTestVector(i-1)))
                    report "StatReg error at test vector " & integer'image(i-1)
                    severity ERROR;
            end if;
            
            -- wait for the next rising clock edge
            wait for 10 ns;
        end loop;
        
        -- done with the simulation
        END_SIM <= TRUE;
        wait;
    end process;
    

    -- clock generation process: while the simulation is still running, 
    -- generate a 50% duty cycle, 100 ns clock
    process
    begin
        -- falling edge
        if END_SIM = FALSE then
            CLK <= '0';
            wait for 50 ns;
        else
            wait;
        end if;

        -- rising edge
        if END_SIM = FALSE then
            CLK <= '1';
            wait for 50 ns;
        else
            wait;
        end if;
    end process;

end TB_ARCHITECTURE;