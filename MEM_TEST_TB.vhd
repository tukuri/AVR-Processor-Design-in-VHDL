-- Testbench Name: 
--   MEM_TEST_TB
--
-- Description: 
--   This is a testbench that thoroughly tests the Data Memory Access Unit. The testbench uses MEM_TEST entity, 
--   which combines data memory access unit, register set, and the control unit. One cycle instructions(e.g. MOV,
--	 LDI), two cycle instructions(e.g. Load, Load with inc/dec, Store with inc/dec, Push, Pop) and three cycle 
--	 instructions(LDS, STS) are tested through the test vectors. For LDS and STS, the second instruction is
--	 input from ProgDB. Also, extra credit is implemented in this homework. general registers of address 0-31 and
--   I/O ports of address 32-95 are mapped into data memory space. The reads and writes to these addresses are
--	 redirected to internal registers, not to the external memory bus. The testbench inspects the values and timings 
--   of DataAB, DataDB, DataRd, and DataWr. Since we are assuming that the memory access has a time delay, the 
--	 dataDB will be valid a certain amount of time after the rising edge of second clock for two cycle instructions.
--	 For Load instructions, DataRd must be pulled down before dataDB gets valid. For Store instructions, DataWr
--	 must be pulled down after the DataDB is valid. For testing Push/Pop instructions, the testbench follows the
--	 sequence of Push-and-Pop to emulate the common usage of Push/Pops. It checks if we are pushing to correct
--	 addresses and popping from the corresponding addresses. Stack Pointer(SP) is r94:r93.
--
-- Revision History
--   02/01/2019  Sung Hoon Choi  Created
--	 02/05/2019	 Sung Hoon Choi	 Added testvectors for IR, DataAB, and DataDB
--	 02/09/2019	 Sung Hoon Choi  Initial simulation
--   02/10/2019	 Sung Hoon Choi  Added PUSH/POP tests
--	 02/11/2019  Sung Hoon Choi  Added comments


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.opcodes.all;
use xil_defaultlib.constants.all;


entity MEM_TEST_TB is
end MEM_TEST_TB;

architecture Behavioral of MEM_TEST_TB is

-- Instruction Register that holds current instruction
signal IR: opcode_word;
-- Second instruction for three cycle instructions (LDS, STS)
signal ProgDB: std_logic_vector(15 downto 0) := "0000000000000000";
-- Restes stack pointer
signal Reset: std_logic:= '1';
-- Source clock
signal clock: std_logic := '0';
-- Data Address Bus
signal DataAB: std_logic_vector(15 downto 0) := "0000000000000000";
-- Data Data Bus
signal DataDB: std_logic_vector(7 downto 0) := "00000000";
-- Data Read signal (Must be pulled down and go back for Load instructions)
signal DataRd: std_logic;
-- Data Write signal (Must be pulled down and go back for Store instructions)
signal DataWr: std_logic;
-- Indicates the end of simulation
signal END_SIM: boolean := FALSE;

-- Number of bits of instruction register
constant IR_SIZE: integer := 16;
-- Number of bits of address
constant ADDR_SIZE: integer := 16;
-- Number of bits of data
constant DATA_SIZE: integer := 8;
-- Number of test vector entries
constant VECTOR_SIZE: integer := 55;


-- Manual DataDB input for load instructions --
type DataDBIn_Vector_Type is array (0 to VECTOR_SIZE-1) of std_logic_vector(DATA_SIZE-1 downto 0);

-- Type definitions for testvectors
type IR_Test_Vector_Type is array (0 to VECTOR_SIZE-1) of opcode_word; -- IR
type DataAB_Test_Vector_Type is array (0 to VECTOR_SIZE-1) of std_logic_vector(ADDR_SIZE-1 downto 0); --DataAB
type DataDB_Test_Vector_Type is array (0 to VECTOR_SIZE-1) of std_logic_vector(DATA_SIZE-1 downto 0); --DataDB


