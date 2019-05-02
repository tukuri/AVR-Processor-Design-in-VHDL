----------------------------------------------------------------------------
--
--  Atmel AVR Data Memory
--
--  This component describes the data memory for the AVR CPU.  It creates a
--  64K x 8 RAM.
--
--  Revision History:
--     11 May 98  Glen George       Initial revision.
--      9 May 00  Glen George       Changed from using CS and WE to using RE
--                                  and WE.
--      7 May 02  Glen George       Updated comments.
--     23 Jan 06  Glen George       Updated comments.
--     17 Jan 18  Glen George       Output an error message and write current
--                                  data value instead of previous value when
--                                  address bus changes while WE is active.
--
----------------------------------------------------------------------------


--
--  DATA_MEMORY
--
--  This is the data memory component.  It is just a 64 Kbyte RAM with no
--  timing information.  It is meant to be connected to the AVR CPU.
--
--  Inputs:
--    RE     - read enable (active low)
--    WE     - write enable (active low)
--    DataAB - memory address bus (16 bits)
--
--  Inputs/Outputs:
--    DataDB - memory data bus (8 bits)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity  DATA_MEMORY  is

    port (
        RE      : in     std_logic;             	-- read enable (active low)
        WE      : in     std_logic;		        -- write enable (active low)
        DataAB  : in     std_logic_vector(15 downto 0); -- memory address bus
        DataDB  : inout  std_logic_vector(7 downto 0)   -- memory data bus
    );

end  DATA_MEMORY;


architecture  RAM  of  DATA_MEMORY  is

    -- define the type for the RAM
    type  RAMtype  is array (0 to 65535) of std_logic_vector(7 downto 0);

    -- now define the RAM itself (initialized to X)
    signal  RAMbits  :  RAMtype  := (others => (others => 'X'));


begin

    process
    begin

        -- wait for an input to change
	wait on  RE, WE, DataAB;

        -- first check if reading (active low read enable)
	if  (RE = '0')  then
	    -- reading, put the data out
	    DataDB <= RAMbits(CONV_INTEGER(DataAB));
	else
	    -- not reading, send data bus to hi-Z
	    DataDB <= "ZZZZZZZZ";
	end if;

	-- now check if writing
	if  (WE'event and (WE = '1'))  then
	    -- rising edge of write - write the data
	    RAMbits(CONV_INTEGER(DataAB)) <= DataDB;
	    -- wait for the update to happen
	    wait for 0 ns;
	end if;

	-- finally check if WE low with the address changing
	if  (DataAB'event and (WE = '0'))  then
            -- output an error message
	    REPORT "Glitch on Data Address bus"
	    SEVERITY  ERROR;
	    -- address changed with WE low - trash the old location
	    RAMbits(CONV_INTEGER(DataAB'delayed)) <= DataDB;
	end if;

    end process;


end  RAM;