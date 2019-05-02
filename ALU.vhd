--------------------------------------------------------------------------------
--
-- ALU.vhd
--
-- This file contains the entity declaration and the Behavioral architecture of 
-- the CPU arithmetic and logic unit.
--
-- Revision History:
--     01/25/2019   Sung Hoon Choi   Created
--     01/30/2019   Garret Sullivan  Implemented Add/Sub and F-Block
--     02/04/2019   Garret Sullivan  Updated comments and constants
--     02/19/2019   Garret Sullivan  Move status register into ALU
--     02/22/2019   Garret Sullivan  Fix (half-)carry flags during subtraction
--     02/25/2019   Garret Sullivan  Updated comments
--
--------------------------------------------------------------------------------

-- libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants.all;


--
-- ALU
--
-- Description: 
--     This is an entity for ALU. It consists of three main blocks: the F-Block 
--     for computing logic functions (AND, OR, NOT, etc.), the Add/Sub block 
--     for arithmetic, and the shift/rotate block for shift and rotate 
--     instructions. Results from all three blocks are always computed; the 
--     appropriate result is then selected based on the ALU opcode received. 
--     Small additional blocks are also included for specialized instructions 
--     (BLD and SWAP). Additionally, the values of each of the status flags 
--     are also computed and latched to the status register, which is output.
--
-- Inputs:
--     ALUOp         - opcode for the ALU operation (ALU_OP_SIZE bits)
--     OperandA      - first input operand for ALU calculations (REG_SIZE bits)
--     OperandB      - second input operand for ALU calculations (REG_SIZE bits)
--     StatMask      - mask for which status bits to update (REG_SIZE bits)
--     PropagateZero - whether the zero flag from the previous status register 
--                     value should be propagated forward (zero requires new 
--                     status to be zero AND old status to be zero) (1 bit)
--
-- Outputs:
--     Result   - result of ALU calculation (REG_SIZE bits)
--     StatOut  - status register output (REG_SIZE bits)
--     FlagZero - direct zero flag output (combinational, for CPSE) (1 bit)
--

entity ALU is
    port (
        CLK : in std_logic; -- system clock

        -- ALU inputs
        ALUOp         : in opcode_alu; -- ALU operation
        OperandA      : in std_logic_vector(REG_SIZE-1 downto 0); -- first operand
        OperandB      : in std_logic_vector(REG_SIZE-1 downto 0); -- second operand
        StatMask      : in std_logic_vector(REG_SIZE-1 downto 0);
        PropagateZero : in std_logic;
        
        -- ALU outputs
        Result   : out std_logic_vector(REG_SIZE-1 downto 0); -- ALU result
        StatOut  : out std_logic_vector(REG_SIZE-1 downto 0); -- status reg output
        FlagZero : out std_logic
    );
end ALU;


architecture Behavioral of ALU is

    -- intermediate results from each of the blocks
    signal ResultFBlock : std_logic_vector(REG_SIZE-1 downto 0);
    signal ResultAddSub : std_logic_vector(REG_SIZE-1 downto 0);
    signal ResultShift  : std_logic_vector(REG_SIZE-1 downto 0);
    signal ResultBLD    : std_logic_vector(REG_SIZE-1 downto 0);
    signal ResultSWAP   : std_logic_vector(REG_SIZE-1 downto 0);
    
    -- intermediate status calculation signal
    signal StatCalc : std_logic_vector(REG_SIZE-1 downto 0);
    signal StatMux  : std_logic_vector(REG_SIZE-1 downto 0);
    
    -- add/sub block carry signals
    signal CarryIn  : std_logic_vector(REG_SIZE-1 downto 0);
    signal CarryOut : std_logic_vector(REG_SIZE-1 downto 0);
    
    -- additional add/sub block logic
    signal IsSub    : std_logic; -- is the operation subtraction
    signal UseCarry : std_logic; -- should the operation use the carry flag