-- Test Vectors description --
-- The testbench utilizes IR test vectors, DataAB vectors, and DataDB vectors to test the correctness of the
-- Data Memory Access Unit. It first initializes registers by using LDI instruction. LDI instructions are checked
-- by using these initialized registers throughout the testbench. Then, it goes through two-cycle load instructions. 
-- For load instructions, we manually load the data by using DataDBIn vectors. We check dataAB and dataRd since 
-- dataDB is manually input by the user for Load instructions. dataDB must be toggled to read the data
-- (Timings will be discussed below, on the lower section of the code) 
-- Then, we go through checking two-cycle store instructions. For store instructions, we check DataAB, DataDB, and 
-- DataWr. Note that for storing instructions, we input "Z" to the data bus so that we can receive the dataDB(out) 
-- from the system. DataWr must be toggled to write a value to external memory or internal addresses(0 ~ 95)
-- Then, we go through three-cycle instructions(LDS, STS). For these instructions, we give the second instruction
-- (address) using the ProgDB on the second cycle. We check address, data, read(LDS) and write(STS) signals.
-- Finally, for push/pop instructions, we first initialize the stack pointer(r94:r93). 
-- Then, we push two registers and pop two registers to check if they work correctly. Note that
-- we've implemented the extra credit, so the system redirects the reads/writes when the target address is within 
-- the address range 0-95. To do so, we do not toggle dataRd and dataWr when we are redirecting to address 0~95. 

-- Test vector for IR(Instruction Register)
signal IR_Test_Vector : IR_TEST_VECTOR_TYPE := ( -- one cycle (register initializations) --
                                                "1110101000000000", -- LDI r16, xA0
                                                "1110101000010001", -- LDI r17, xA1
                                                "1110101000100010", -- LDI r18, xA2
                                                "1110101000110011", -- LDI r19, xA3
                                                "1110101001000100", -- LDI r20, xA4
                                                "1110101001010101", -- LDI r21, xA5
                                                "1110101001100110", -- LDI r22, xA6
                                                "1110101001110111", -- LDI r23, xA7
                                                "1110101010001000", -- LDI r24, xA8
                                                "1110101010011001", -- LDI r25, xA9
                                                "1110101010101010", -- LDI r26, xAA
                                                "1110101010111011", -- LDI r27, xAB
                                                "1110101011001100", -- LDI r28, xAC
                                                "1110101011011101", -- LDI r29, xAD
                                                "1110101011101110", -- LDI r30, xAE
                                                "1110101011111111", -- LDI r31, xAF
                                                "0010111000001010", -- MOV r0, r26
                                                "0010111110111010", -- MOV r27, r26
                                                "0010111011110001", -- MOV r15,  r17        
                                                -- Two cycles--       Instruction  destination   XYZ after inst.
                                                "1001000000011100", -- LD r1,  X    r1 = x30,     X=xAAAA
                                                "1001000000101101", -- LD r2,  X+   r2 = x30,     X=xAAAB 
                                                "1001000010101100", -- LD r10, X    r10 = x35,    X=xAAAB
                                                "1001000000111110", -- LD r3, -X    r3 = x30,     X=xAAAA
                                                "1001000001001001", -- LD r4, Y+    r4 = x40,     Y=xADAD
                                                "1001000010101001", -- LD r10, Y+   r10 = x45,    Y=xADAE
                                                "1001000011001010", -- LD r12, -Y   r12 = x45,    Y=xADAD
                                                "1001000100000001", -- LD r16, Z+   r16 = x50,    Z=xAFAF
                                                "1001000100110010", -- LD r19, -Z   r19 = x55,    Z=xAFAE
                                                "1000000001011011", -- LDD r5, Y+3  r5 = x60      Y+3=xADB0
                                                "1000000100010111", -- LDD r17, Z+7 r17 = x70     Z+7=xAFB5 
                                                "1001001111101100", -- ST X, r30   (xAAAA) = xAE, X=xAAAA
                                                "1001001110001101", -- ST X+, r24  (xAAAA) = xA8, X=xAAAB
                                                "1001001100001100", -- ST X, r16   (xAAAB) = x50, X=xAAAB
                                                "1001001000101110", -- ST -X, r2   (xAAAA) = x30, X=xAAAA
                                                "1001001000111001", -- ST Y+, r3   (xADAD) = x30, Y=xADAE
                                                "1001001001001001", -- ST Y+, r4   (xADAE) = x40, Y=xADAF
                                                "1001001100011010", -- ST -Y, r17  (xADAE) = x70, Y=xADAE
                                                "1001001000010001", -- ST Z+, r1   (xAFAE) = x30, Z=xAFAF
                                                "1001001100100010", -- ST -Z, r18  (xAFAE) = xA2, Z=xAFAE
                                                "1000001111101111", -- STD Y+7, r30 (xADB5) = xAE, Y+7=xADB5
                                                "1000001000010001", -- STD Z+1, r1 (xAFAF) = x30   Z+1=xAFAF 
												-- Three cycles --
                                                "1001000001000000", -- LDS r4, x000F   redirect to internal
                                                "1001000100000000", -- LDS r16 x1000   external memory
                                                "1001001001000000", -- STS x0008, r4   redirect to internal 
                                                "1001001100000000", -- STS x1111, r16  external memory
												-- Push/Pop --
                                                "1110000000001111", -- LDI r16, x0F  r16=x0F
                                                "1110000000010111", -- LDI r17, x07  r17=x07
                                                "1001001100000000", -- LDS r16, x94  r94(SP_high)=x0F
                                                "1001001100010000", -- LDS r17, x93  r93(SP_low)=x07
                                                "1001001000001111", -- PUSH r0       Push AA
                                                "1001001010101111", -- PUSH r10      Push x45 50
                                                "0010111000001001", -- MOV r0, r25   r0 = xA9
                                                "0010111010101010", -- MOV r10, r26  r10= xAA
                                                "1001000010101111", -- POP r10       Pop x45 53
                                                "1001000000001111"  -- POP r0		 Pop xAA 54
                                                );

