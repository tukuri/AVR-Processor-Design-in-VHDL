--------------------------------------------------------------------------------
--
-- DataMemAccess.vhd
--
-- This file contains the entity declaration and the Behavioral architecture of 
-- the CPU data memory access unit
--
-- Revision History:
--     02/08/2019   Sung Hoon Choi   Created
--     02/09/2019   Sung Hoon Choi   Implemented base addr/offset selection
--                                   and dataDB selection logics
--     02/09/2019   Garret Sullivan  Added memory-mapped register functionality
--     02/11/2019   Garret Sullivan  Updated comments
--     02/23/2019   Garret Sullivan  Use DataWr instead of SelLoadStore to enable 
--                                   data bus output
--
--------------------------------------------------------------------------------

-- libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants.all;

--
-- DataMemAccess
--
-- Description: 
--     This is an entity for the data memory access unit. It handles addressing 
--     external memory on the data address bus and either outputting data to 
--     store on the data data bus or holding the data data bus in high-impedence 
--     to allow it to be driven externally. This entity receives a base address 
--     and an offset, adding them together to generate a target address. Either 
--     the base address or the target address can be output, allowing for pre- 
--     and post- increment and decrement functionality. It also takes a value 
--     to output on the data data bus and a signal to enable the output or hold 
--     the bus in Hi-Z. Additionally, this entity output a signal indicating 
--     whether or not the target address is within the memory-mapped register 
--     region, allowing the control unit to handle the access appropriately.
--
--     Valid values for select signals can be found in constants.vhd. Signals 
--     are active-high unless otherwise noted.
--
-- Inputs:
--     AddrBase     - the base address to output; one of X, Y, Z, or SP (WORD_SIZE bits)
--     AddrOffset   - the offset to add to the base address (WORD_SIZE bits)
--     UseAddrBase  - whether to use the base address or to ignore it and only 
--                    use the offset (1 bit)
--     SelLoadStore - whether the operation is load (1) or store (0) (1 bit)
--     StoreVal     - the value to output on DataDB to store (REG_SIZE bits)
--     SelDataAB    - whether to output base address or target address (1 bit)
--     DataWr       - active low write-enable, use to enable or disable DataDB buffer
--
-- Outputs:
--     AddrTarget   - the target address (base + offset) (WORD_SIZE bits)
--     DataAB       - the data address bus (WORD_SIZE bits)
--
-- Inputs/Outputs:
--     DataDB       - the data data bus (REG_SIZE bits)
--
entity DataMemAccess is
    port (
        AddrBase     : in  std_logic_vector(WORD_SIZE-1 downto 0);
        AddrOffset   : in  std_logic_vector(WORD_SIZE-1 downto 0);
        AddrTarget   : out std_logic_vector(WORD_SIZE-1 downto 0);
        
        UseAddrBase  : in  std_logic;
        
        SelLoadStore : in  sel_load_store;
		StoreVal     : in  std_logic_vector(REG_SIZE-1 downto 0);

        IsInternalAddr : out std_logic;
		
        SelDataAB    : in  sel_data_ab;
        DataAB       : out std_logic_vector(WORD_SIZE-1 downto 0);
        
        DataDB       : inout std_logic_vector(REG_SIZE-1 downto 0);
        DataWr       : in    std_logic
    );
end DataMemAccess;


architecture behavioral of DataMemAccess is

    signal MuxedAddrBase : std_logic_vector(WORD_SIZE-1 downto 0);

begin

    -- Main process for the data memory access unit; contains logic to output 
    -- target address, to manage the data data bus, and to inform the control 
    -- unit if the address is in the memory-mapped range
    process (all)
    begin
    
        -- mux between the base address and 0 based on whether or not to use the 
        -- base address
        case (UseAddrBase) is
            when '1' => MuxedAddrBase <= AddrBase;
            when '0' => MuxedAddrBase <= (others => '0');
            when others => null;
        end case;
        
        -- add muxed base and offset to get the target address
        -- cast to signed doesn't matter since these are the same length, it's 
        -- just so that the synthesizer doesn't complain about trying to add 
        -- std_logic_vectors
        AddrTarget <= std_logic_vector(signed(MuxedAddrBase) + signed(AddrOffset));
        
        -- output either base address or target depending on the select
        case (SelDataAB) is
               when SelDataABBase   => DataAB <= MuxedAddrBase; -- Post Increment/Decrement
               when SelDataABTarget => DataAB <= AddrTarget;    -- Pre Increment/Decrement
               when others => null;
        end case;

        -- output whether this address is in the range of the memory-mapped registers
        IsInternalAddr <= '0';
        if unsigned(DataAB) < NUM_REGS then
            IsInternalAddr <= '1';
        end if;
        
        -- hold data data bus in Hi-Z during loads; output the data during stores
        case (DataWr) is 	          
               when '1' => DataDB <= (others => 'Z'); -- Load Rd = (X)		
               when '0' => DataDB <= StoreVal;        -- Store (X) = Rr
               when others => null;
        end case;

    end process;
                
 end  behavioral;
