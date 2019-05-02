library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.opcodes.all;
use xil_defaultlib.constants.all;

-- ProgMemAccess
--
-- Description: 
--     This is an entity for the program memory access unit. It updates PC (CurrentProgAddr) either 
--	   through relative jump(ProgLoad = '1'), absolute jump(ProgLoad = '0'), or the value from DataDB(in case of
--	   RET and RETI). For RET and RETI, PC receives SP through DataDB, single byte per cycle.(Note that the size 
--	   of a PC is 2 bytes while the size of DataDB is 1 byte) When the active-low Reset is activated, PC is 
--     reset to zero.
--
-- Inputs:
--     ImmProgOffset- Immediate program offset value from control unit (WORD_SIZE bits)
--     ProgLoad     - Whether to add an offset to current PC, or set PC to an absolute value (1 bit)
--     Clock		- System clock (1 bit)
--     Reset		- Resets PC to zero (1 bit)
--     DataDB       - Data-Data Bus. Used to update PC, 1 byte per cycle, in case of RET and RETI (BYTE_SIZE bits)
--     SelPCInput   - Whether to update the high byte of PC with DataDB, or to update the low byte of PC with DataDB, 
--				      or to update PC with ProgAB, the internally calculated next program address (2 bits)
-- Outputs:
--	   CurrProgAddr - Current Program Address. It is the Program Counter, PC (WORD_SIZE bits)
--	   ProgAB       - Program address bus. It is the address of the next instruction (WORD_SIZE bits)
--
-- Revision History:
--     02/18/2019   Sung Hoon Choi   Created
--     02/20/2019   Sung Hoon Choi	 Added selection logics for PC input
--			                         Update High byte of PC with DataDB vs 
--								     Update Low byte of PC with DataDB vs 
--                                   Update PC with ProgAB (next program address)
--     02/21/2019   Sung Hoon Choi   Updated comments

entity ProgMemAccess is
port(
    ImmProgOffset: in std_logic_vector(15 downto 0);
    ProgLoad: in std_logic;
    Clock: in std_logic; 
    Reset: in std_logic;
    DataDB: in std_logic_vector(7 downto 0);
    SelPCInput: in std_logic_vector(1 downto 0);
    CurrProgAddr:out std_logic_vector(15 downto 0);
    ProgAB: out std_logic_vector(15 downto 0)
     );
end ProgMemAccess;

architecture Behavioral of ProgMemAccess is

-- ProgLoad decides whether to add an offset to current PC(relative) or set the absolute value of PC(non-relative)
-- Extend the bit to match with the size of PC
signal ProgLoad_extended: std_logic_vector(15 downto 0);

begin

	-- Input logic for CurrProgAddr (which is equivalent to PC)
	-- If the active-low Reset is activated, reset PC to zero. 
	-- Now, if the Reset is not activated,
	-- if SelPCInPut is "10", update PC's high byte with DataDB(which would have SP in case of RET and RETI)
	-- If SelPCInput is "01", update PC's low byte with DataDB(which would have SP in case of RET and RETI)
	-- Otherwise, update PC with ProgAB, which has the next instruction's address
    process(Clock)
    begin
        if(rising_edge(Clock)) then
            if(Reset = '0') then -- Reset is an active low signal
                CurrProgAddr <= (others => '0'); -- Reset PC to zero
            elsif SelPCInput = "10" then
                CurrProgAddr(15 downto 8) <= DataDB; -- Update PC[15:8] with DataDB
            elsif SelPCInput = "01" then
                CurrProgAddr(7 downto 0) <= DataDB;  -- Update PC[7:0] with DataDB
            else
                CurrProgAddr <= ProgAB; -- Update PC with ProgAB (next instruction's address)
            end if;
        end if;
    end process;
    
	-- Extend ProgLoad bit to match with the size of PC
    ProgLoad_extended <= (others => ProgLoad);
	-- If ProgLoad is set, add immediate offset from Control Unit to current PC
	-- If ProgLoad is not set, set PC with the absolute value of ImmProgOffset
    ProgAB <= std_logic_vector(signed(CurrProgAddr and ProgLoad_extended) + signed(ImmProgOffset));
    
end Behavioral;