-- Manual input DataDB(in) for Loads										
signal DataDBIn_Vector: DataDBIn_Vector_Type := (
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "--------",
                                                "00110000", 
                                                "00110000",
                                                "00110101",
                                                "00110000",
                                                "01000000",
                                                "01000101",
                                                "01000101",
                                                "01010000",
                                                "01010101",
                                                "01100000",
                                                "01110000",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "--------", 
                                                "11111111",
                                                "ZZZZZZZZ",
                                                "ZZZZZZZZ",
                                                "--------", 
                                                "--------", 
                                                "--------", 
                                                "--------", 
                                                "--------", 
                                                "--------", 
                                                "--------", 
                                                "--------", 
                                                "--------", 
                                                "--------"
                                                );

-- Test vector for DataAB												
signal DataAB_Test_Vector : DataAB_Test_Vector_Type := (
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "----------------",
                                                        "1010101010101010", -- xAAAA LD
                                                        "1010101010101010", -- xAAAA
                                                        "1010101010101011", -- xAAAB
                                                        "1010101010101010", -- xAAAA
                                                        "1010110110101100", -- xADAC
                                                        "1010110110101101", -- xADAD
                                                        "1010110110101101", -- xADAD
                                                        "1010111110101110", -- xAFAE
                                                        "1010111110101110", -- xAFAE
                                                        "1010110110110000", -- xADB0
                                                        "1010111110110101", -- xAFB5 
                                                        "1010101010101010", -- xAAAA ST
                                                        "1010101010101010", -- xAAAA
                                                        "1010101010101011", -- xAAAB
                                                        "1010101010101010", -- xAAAA
                                                        "1010110110101101", -- xADAD
                                                        "1010110110101110", -- xADAE
                                                        "1010110110101110", -- xADAE
                                                        "1010111110101110", -- xAFAE
                                                        "1010111110101110", -- xAFAE
                                                        "1010110110110101", -- xADB5
                                                        "1010111110101111", -- xAFAF
                                                        "0000000000001111", -- x000F LDS ProgDB internal
                                                        "0001000000000000", -- x1000 LDS ProgDB external memory
                                                        "0000000000001000", -- x0008 STS ProgDB internal
                                                        "0001000100010001", -- x1111 STS ProgDB external memory
														-- Push/Pop --
                                                        "----------------",
                                                        "----------------",
                                                        "0000000001011110", 
                                                        "0000000001011101", 
                                                        "0000111100000111", -- PUSH to x0F07
                                                        "0000111100000110", -- PUSH to x0F06
                                                        "----------------", 
                                                        "----------------", 
                                                        "0000111100000110", -- POP from x0F06
                                                        "0000111100000111"  -- POP from x0F07
                                                        );


