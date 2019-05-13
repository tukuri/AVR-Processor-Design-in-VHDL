library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench Name: 
--   AVR_CPU_TB
--
-- Description: 
--   This is the testbench that thoroughly tests AVR_CPU.
--   AVR_CPU is an 8-bit RISC harvard architecture CPU that implements most of the instructions listed in
--	 ATMEL AVR Instruction Set Manual. It also satisfies the required number of clock cycles taken for each 
--   instruction.
--   AVR_CPU entity, DATA_MEMORY entity, and PROG_MEMORY entity are wired up together to run the test.
--   DATA_MEMORY is a 64 KByte RAM
--   PROG_MEMORY is a ROM that contains the instructions to be exectued for test. 
--   AVR_CPU fetches the instruction(ProgDB) from PROG_MEMORY by giving ProgAB to the PROG_MEMORY ROM.
--   While going through the set of instructions saved in ROM, the testbench inspects the correctness and timings
--   of ProgAB(Program Address), DataAB(Data Address), DataDB(Data Data), DataWr(Write signal for Data Memory), and
--   DataRd(Read signal for Data Memory).
--   Note that the active-low Reset is activated initially to reset the program counter(to X"0000") and 
--   stack pointer(to X"FFFF)
--	 
-- Revision History
--   02/22/2019  Sung Hoon Choi  Created
--	 02/23/2019	 Sung Hoon Choi	 Wired up AVR_CPU, DATA_MEMORY, and PROG_MEMORY
--	 02/24/2019	 Sung Hoon Choi  Completed writing testvectors for ProgAB, DataAB, DataDB, DataWr, and DataRd
--   02/24/2019	 Sung Hoon Choi  Passed all tests
--   02/25/2019	 Sung Hoon Choi  Updated comments


entity AVR_CPU_TB is
end AVR_CPU_TB;

architecture Behavioral of AVR_CPU_TB is

component  AVR_CPU  is
    port (
        ProgDB  :  in     std_logic_vector(15 downto 0);   -- program memory data bus
        Reset   :  in     std_logic;                       -- reset signal (active low)
        INT0    :  in     std_logic;                       -- interrupt signal (active low)
        INT1    :  in     std_logic;                       -- interrupt signal (active low)
        clock   :  in     std_logic;                       -- system clock
        ProgAB  :  out    std_logic_vector(15 downto 0);   -- program memory address bus
        DataAB  :  out    std_logic_vector(15 downto 0);   -- data memory address bus
        DataWr  :  out    std_logic;                       -- data memory write enable (active low)
        DataRd  :  out    std_logic;                       -- data memory read enable (active low)
        DataDB  :  inout  std_logic_vector(7 downto 0)     -- data memory data bus
    );
end  component;

component  DATA_MEMORY  is
    port (
        RE      : in     std_logic;             	    -- read enable (active low)
        WE      : in     std_logic;		                -- write enable (active low)
        DataAB  : in     std_logic_vector(15 downto 0); -- memory address bus
        DataDB  : inout  std_logic_vector(7 downto 0)   -- memory data bus
    );
end  component;

component  PROG_MEMORY  is
    port (
        ProgAB  :  in   std_logic_vector(15 downto 0);  -- program address bus
        Reset   :  in   std_logic;                      -- system reset
        ProgDB  :  out  std_logic_vector(15 downto 0)   -- program data bus
    );
end  component;

signal ProgDB  :  std_logic_vector(15 downto 0);   -- program memory data bus
signal Reset   :  std_logic;                       -- reset signal (active low)
signal clock   :  std_logic := '1';                -- system clock
signal ProgAB  :  std_logic_vector(15 downto 0);   -- program memory address bus
signal DataAB  :  std_logic_vector(15 downto 0);   -- data memory address bus
signal DataWr  :  std_logic;                       -- data memory write enable (active low)
signal DataRd  :  std_logic;                       -- data memory read enable (active low)
signal DataDB  :  std_logic_vector(7 downto 0);    -- data memory data bus
signal END_SIM :  std_logic := '0';                -- Indicates the end of simulation

-- number of test vectors
constant VECTOR_SIZE : natural := 786;

-- Test vector type for ProgAB and DataAB
type AddrTestVec_Type is array (0 to VECTOR_SIZE-1) of std_logic_vector(15 downto 0);
-- Test vector type for DataDB (Note that ProgDB, the program instructions are saved in ROM)
type DataTestVec_Type is array (0 to VECTOR_SIZE-1) of std_logic_vector(7 downto 0);

-- Test vector for DataRd (Read enable signal for DATA_MEMORY)
signal DataRdTestVector : std_logic_vector(0 to VECTOR_SIZE-1) := "111111111111111111010101111111111111111111111111111111111111111111111111011101011101011101010101010101010101010101111101011111011111101111101111111011111110111111101111111011111110111111101111111011111110111111101111111011111110111111101111111011111110111111101111111110111101111111011110111111101111011111110111101111111011110111111101110111101111110111101111110111101111101111011110111101111111011111101111111011111101111111011111110111111101111111011110111110111101111110111110111101111011110111111101111110111111101111101111011111101111011111011110111111011110111111101111011111110111101111110111101111110111101111111011110111111011110111111011110111110111101111101111011111011110111110---------------------------------------------------------1110-----------------------------------";
-- Test vector for DataWr (Write enable signal for DATA_MEMORY)
signal DataWrTestVector : std_logic_vector(0 to VECTOR_SIZE-1) := "111111111111010101111111110111011101010101010101010101010101010101010101110111110111110111111111111111111111111111010111111011111110111110111111101111111011111110111111101111111011111110111111101111111011111110111111101111111011111110111111101111111011111110111111111011110111111101111011111110111101111111011110111111101111011111110111011110111111011110111111011110111110111101111011110111111101111110111111101111110111111101111111011111110111111101111011111011110111111011111011110111101111011111110111111011111110111110111101111110111101111101111011111101111011111110111101111111011110111111011110111111011110111111101111011111101111011111101111011111011110111110111101111101111011111011---------------------------------------------------------1011-----------------------------------";

-- Program Address Testvector
-- It is a testvector used to verify the correctness of ProgAB
-- Note that for the flow-control instructions at the bottom of testvector (JMP, CALL, etc.), we don't care how 
-- the program address changes internally before the last cycle of the instruction. For example, JMP is a three
-- cycle instruction. For JMP, we don't care about the value of ProgAB for first and second cycle. We only care
-- if it jumps to the correct next address at the last cycle of the instruction. This is the reason why we have
-- Don't Cares (dashes) at the bottom of the testvectors.
-- For 2-cycle instructions such as PUSH/POP, LD/ST, Program Addresses are duplicated(thus, same progAB twice) 
-- to stay on the current instrcution for the entire 2 cycles. For LDS and STS, we increment the Program Address 
-- once at the first cycle to fetch the memory address(mmm...m) and then duplicate ProgAB (Thus, total 3 cycles)
signal ProgAddrTestVector : AddrTestVec_Type := (
    X"0000", X"0001", X"0002", X"0003", X"0004", 
    X"0005", X"0006", X"0007", X"0008", X"0009", 
    X"000A", X"000B", X"000B", X"000C", X"000C", 
    X"000D", X"000D", X"000E", X"000E", X"000F", 
    X"000F", X"0010", X"0010", X"0011", X"0012", 
    X"0013", X"0013", X"0014", X"0015", X"0016", 
    X"0016", X"0017", X"0018", X"0019", X"0019", 
    X"001A", X"001A", X"001B", X"001B", X"001C", 
    X"001C", X"001D", X"001D", X"001E", X"001E", 
    X"001F", X"001F", X"0020", X"0020", X"0021", 
    X"0021", X"0022", X"0022", X"0023", X"0023", 
    X"0024", X"0024", X"0025", X"0025", X"0026", 
    X"0026", X"0027", X"0027", X"0028", X"0028", 
    X"0029", X"0029", X"002A", X"002A", X"002B", 
    X"002B", X"002C", X"002C", X"002D", X"002D", 
    X"002E", X"002E", X"002F", X"002F", X"0030", 
    X"0030", X"0031", X"0031", X"0032", X"0032", 
    X"0033", X"0033", X"0034", X"0034", X"0035", 
    X"0035", X"0036", X"0036", X"0037", X"0037", 
    X"0038", X"0038", X"0039", X"0039", X"003A", 
    X"003A", X"003B", X"003B", X"003C", X"003C", 
    X"003D", X"003D", X"003E", X"003E", X"003F", 
    X"003F", X"0040", X"0040", X"0041", X"0041", 
    X"0042", X"0042", X"0043", X"0043", X"0044", 
    X"0044", X"0045", X"0046", X"0046", X"0047", X"0048", X"0048", 
    X"0049", X"004A", X"004B", X"004C", X"004C", 
    X"004D", X"004D", X"004E", X"004F", X"0050", 
    X"0050", X"0051", X"0051", X"0052", X"0053", 
    X"0054", X"0055", X"0056", X"0056", X"0057", 
    X"0057", X"0058", X"0059", X"005A", X"005B", 
    X"005C", X"005C", X"005D", X"005D", X"005E", 
    X"005F", X"0060", X"0061", X"0062", X"0062", 
    X"0063", X"0063", X"0064", X"0065", X"0066", 
    X"0067", X"0068", X"0068", X"0069", X"0069", 
    X"006A", X"006B", X"006C", X"006D", X"006E", 
    X"006E", X"006F", X"006F", X"0070", X"0071", 
    X"0072", X"0073", X"0074", X"0074", X"0075", 
    X"0075", X"0076", X"0077", X"0078", X"0079", 
    X"007A", X"007A", X"007B", X"007B", X"007C", 
    X"007D", X"007E", X"007F", X"0080", X"0080", 
    X"0081", X"0081", X"0082", X"0083", X"0084", 
    X"0085", X"0086", X"0086", X"0087", X"0087", 
    X"0088", X"0089", X"008A", X"008B", X"008C", 
    X"008C", X"008D", X"008D", X"008E", X"008F", 
    X"0090", X"0091", X"0092", X"0092", X"0093", 
    X"0093", X"0094", X"0095", X"0096", X"0097", 
    X"0098", X"0098", X"0099", X"0099", X"009A", 
    X"009B", X"009C", X"009D", X"009E", X"009E", 
    X"009F", X"009F", X"00A0", X"00A1", X"00A2", 
    X"00A3", X"00A4", X"00A4", X"00A5", X"00A5", 
    X"00A6", X"00A7", X"00A8", X"00A9", X"00AA", 
    X"00AA", X"00AB", X"00AB", X"00AC", X"00AD", 
    X"00AE", X"00AF", X"00B0", X"00B1", X"00B2", 
    X"00B2", X"00B3", X"00B3", X"00B4", X"00B5", 
    X"00B5", X"00B6", X"00B6", X"00B7", X"00B8", 
    X"00B9", X"00BA", X"00BB", X"00BB", X"00BC", 
    X"00BC", X"00BD", X"00BE", X"00BE", X"00BF", 
    X"00BF", X"00C0", X"00C1", X"00C2", X"00C3", 
    X"00C4", X"00C4", X"00C5", X"00C5", X"00C6", 
    X"00C7", X"00C7", X"00C8", X"00C8", X"00C9", 
    X"00CA", X"00CB", X"00CC", X"00CD", X"00CD", 
    X"00CE", X"00CE", X"00CF", X"00D0", X"00D0", 
    X"00D1", X"00D1", X"00D2", X"00D3", X"00D4", 
    X"00D5", X"00D6", X"00D6", X"00D7", X"00D7", 
    X"00D8", X"00D9", X"00D9", X"00DA", X"00DA", 
    X"00DB", X"00DC", X"00DD", X"00DD", X"00DE", 
    X"00DE", X"00DF", X"00DF", X"00E0", X"00E0", 
    X"00E1", X"00E1", X"00E2", X"00E3", X"00E3", 
    X"00E4", X"00E4", X"00E5", X"00E6", X"00E7", 
    X"00E8", X"00E8", X"00E9", X"00E9", X"00EA", 
    X"00EB", X"00EB", X"00EC", X"00EC", X"00ED", 
    X"00EE", X"00EF", X"00F0", X"00F0", X"00F1", 
    X"00F1", X"00F2", X"00F3", X"00F3", X"00F4", 
    X"00F4", X"00F5", X"00F6", X"00F7", X"00F7", 
    X"00F8", X"00F8", X"00F9", X"00FA", X"00FA", 
    X"00FB", X"00FB", X"00FC", X"00FD", X"00FD", 
    X"00FE", X"00FE", X"00FF", X"0100", X"0100", 
    X"0101", X"0101", X"0102", X"0103", X"0104", 
    X"0105", X"0106", X"0106", X"0107", X"0107", 
    X"0108", X"0109", X"010A", X"010B", X"010B", 
    X"010C", X"010C", X"010D", X"010E", X"010F", 
    X"0110", X"0111", X"0111", X"0112", X"0112", 
    X"0113", X"0114", X"0115", X"0116", X"0116", 
    X"0117", X"0117", X"0118", X"0119", X"011A", 
    X"011B", X"011C", X"011C", X"011D", X"011D", 
    X"011E", X"011F", X"0120", X"0121", X"0122", 
    X"0122", X"0123", X"0123", X"0124", X"0125", 
    X"0126", X"0127", X"0128", X"0128", X"0129", 
    X"0129", X"012A", X"012B", X"012C", X"012D", 
    X"012E", X"012E", X"012F", X"012F", X"0130", 
    X"0131", X"0131", X"0132", X"0132", X"0133", 
    X"0134", X"0135", X"0135", X"0136", X"0136", 
    X"0137", X"0138", X"0138", X"0139", X"0139", 
    X"013A", X"013B", X"013C", X"013D", X"013D", 
    X"013E", X"013E", X"013F", X"0140", X"0141", 
    X"0141", X"0142", X"0142", X"0143", X"0144", 
    X"0144", X"0145", X"0145", X"0146", X"0147", 
    X"0147", X"0148", X"0148", X"0149", X"014A", 
    X"014A", X"014B", X"014B", X"014C", X"014D", 
    X"014E", X"014F", X"0150", X"0150", X"0151", 
    X"0151", X"0152", X"0153", X"0154", X"0155", 
    X"0155", X"0156", X"0156", X"0157", X"0158", 
    X"0159", X"015A", X"015B", X"015B", X"015C", 
    X"015C", X"015D", X"015E", X"015F", X"015F", 
    X"0160", X"0160", X"0161", X"0162", X"0162", 
    X"0163", X"0163", X"0164", X"0165", X"0166", 
    X"0167", X"0167", X"0168", X"0168", X"0169", 
    X"016A", X"016A", X"016B", X"016B", X"016C", 
    X"016D", X"016E", X"016E", X"016F", X"016F", 
    X"0170", X"0171", X"0171", X"0172", X"0172", 
    X"0173", X"0174", X"0175", X"0176", X"0176", 
    X"0177", X"0177", X"0178", X"0179", X"0179", 
    X"017A", X"017A", X"017B", X"017C", X"017D", 
    X"017E", X"017F", X"017F", X"0180", X"0180", 
    X"0181", X"0182", X"0182", X"0183", X"0183", 
    X"0184", X"0185", X"0186", X"0187", X"0188", 
    X"0188", X"0189", X"0189", X"018A", X"018B", 
    X"018B", X"018C", X"018C", X"018D", X"018E", 
    X"018F", X"0190", X"0190", X"0191", X"0191", 
    X"0192", X"0193", X"0193", X"0194", X"0194", 
    X"0195", X"0196", X"0197", X"0198", X"0198", 
    X"0199", X"0199", X"019A", X"019B", X"019B", 
    X"019C", X"019C", X"019D", X"019E", X"019F", 
    X"019F", X"01A0", X"01A0", X"01A1", X"01A1", 
    X"01A2", X"01A3", X"01A3", X"01A4", X"01A4", 
    X"01A5", X"01A6", X"01A7", X"01A8", X"01A8", 
    X"01A9", X"01A9", X"01AA", X"01AB", X"01AB", 
    X"01AC", X"01AC", X"01AD", X"01AE", X"01AF", 
    X"01B0", X"01B0", X"01B1", X"01B1", X"01B2", 
    X"01B3", X"01B3", X"01B4", X"01B4", X"01B5", 
    X"01B6", X"01B7", X"01B7", X"01B8", X"01B8", 
    X"01B9", X"01BA", X"01BA", X"01BB", X"01BB", 
    X"01BC", X"01BD", X"01BE", X"01BE", X"01BF", 
    X"01BF", X"01C0", X"01C1", X"01C1", X"01C2", 
    X"01C2", X"01C3", X"01C4", X"01C5", X"01C5", 
    X"01C6", X"01C6", X"01C7", X"01C8", X"01C8", 
    X"01C9", X"01C9", X"01CA", X"01CB", X"01CC", 
    X"01CC", X"01CD", X"01CD",
    -- flow control instructions(CALL, JMP, etc.) start
    X"01CE", X"----", X"----", X"01D1", X"----",X"01D3",
    X"01D4", X"01D5", X"----", X"01D7", X"01D8", X"----", X"----", X"----",
    X"01DC", X"01DD", X"----", X"----", X"----", X"01DA", X"----", X"----", 
    X"01DE", X"01DF", X"----", X"----", X"01E2", X"01E3", X"----", X"----", X"----", 
    X"01E0", X"----", X"----", X"01E4", X"01E5", X"01E6", X"----", X"----", X"01E9",
    X"01EA", X"----", X"----", X"----", X"01E7", X"----", X"----", X"01EB",
    X"01EC", X"----", X"----", X"----", X"01F3", X"----", X"----", X"----",
    X"01EE", X"01EF", X"01EF", X"01F0", X"01F0", X"01F1", X"----", X"----",
    X"01F4", X"01F5", X"01F6", X"01F7", X"01F8", X"01F9", X"01FA", X"01FB", 
    X"01FC", X"01FD", X"01FE", X"01FF", X"0200", X"0201", 
    X"0202", X"0203", X"0204", X"0205", X"0206", X"0207", X"0208", 
    X"0209", X"020A", X"020B", X"020C", X"020D", 
    X"020E", X"020F", X"0210", X"0211", X"0212", 
    X"0213"
);

-- Data Address Testvector
-- This is a testvector that verifies the correctness of DataAB
-- For the instructions that do not use DataAB, we just set the testvector to dashes(Don't Cares)
-- In our test, PUSH and POP are used to verify the correctness of ALU instructions. Since the SP is initialized
-- to X"FFFF" when reset, the testvector starts from X"FFFF". All PUSHes are paired with POPs.
-- Also, DataAB are checked for load/store instructions(except LDI), since they use the data bus to transfer data.
signal DataAddrTestVector: AddrTestVec_Type := (
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFE",            
    "----------------", X"FFFD",            "----------------", X"FFFD",            "----------------", 
    X"FFFE",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", X"FF00",            "----------------", "----------------", "----------------", 
    X"FF80",            "----------------", "----------------", "----------------", X"FFB0",            
    "----------------", X"FF00",            "----------------", X"FF01",            "----------------", 
    X"FF02",            "----------------", X"FF80",            "----------------", X"FF81",            
    "----------------", X"FF82",            "----------------", X"FFB0",            "----------------", 
    X"FFB1",            "----------------", X"FFB2",            "----------------", X"FF02",            
    "----------------", X"FF01",            "----------------", X"FF00",            "----------------", 
    X"FF82",            "----------------", X"FF81",            "----------------", X"FF80",            
    "----------------", X"FFB2",            "----------------", X"FFB1",            "----------------", 
    X"FFB0",            "----------------", X"FF00",            "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", X"FF80",            "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", X"FFB0",            
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    X"FF00",            "----------------", X"FF01",            "----------------", X"FF80",            
    "----------------", X"FF81",            "----------------", X"FFB0",            "----------------", 
    X"FFB1",            "----------------", X"FF01",            "----------------", X"FF00",            
    "----------------", X"FF81",            "----------------", X"FF80",            "----------------", 
    X"FFB1",            "----------------", X"FFB0",            "----------------", X"FF82",            
    "----------------", X"FFB2",            "----------------", X"FF81",            "----------------", 
    X"FFB1",            "----------------", "----------------", X"FF02",            "----------------", 
    "----------------", X"FF01",            "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",            
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", X"FFFF",            "----------------", 
    X"FFFF",            "----------------", "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", X"FFFF",            
    "----------------", X"FFFF",            "----------------", "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    X"FFFF",            "----------------", X"FFFF",            "----------------", "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", X"FFFF",            "----------------", X"FFFF",            "----------------", 
    "----------------", "----------------", X"FFFF",            "----------------", X"FFFF",
    -- flow control
    "----------------", "----------------", "----------------", "----------------", "----------------",
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", X"FFFF", "----------------", 
    X"FFFF",
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------", 
    "----------------", "----------------", "----------------", "----------------", "----------------"
);

-- Data Data Testvector for Read cases
-- This is a testvector that is used to verify the correctness of DataDB when reading data from data memory.
-- When we are reading nothing, the test value would be just "Z" since the default of our systems' Load/Store is
-- set to Load(which reads data from memory) When we are actually reading a value (for example, POP or Load 
-- instructions), we test the correctness of the read values. For flow-control instructions(JMP, CALL, etc), we
-- don't care about the values on DataDB.
signal DataDBReadTestVector: DataTestVec_Type := (
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"2C",      "ZZZZZZZZ", 
    X"F8",      "ZZZZZZZZ", X"7E",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"7E",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"7E",      "ZZZZZZZZ", X"2C",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"2C",      "ZZZZZZZZ", X"F8",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"F8",      "ZZZZZZZZ", 
    X"7E",      "ZZZZZZZZ", X"F8",      "ZZZZZZZZ", X"2C",      
    "ZZZZZZZZ", X"7E",      "ZZZZZZZZ", X"F8",      "ZZZZZZZZ", 
    X"2C",      "ZZZZZZZZ", X"F8",      "ZZZZZZZZ", X"7E",      
    "ZZZZZZZZ", X"7E",      "ZZZZZZZZ", X"2C",      "ZZZZZZZZ", 
    X"2C",      "ZZZZZZZZ", X"F8",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"7E",      "ZZZZZZZZ", 
    X"2C",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"F8",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"38",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"01",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"02",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"04",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"08",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"00",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"10",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"00",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"20",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"40",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"80",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"3A",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"20",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"39",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"20",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"FE",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"2C",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"3D",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"00",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"1B",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"F0",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"E3",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"14",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"24",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"00",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"01",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"41",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"02",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"19",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"08",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"59",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"19",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"03",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"02",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"35",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"03",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"35",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"AF",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"18",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"02",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"01",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"02",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"14",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"19",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"DD",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"35",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"DF",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"35",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"BB",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"35",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"B1",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"2C",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"7A",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"18",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"02",      
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"7B",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"18",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"02",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"4E",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"00",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"A1",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"14",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"F7",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    X"35",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"29",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", X"00",      "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"40",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", X"18",      "ZZZZZZZZ", "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"00",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"02",      "ZZZZZZZZ", 
    "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", "ZZZZZZZZ", X"DA",
    -- flow control instructions
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    X"82",-- This is the data read by single POP instruction while testing flow-control instructions
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------"
);

-- Data Data Testvector for Write cases
-- This is a testvector that is used to verify the correctness of DataDB when writing data to data memory.
-- When we are writing nothing, we don't care about the values on DataDB. 
-- When we are actually writing a value (for example, PUSH or Store instructions), we test the correctness of the 
-- written values. For flow-control instructions(JMP, CALL, etc), we don't care about the values on DataDB.
signal DataDBWriteTestVector: DataTestVec_Type := (
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"7E",      "--------", X"F8",      
    "--------", X"2C",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"7E",      "--------", "--------", "--------", 
    X"F8",      "--------", "--------", "--------", X"2C",      
    "--------", X"2C",      "--------", X"F8",      "--------", 
    X"7E",      "--------", X"2C",      "--------", X"F8",      
    "--------", X"7E",      "--------", X"2C",      "--------", 
    X"F8",      "--------", X"7E",      "--------", X"2C",      
    "--------", X"F8",      "--------", X"7E",      "--------", 
    X"F8",      "--------", X"7E",      "--------", X"2C",      
    "--------", X"7E",      "--------", X"2C",      "--------", 
    X"F8",      "--------", "--------", "--------", X"7E",      
    "--------", "--------", "--------", "--------", "--------", 
    X"2C",      "--------", "--------", "--------", "--------", 
    "--------", X"F8",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"2C",      
    "--------", X"F8",      "--------", "--------", "--------", 
    "--------", "--------", "--------", X"7E",      "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"38",      "--------", "--------", "--------", 
    "--------", "--------", X"01",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"00",      "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", X"02",      "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"00",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"04",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"00",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"08",      "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", X"00",      "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"10",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"00",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"20",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"00",      "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", X"40",      "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"00",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"80",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"00",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"3A",      "--------", "--------", 
    "--------", "--------", X"20",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"39",      "--------", "--------", "--------", "--------", 
    X"20",      "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", X"FE",      "--------", 
    "--------", "--------", "--------", X"2C",      "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"3D",      "--------", "--------", "--------", 
    "--------", X"00",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"00",      
    "--------", "--------", "--------", "--------", X"1B",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"F0",      "--------", "--------", 
    "--------", X"E3",      "--------", "--------", "--------", 
    "--------", X"14",      "--------", "--------", "--------", 
    "--------", "--------", "--------", X"24",      "--------", 
    "--------", "--------", "--------", X"00",      "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"01",      "--------", "--------", "--------", "--------", 
    X"00",      "--------", "--------", "--------", "--------", 
    "--------", X"41",      "--------", "--------", "--------", 
    "--------", X"00",      "--------", "--------", "--------", 
    "--------", X"00",      "--------", "--------", "--------", 
    "--------", X"02",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"19",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"08",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"59",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"19",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"03",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"02",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"35",      "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", X"03",      "--------", 
    "--------", "--------", "--------", X"35",      "--------", 
    "--------", "--------", "--------", "--------", X"AF",      
    "--------", "--------", "--------", "--------", X"18",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"02",      "--------", "--------", "--------", 
    "--------", "--------", X"01",      "--------", "--------", 
    "--------", "--------", X"00",      "--------", "--------", 
    "--------", "--------", X"00",      "--------", "--------", 
    "--------", "--------", X"02",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"14",      "--------", "--------", "--------", "--------", 
    "--------", "--------", X"00",      "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    X"19",      "--------", "--------", "--------", "--------", 
    "--------", X"DD",      "--------", "--------", "--------", 
    "--------", X"35",      "--------", "--------", "--------", 
    "--------", "--------", "--------", X"DF",      "--------", 
    "--------", "--------", "--------", X"35",      "--------", 
    "--------", "--------", "--------", "--------", X"BB",      
    "--------", "--------", "--------", "--------", X"35",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"B1",      "--------", "--------", "--------", 
    "--------", X"2C",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"7A",      
    "--------", "--------", "--------", "--------", X"18",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", X"00",      "--------", "--------", 
    "--------", "--------", X"02",      "--------", "--------", 
    "--------", "--------", "--------", "--------", X"7B",      
    "--------", "--------", "--------", "--------", X"18",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"00",      "--------", "--------", "--------", 
    "--------", X"02",      "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", X"4E",      
    "--------", "--------", "--------", "--------", X"00",      
    "--------", "--------", "--------", "--------", "--------", 
    "--------", X"A1",      "--------", "--------", "--------", 
    "--------", X"14",      "--------", "--------", "--------", 
    "--------", "--------", "--------", X"F7",      "--------", 
    "--------", "--------", "--------", X"35",      "--------", 
    "--------", "--------", "--------", "--------", X"29",      
    "--------", "--------", "--------", "--------", X"00",      
    "--------", "--------", "--------", "--------", "--------", 
    X"40",      "--------", "--------", "--------", "--------", 
    X"18",      "--------", "--------", "--------", "--------", 
    "--------", X"00",      "--------", "--------", "--------", 
    "--------", X"02",      "--------", "--------", "--------", 
    "--------", "--------", X"DA",      "--------", "--------",
    -- Flow control starts 
    "--------", "--------", "--------", "--------", "--------",
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", X"82", "--------", 
    "--------",
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------", 
    "--------", "--------", "--------", "--------", "--------"
);

begin

AVR_CPU_UUT: AVR_CPU
port map(
        ProgDB => ProgDB,
        Reset  => Reset,
        INT0   => '1',
        INT1   => '1',
        clock  => clock,
        ProgAB  => ProgAB,
        DataAB  => DataAB,
        DataWr  => DataWr,
        DataRd  => DataRd,
        DataDB  => DataDB
        );
        
DATA_MEM_UUT: DATA_MEMORY
port map(
        RE => DataRd,
        WE => DataWr,
        DataAB => DataAB,
        DataDB => DataDB
        );
PROG_MEM_UUT: PROG_MEMORY
port map(
        ProgAB => ProgAB,
        Reset => Reset,
        ProgDB => ProgDB
        );
       
-- Clock generation
 Clock <= not Clock after 50 ns when END_SIM = '0' else
         '1';
 
 -- Test loop
 -- This test loop goes through the test vectors stated above and verify ProgAB, DataRd, DataWr, DataAB, and DataDB
 -- Note that there is one cycle delay between ProgDB and IR, and this is why we use i-1 for
 -- DataRd, DataWr, DataAB, and DataDB. We check the values at the end of every cycle
 process
 begin
    Reset <= '0'; -- Activate Reset (Reset PC counter and SP)
    wait for 100 ns;
    for i in 0 to VECTOR_SIZE-1 loop -- Start the test loop
        wait for 90 ns;

        assert(std_match(ProgAB,ProgAddrTestVector(i))) -- Verify ProgAB
            report  "ProgAB ERROR at " & integer'image(i)
            severity ERROR;

        if ( i /= 0 ) then
            assert(std_match(DataRd, DataRdTestVector(i-1))) -- Verify DataRd.
                report "DataRd ERROR at " & integer'image(i)
                severity ERROR;

            assert(std_match(DataWr, DataWrTestVector(i-1))) -- Verify DataWr
                report "DataWr ERROR at " & integer'image(i)
                severity ERROR;

            assert(std_match(DataAB, DataAddrTestVector(i-1))) -- Verify DataAB
                report "DataAB ERROR at " & integer'image(i)
                severity ERROR;

            if(DataWr = '0') then
                assert(std_match(DataDB,  DataDBWriteTestVector(i-1))) -- Verify DataDB (when writing)
                    report "DataDB Write ERROR at " & integer'image(i)
                    severity ERROR;
            end if;

            if(DataRd = '0') then
                assert(std_match(DataDB, DataDBReadTestVector(i-1))) -- Verify DataDB (when reading)
                    report "DataDB Read ERROR at " & integer'image(i)
                    severity ERROR;
            end if;

        end if;

        wait for 10 ns;
        reset <= '1'; -- Deactivate Reset
    end loop;

    wait for 200 ns;
    END_SIM <= '1';  -- End of simulation
    wait;
 end process;
end Behavioral;