begin

    ----------------------------------------------------------------------
    -- Add/Sub Block logic
    ----------------------------------------------------------------------

    -- is this a subtraction operation?
    IsSub <= '1' when std_match(ALUOp, ALUOpSUB) or std_match(ALUOp, ALUOpSBC) else
             '0';

    -- should we propagate the carry from the previous operation?
    UseCarry <= '1' when std_match(ALUOp, ALUOpADC) or std_match(ALUOp, ALUOpSBC) else
                '0';

    -- need to flip the initial carry to borrow for subtraction
    CarryIn(0) <= (StatOut(0) and UseCarry) xor IsSub;

    -- connect up the carry ins to the previous carry outs
    gen_carry_in: for i in 1 to BYTE_SIZE-1 generate
        CarryIn(i) <= CarryOut(i-1);
    end generate;

    -- create a full adder for each bit
    gen_full_adder: for i in 0 to BYTE_SIZE-1 generate
        ResultAddSub(i) <= OperandA(i) xor OperandB(i) xor CarryIn(i) xor IsSub;
        CarryOut(i) <= (OperandA(i) and CarryIn(i)) or
                       ((OperandB(i) xor IsSub) and OperandA(i)) or
                       ((OperandB(i) xor IsSub) and CarryIn(i));
    end generate;


    ----------------------------------------------------------------------
    -- F-Block logic
    ----------------------------------------------------------------------

    -- mux using the operands as selects; logic functions are encoded in the ALU 
    -- opcodes themselves
    gen_f_block: for i in 0 to BYTE_SIZE-1 generate
        ResultFBlock(i) <= ALUOp(0) when (OperandA(i) = '0' and OperandB(i) = '0') else
                           ALUOp(1) when (OperandA(i) = '0' and OperandB(i) = '1') else
                           ALUOp(2) when (OperandA(i) = '1' and OperandB(i) = '0') else
                           ALUOp(3);
    end generate;


    ----------------------------------------------------------------------
    -- Shift/Rotate logic
    ----------------------------------------------------------------------

    -- set high bit depending on specific instruction
    ResultShift(7) <= '0'         when std_match(ALUOp, ALUOpLSR) else -- LSR, 0 extend
                      OperandA(7) when std_match(ALUOp, ALUOpASR) else -- ASR, sign extend
                      StatOut(0);                                       -- ROR, rotate

    -- for remaining bits, just shift
    gen_shift: for i in BYTE_SIZE-2 downto 0 generate
        ResultShift(i) <= OperandA(i+1);
    end generate;


    ----------------------------------------------------------------------
    -- Miscellaneous ALU operation logic
    ----------------------------------------------------------------------

    -- use bit address encoded into ALU opcode to load to appropriate bit
    gen_bld: for i in 0 to 7 generate
        ResultBLD(i) <= StatOut(6) when unsigned(ALUOp(2 downto 0)) = i else
                        OperandA(i);
    end generate;
    
    
    -- Swap Nibbles logic
    ResultSWAP <= OperandA(3 downto 0) & OperandA(7 downto 4);


    ----------------------------------------------------------------------
    -- Final Result Selection logic
    ----------------------------------------------------------------------

    Result <= ResultFBlock   when std_match(ALUOp, ALUOpSetFBlock) else -- AND, OR, NOT, XOR
              ResultAddSub   when std_match(ALUOp, ALUOpSetAddSub) else -- LSR, ASR, ROR
              ResultShift    when std_match(ALUOp, ALUOpSetShift)  else -- ADD, ADC, SUB, SBC
              ResultBLD      when std_match(ALUOp, ALUOpSetBLD)    else -- BLD
              ResultSWAP;                                               -- SWAP
    
    
    ----------------------------------------------------------------------
    -- Status Flag logic
    ----------------------------------------------------------------------

    -- interrupt enable, will always get masked
    StatCalc(FLAG_I) <= '0'; 

    -- transfer bit, use bit address encoded into ALU opcode to store from 
    -- appropriate bit
    StatCalc(FLAG_T) <= OperandA(to_integer(unsigned(ALUOp(2 downto 0))));

    -- half carry
    StatCalc(FLAG_H) <= CarryOut(3) xor isSub;

    -- corrected sign, sign xor signed overflow
    StatCalc(FLAG_S) <= StatCalc(FLAG_N) xor StatCalc(FLAG_V);

    -- signed overflow: last 2 carries don't match for add/sub, negative xor carry 
    -- for shift, 0 for logical
    StatCalc(FLAG_V) <= CarryOut(6) xor CarryOut(7)           when std_match(ALUOp, ALUOpSetAddSub) else
                        StatCalc(FLAG_N) xor StatCalc(FLAG_C) when std_match(ALUOp, ALUOpSetShift)  else
                       '0';

    -- negative, high bit of result
    StatCalc(FLAG_N) <= Result(7);

    -- zero, just check for zero result
    StatCalc(FLAG_Z) <= StatOut(FLAG_Z) when Result = "00000000" and PropagateZero = '1' else
                       '1'              when Result = "00000000" else
                       '0';

    -- carry, either add/sub carry or shift/rotate into carry
    StatCalc(FLAG_C) <= CarryOut(7) xor isSub when std_match(ALUOp, ALUOpSetAddSub) else
                        OperandA(0) when std_match(ALUOp, ALUOpSetShift)  else
                        '1'; -- only matters for COM, when it should be set


    -- output the zero flag directly (for the CPSE instruction)
    FlagZero <= StatCalc(FLAG_Z);
    
    -- mux the final output with all 1s or all 0s for BSET and BCLR, respectively, 
    -- and with OperandA for ALUOpSTAT (setting status register directly)
    StatMux <= "11111111" when std_match(ALUOp, ALUOpBSET) else
               "00000000" when std_match(ALUOp, ALUOpBCLR) else
               OperandA   when std_match(ALUOp, ALUOpSTAT) else
               StatCalc;


    -- status register update process
    -- latches new status bit values on the rising clock edge
    process (CLK)
    begin
        if rising_edge(CLK) then
            -- only update the bits that aren't masked; take the masked bits 
            -- from the old status register value
            StatOut <= (StatMux and StatMask) or (StatOut and not StatMask);
        end if;
    end process;
                   

end Behavioral;