-- Test Vector for DataDB(out)
signal DataDB_Test_Vector : DataDB_Test_Vector_Type := (
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "--------",
                                                        "10101110", -- xAE
                                                        "10101000", -- xA8
                                                        "01010000", -- x50
                                                        "00110000", -- x30
                                                        "00110000", -- x30
                                                        "01000000", -- x40
                                                        "01110000", -- x70
                                                        "00110000", -- x30
                                                        "10100010", -- xA2
                                                        "10101110", -- xAE
                                                        "00110000", -- x30
                                                        "--------", 
                                                        "--------",
                                                        "10100001", -- xA1
                                                        "11111111", -- xFF                  
                                                        "--------",    
                                                        "--------",
                                                        "--------",      
                                                        "--------",
                                                        "10101010", -- xAA
                                                        "01000101", -- x45
                                                        "--------",
                                                        "--------",
                                                        "01000101", -- x45
                                                        "10101010"  -- xAA                
                                                        );
                                                                      
                                                        
component  MEM_TEST 
    port (
        IR      :  in     opcode_word;                      -- Instruction Register
        ProgDB  :  in     std_logic_vector(15 downto 0);    -- second word of instruction
        Reset   :  in     std_logic;                        -- system reset signal (active low)
        clock   :  in     std_logic;                        -- system clock
        DataAB  :  out    std_logic_vector(15 downto 0);    -- data address bus
        DataDB  :  inout  std_logic_vector(7 downto 0);     -- data data bus
        DataRd  :  out    std_logic;                        -- data read (active low)
        DataWr  :  out    std_logic                         -- data write (active low)
    );

end  component;

begin

clock <= not clock after 50 ns; -- clock generation

    -- Instantiate the test module
    UUT: MEM_TEST
    port map(
        IR => IR,
        ProgDB => ProgDB,
        Reset => Reset,
        clock  => clock,
        DataAB  => DataAB,
        DataDB => DataDB,
        DataRd => DataRd,
        DataWr => DataWr
        );

