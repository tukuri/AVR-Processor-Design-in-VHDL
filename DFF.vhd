library ieee;
use ieee.std_logic_1164.all;

library xil_defaultlib;
use xil_defaultlib.constants.all;

-- Entity Name: 
--   DFF
--
-- Description: 
--   This is an entity for single D-FlipFlop with REGISTER_SIZE_IN_BITS bits width.
--   It also has enable signal (En) that controlls the register.
--   The output will be updated by the current input only when th enable signal is set.
--   Otherwise, the output stays having its old value.
--
--   Inputs
--      CLK: The source clock (1 bit)
--      EnableIn: Enables the D-FlipFlop to write a new value (1 bit)
--      D: Input of D-FlipFlop (REG_SIZE bits)
--   Outputs
--      Q: Output of D-FlipFlop (REG_SIZE bits)
--
-- Revision History
--   01/24/2019 Sung Hoon Choi  Created
--   01/25/2019 Sung Hoon Choi  Completed the code
--   02/02/2019 Sung Hoon Choi  Added comments

entity DFF is
port(
    clk: in std_logic;  -- The source clock
    En:  in std_logic;  -- Enables the D-FlipFlop to write a new value
    D:   in std_logic_vector(REG_SIZE-1 downto 0);   -- Input of D-FlipFlop
    Q:   out std_logic_vector(REG_SIZE-1 downto 0)); -- Output of D-FlipFlop
end DFF;

architecture Behavioral of DFF is

begin


-- At the rising edge, update the output with current input if the enable signal is set.
-- If the enable signal is not set at the rising edge, the output keeps its old value.
process(clk)
begin
    if(rising_edge(clk)) then -- DFF operates at the rising edge of a clock
        if (en = '1') then -- Only update the output if enable is set.
            Q <= D;
        end if;
    end if;
end process;

end Behavioral;