-- run_simulation
-- This process actually runs the test by using the test vectors above.
-- 
-- Test Description
-- 1-cycle init : Use LDI and MOV to initialize the registers for the testbench. 
--				  1 Cycle instructions can be checked by using these initialized registers throughout the 
--				  testbench and confirming that they have correct values.
-- 2-cycle loads: Check IR 10 ns after the first rising edge of clock
--				  Check DataRd 10ns after second falling edge. Must be pulled downto '0'.
--				  Input DataDB(in) 10ns before the end of second cycle.
-- 2-cycle stores:Set DataDB to 'Z's so that we can receive the DataDB(out) from the system.
--				  Check IR 10ns after the first rising edge of clock
--				  Check DataDB 10ns before the second falling edge. This is because for stores, dataDB(out) must be
--		          ready before DataWr goes down.
--			      Check DataWr 5ns after the second falling edge. Must be pulled downto '0'.
-- 3-cycle LDS :  We test two cases of LDS. One loads data from internal addresses(0~95) while another one loads
--			      data from external memory.
--				  For both cases, we input ProgDB manually and the ProgDB is to be latched by the system at the 
--				  end of the second cycle.
--				  For both internal and external cases, check DataAB 10 ns before the third falling edge
--				  For internal case, check DataRd 20 ns before the end of third cycle. Should "NOT" be pulled down
--				  For external case, check DataRd 20 ns before the end of third cycle. Should be pulled down
-- 3-cycle STS :  We test two cases of STS. One stores data to internal addresses(0~95 while another one stores 
--				  data to external memory.
--				  For both cases, we input ProgDB manually and the ProgDB is to be latched by the system at the
--				  end of the second cycle.
--			      For both internal and external cases, check DataAB 10 ns before the third falling edge
--				  For internal case, check DataWr 20 ns before the end of third cycle. Should "NOT" be pulled down
--				  For external case, check DataWr 20 ns before the end of third cycle. Should be pulled down
-- Push/Pop    :  Before we test push/pop, we first initialize the stack pointer.(r94:r93)
--				  Then we push two registers and pop the registers back.
--				  Checking Push/Pop is equivalent to checking Store/Load (respectively), except that we now 
--				  use the stack pointer's value as address, and that we pre-increment SP for POP and post-decrement
--			      SP.
run_simulation: process
begin
    ProgDB <= "ZZZZZZZZZZZZZZZZ"; -- Initialize ProgDB
    wait for 60 ns;
    
    -- 1 cycle instructions (LDI, MOV)
    for i in 0 to 18 loop 
        IR <=IR_Test_Vector(i); -- Input an instruction
        wait for 100 ns;
    end loop;     
    
    -- 2-cycle Loads
    for i in 19 to 29 loop 
        IR <= IR_Test_Vector(i); -- Input an instruction
        wait for 80 ns;
        assert(std_match(DataAB, DataAB_Test_Vector(i))) -- Check DataAB's value at the correct timing
            report "DataAB error at test case i = " & integer'image(i)
            severity ERROR;
        wait for 70 ns;
        assert(std_match(DataRd, '0')) -- Check DataRd's value at the correct timing. Must be pulled down.
            report "DataRd error at test case i = " & integer'image(i)
            severity ERROR;
        wait for 30 ns;
        DataDB <= DataDBIn_Vector(i); -- Input DataDB values since it's a Load instruction.
        wait for 20 ns;
    end loop;
    
    -- Stores
    DataDB <= "ZZZZZZZZ"; -- Initialize DataDB to 'Z's to receive the DataDB(out) from system
    for i in 30 to 40 loop 
        IR <= IR_Test_Vector(i); -- Input an instruction
        wait for 80 ns;
        assert(std_match(DataAB, DataAB_Test_Vector(i))) -- Check DataAB
            report "DataAB error at test case i = " & integer'image(i)
            severity ERROR;
        wait for 50 ns;
        assert(std_match(DataDB, DataDB_Test_Vector(i))) -- Check DataDB(out) from system
            report "DataDB(out) error at test case i = " & integer'image(i)
            severity ERROR;
        wait for 15 ns;
        assert(std_match(DataWr, '0')) -- Check DataWr. DataWr must be pulled down to write a value.
            report "DataWr at test case i = " & integer'image(i)
            severity ERROR;
        wait for 55 ns;
    end loop;
    
    -- LDS --
    for i in 41 to 42 loop
        IR <= IR_Test_Vector(i); -- Input an instruction
        wait for 80 ns;
        ProgDB <= DataAB_Test_Vector(i); -- Input the second instruction(memory address)
        wait for 150 ns;
        assert(std_match(DataAB, DataAB_Test_Vector(i))) -- Check DataAB
            report "DataAB error at test case i = " & integer'image(i)
            severity ERROR;
        wait for 40 ns;
        if(i=41) then -- if Loading from internal address (0~95)
            assert(std_match(DataRd, '1')) -- DataRd must stay high since it's loading from internal addresses.
                report "DataRd error at test case i = " & integer'image(i)
                severity ERROR;
        else -- if Loading from external memory
            assert(std_match(DataRd, '0')) -- DataRd must be pulled down to read a value from external memory.
                report "DataRd error at test case i = " & integer'image(i)
                severity ERROR;        
         end if;
        DataDB <= DataDBIn_Vector(i);
        wait for 30 ns;
    end loop;
    
    -- STS --
    DataDB <= "ZZZZZZZZ"; -- Initialize DataDB to 'Z's to receive DataDB(out) from the system.
    for i in 43 to 44 loop
        IR <= IR_Test_Vector(i); -- Input an instruction
        wait for 80 ns;
        ProgDB <= DataAB_Test_Vector(i); -- Input the second instruction (memory address)
        wait for 150 ns;
        assert(std_match(DataAB, DataAB_Test_Vector(i))) -- Check DataAB
            report "DataAB error at test case i = " & integer'image(i)
            severity ERROR;
        assert(std_match(DataDB, DataDB_Test_Vector(i))) -- Check DataDB(out)
            report "DataDB error at test case i = " & integer'image(i)
            severity ERROR;
        wait for 40 ns;
        if (i=43) then -- If Storing to internal address (0~95)
            assert(std_match(DataWr, '1')) -- DataWr must stay high since it's storing to internal address
                report "DataWr error at test case i = " & integer'image(i)
                severity ERROR;
        else
            assert(std_match(DataWr, '0')) -- DataWr must be pulled down since it's storing to external memory
                report "DataWr error at test case i = " & integer'image(i)
                severity ERROR;        
        end if;
        wait for 30 ns;
     end loop;
     
     -- PUSH/POP --
     -- Prepare for PUSH/POP instructions --
	 -- Intialize the stack pointer(r94:r93)--
    IR <= IR_Test_Vector(45); --r16 = x0F
    wait for 100 ns;
    IR <= IR_Test_Vector(46); --r17 = x07
    wait for 100 ns;
    IR <= IR_Test_Vector(47); -- r94(SP_high) = r16
    wait for 80 ns;
    ProgDB <= DataAB_Test_Vector(47); -- 
    wait for 220 ns;
    IR <= IR_Test_Vector(48); -- r93(SP_low) = r17
    wait for 80 ns;
    ProgDB <= DataAB_Test_Vector(48); --(r94:r93=SP=r16:r17=x0F07)
    wait for 220 ns;
    
     --PUSH/POPS--
    for i in 49 to 54 loop
        IR <= IR_Test_Vector(i);
        wait for 80 ns;
            assert(std_match(DataAB, DataAB_Test_Vector(i))) -- For both PUSH and POP, check DataAB
                report "DataAB error at test case i = " & integer'image(i)
                severity ERROR;
        wait for 20 ns;
        if(i < 51) then  -- For PUSH, check if correct data is being output
            assert(std_match(DataDB, DataDB_Test_Vector(i)))
                report "DataDB (out) error at test case i = " & integer'image(i)
                severity ERROR;
        end if;
        wait for 50 ns;
        if(i > 52) then
            assert(std_match(DataRd, '0')) -- For POP, check DataRd. It must be pulled down to read(pop)
                report "DataRd error at test case i = " & integer'image(i)
                severity ERROR;
        end if;
        if(i< 51) then
            assert(std_match(DataWr, '0')) -- For PUSH, check DataWr. It must be pulled down to write(push)
                report "DataWr error at test case i = " & integer'image(i)
                severity ERROR;
        end if;
        wait for 50 ns;
     end loop;
     
    END_SIM <= TRUE; 
    wait;
end process;
end Behavioral;
