--------------------------------------------------------------------------------
--
-- ControlUnit.vhd
--
-- This file contains the entity declaration and the Behavioral architecture of 
-- the CPU control unit.
--
-- Revision History:
--     01/25/2019   Sung Hoon Choi   Created
--     01/30/2019   Garret Sullivan  Implemented instruction decoding
--     02/02/2019   Sung Hoon Choi   Fixed the SelA for immediate instructions 
--                                   (ANDI,CPI, ORI, SBCI, SUBI)
--     02/03/2019   Sung Hoon Choi   Fixed the SelIn for two-cycle instructions 
--                                   (ADIW, SBIW) and immediate instructions
--     02/05/2019   Garret Sullivan  Updated comments and constant definitions
--     02/09/2019   Garret Sullivan  Implemented remaining load/store 
--                                   instructions
--     02/09/2019   Garret Sullivan  Added memory-mapped register functionality 
--     02/10/2019   Sung Hoon Choi   Added Stack Pointer and PUSH/POP 
--                                   instructions
--     02/10/2019   Garret Sullivan  Updated comments
--     02/17/2019   Sung Hoon Choi   Implemented flow control instructions (JMP, 
--                                   RET, CALL, etc)
--     02/21/2019   Sung Hoon Choi   Fixed bugs in flow control
--     02/24/2019   Garret Sullivan  Updated comments
--
--------------------------------------------------------------------------------

-- libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.opcodes.all;
use xil_defaultlib.constants.all;


--
-- ControlUnit
--
-- Description: 
--     This is an entity for the control unit. The bulk of it is the 
--     instruction decoder, which uses data from the IR to decode which  
--     instruction is being executed. Depending on the instruction, control 
--     signals are generated, connecting to the various other blocks of the 
--     CPU, to control their operation appropriately. For registers, these  
--     include select signals for register inputs and outputs and a write 
--     enable. The register array also communicates back to the control unit if 
--     the status register is being written, which must be done through the 
--     ALU. For the ALU, these include the ALU opcode, selects for the 
--     inputs to the ALU, an immediate operand from the IR, and a status 
--     register mask. For the data memory access unit, these include the source 
--     of the base memory address, an immediate memory offset, a select for 
--     outputting the address before or after applying the offset, and an 
--     enable for using the base address entirely. The data memory access unit 
--     also communicates back to the control unit to enable memory-mapped 
--     access to registers. For the program memory access unit, these include 
--     an immediate memory offset, whether to use the base program counter 
--     value, and a select for directly updating one byte of the program 
--     counter. Additionally, there is a simple counter that keeps 
--     track of the cycle count for the current instruction. This is used 
--     by multi-cycle instructions so that separate control signals can 
--     be generated on each cycle.
--
--     Valid values for select signals and ALU opcodes can be found in 
--     constants.vhd. Signals are active-high unless otherwise noted.
--
-- Inputs:
--     CLK    - system clock (1 bit)
--     Reset  - active-low reset (1 bit)
--     ProgDB - the program memory data bus (WORD_SIZE bits)
--
--     StatusWrite - high if the status register is being written, which needs 
--                   to be redirected through the ALU (1 bit)
--
--     InternalAddr   - the internal address used for memory-mapped registers (REG_SEL_SIZE bits)
--     IsInternalAddr - whether the interal address is valid (1 bit)
--
--     InputZ  - the Z register from the register array (for ICALL/IJMP) (WORD_SIZE bits)
--     RegAVal - the A bus output from the register array (for SRBC/SBRS) (REG_SIZE bits)
--
--     StatRegIn - the status register from the ALU (for conditional branches) (REG_SIZE bits)
--     ZeroFlag  - combinational zero flag from ALU before the latch (for CPSE) (1 bit)
--
-- Outputs:
--     EnableIn      - enables writing to a register in the register set (1 bit)
--     SelRegInput   - selects the register input source (2 bits)
--     SelIn         - selects the register to be written (REG_SEL_SIZE bits)
--     SelA          - selects the register to be output on A bus (REG_SEL_SIZE bits)
--     SelB          - selects the register to be output on B bus (REG_SEL_SIZE bits)
--
--     ALUOp         - opcode for the ALU operation (ALU_OP_SIZE bits)
--     SelOpA        - select for A bus input to ALU (1 bit)
--     SelOpB        - select for B bus input to ALU (2 bits)
--     ImmOpB        - immediate operand for ALU bus B (REG_SIZE bits)
--     StatMask      - mask for status register (1=enable write) (REG_SIZE bits)
--     PropagateZero - whether to progagate the zero flag from the previous operation; previous 
--                     zero flag must be set for new one to be set (for CPC) (1 bit)
--
--     SelWord       - selects a pair of registers to access as a word (4 bits)
--     EnableWord    - enables writing to the selected register pair (1 bit)
--
--     SelLoadStore  - selects whether an operation is a load or store (1 bit)
--     SelDataAB     - selects pre-decrement (0) or post-decrement (1) (1 bit)
--     SelStoreVal   - selects source to connect to data bus for memory write (2 bits)
--     ImmOffset     - address offset to use for data address (WORD_SIZE bits)
--     UseAddrBase   - whether to add the offset to base address or use the offset directly (1 bit)
--
--     ImmProgOffset - address offset to use for program address (WORD_SIZE bits)
--     ProgLoad      - high if the base value in PC should be used for address calculation, low 
--                     if 0 should be use (for non-relative jumps) (1 bit)
--     SelPCInput    - select for the value used to update PC; normally ProgAB (the next address),
--                     but possibly the data bus for RET and RETI (2 bits)
--
--     DataRd        - active-low read enable signal for external memory (1 bit)
--     DataWr        - active-low write enable signal for external memory (1 bit)
--

entity ControlUnit is
    port (
        CLK    : in std_logic;
        Reset  : in std_logic;
        ProgDB : in std_logic_vector(WORD_SIZE-1 downto 0);

        IsInternalAddr : in std_logic;
        InternalAddr   : in std_logic_vector(REG_SEL_SIZE-1 downto 0);

        StatusWrite : in std_logic;
        
        InputZ      : in std_logic_vector(WORD_SIZE-1 downto 0); -- for IJMP, ICALL
        RegAVal     : in std_logic_vector(REG_SIZE-1 downto 0);  -- for SBRC, SBRS

        StatRegIn   : in std_logic_vector(REG_SIZE-1 downto 0); 
        ZeroFlag    : in std_logic; -- from ALU before Latch    
        

        -- Register Array (single register access)
        EnableIn     : out std_logic;
        SelRegInput  : out sel_reg_input;
        SelIn        : out std_logic_vector(REG_SEL_SIZE-1 downto 0);
        SelA         : out std_logic_vector(REG_SEL_SIZE-1 downto 0);
        SelB         : out std_logic_vector(REG_SEL_SIZE-1 downto 0);
        
        -- ALU
        ALUOp         : out opcode_alu;
        SelOpA        : out sel_op_a;
        SelOpB        : out sel_op_b;
        ImmOpB        : out std_logic_vector(REG_SIZE-1 downto 0);
        StatMask      : out std_logic_vector(REG_SIZE-1 downto 0);
        PropagateZero : out std_logic;

        -- Register Array (register pair access)
        SelWord      : out sel_word;
        EnableWord   : out std_logic; 
        
        -- Data Memory Access Unit
        SelLoadStore : out sel_load_store;
        SelDataAB    : out sel_data_ab;
        SelStoreVal  : out sel_store_val; 
        ImmOffset    : out std_logic_vector(WORD_SIZE-1 downto 0);
        UseAddrBase  : out std_logic;
        
        -- Program Memory Access Unit
        ImmProgOffset : out std_logic_vector(WORD_SIZE-1 downto 0);
        ProgLoad      : out std_logic;
        SelPCInput    : out sel_pc_input;

        -- Control Bus
        DataRd       : out std_logic;
        DataWr       : out std_logic
    );
end ControlUnit;


architecture Behavioral of ControlUnit is

    -- Signals for keeping track of the cycle number on multi-cycle instructions 
    constant MAX_CYCLES : natural := 4;

	-- Instruction Register
	signal IR: std_logic_vector(WORD_SIZE-1 downto 0);

	-- Enable updating IR (disabled for several JMP instructions)
    signal EnableIR: std_logic; 

    signal Cycle      : natural range 1 to MAX_CYCLES;
    signal CycleCount : natural range 1 to MAX_CYCLES;

    -- Register to hold the second word of two-word instructions (memory 
    -- addresses for LDS and STS) and an enable for that register
    signal ImmAddrReg   : std_logic_vector(WORD_SIZE-1 downto 0);
    signal LatchImmAddr : std_logic;

    -- Signals to enable mapping the registers to the memory space
    signal IOPulse : std_logic;
    signal LoadSelRegInput  : sel_reg_input;
    signal StoreEnableRegIn : std_logic;

    -- Signals that hold data decoded from IR
    -- Singal register addresses
    signal RegASelSrc    : std_logic_vector(REG_SEL_SIZE-1 downto 0);
    signal RegASelAltSrc : std_logic_vector(REG_SEL_SIZE-1 downto 0);
    signal RegBSelSrc    : std_logic_vector(REG_SEL_SIZE-1 downto 0);

    -- Register pair addresses
    constant RegWordPrefix : std_logic_vector(1 downto 0) := "11";
    signal RegWordSrc      : std_logic_vector(IR_REG_WORD_SEL_SIZE-1 downto 0);
    signal RegWordLoSrc    : std_logic_vector(REG_SEL_SIZE-1 downto 0);
    signal RegWordHiSrc    : std_logic_vector(REG_SEL_SIZE-1 downto 0);

    -- Immediate operands
    signal IRImmOp    : std_logic_vector(REG_SIZE-1 downto 0);
    signal IRImmOpAlt : std_logic_vector(REG_SIZE-1 downto 0);

    signal IRImmOffset : std_logic_vector(WORD_SIZE-1 downto 0);

    signal IRImmProgRel : std_logic_vector(WORD_SIZE-1 downto 0);
    signal IRImmConRel  : std_logic_vector(WORD_SIZE-1 downto 0);
    
    -- Register indexes
    signal IRBitSetClear    : std_logic_vector(REG_BIT_IDX_SIZE-1 downto 0);
    signal IRBitLoadStore   : std_logic_vector(REG_BIT_IDX_SIZE-1 downto 0);
    signal IRBitFlowControl : std_logic_vector(REG_BIT_IDX_SIZE-1 downto 0);
    
    -- IO register address
    signal IRIOPortSrc     : std_logic_vector(5 downto 0);

    -- Conversion of IO register address to unified register address space
    signal RegIOSrc : std_logic_vector(REG_SEL_SIZE-1 downto 0);

    -- Flag mask definitions
    constant FlagsZCNVSH : std_logic_vector(REG_SIZE-1 downto 0) := "00111111";
    constant FlagsZCNVS  : std_logic_vector(REG_SIZE-1 downto 0) := "00011111";
    constant FlagsZNVS   : std_logic_vector(REG_SIZE-1 downto 0) := "00011110";
    constant FlagsT      : std_logic_vector(REG_SIZE-1 downto 0) := "01000000";
    constant FlagsNone   : std_logic_vector(REG_SIZE-1 downto 0) := "00000000";

begin

    -- Main instruction decoder: matches the instruction register to one of the 
    -- valid instructions patterns and generates control outputs based on which 
    -- instruction was given and possibly any immediate operands given with 
    -- the instruction
    process (all)
    begin
        -- Retrieve various data from IR. Bit pattern definitions are available 
        -- in the AVR Instruction Set manual
        
        -- Standard register addresses
        -- e.g. ADD 000011rdddddrrrr
        RegASelSrc <= "00" & IR(8 downto 4);
        RegBSelSrc <= "00" & IR(9) & IR(3 downto 0);

        -- Alternate register address, only upper half of register array
        -- e.g. ANDI 0111KKKKddddKKKK
        RegASelAltSrc <= "00" & '1' & IR(7 downto 4);

        -- Register pair addresses
        -- e.g. ADIW 10010110KKddKKKK
        RegWordSrc <= IR(5 downto 4);
        RegWordLoSrc <= "00" & RegWordPrefix & RegWordSrc & '0';
        RegWordHiSrc <= "00" & RegWordPrefix & RegWordSrc & '1';

        -- Immediate operand and alternate shorter version
        -- e.g. ANDI 0111KKKKddddKKKK
        IRImmOp <= IR(11 downto 8) & IR(3 downto 0);

        -- e.g. ADIW 10010110KKddKKKK
        IRImmOpAlt <= "00" & IR(7 downto 6) & IR(3 downto 0);

        -- e.g. LDD 10q0qq0ddddd1qqq
        IRImmOffset <= "0000000000" & IR(13) & IR(11 downto 10) & IR(2 downto 0);

        -- Register indexes for status bit manipulation
        -- e.g. BSET 100101000sss1000
        IRBitSetClear <= IR(6 downto 4);

        -- e.g. BLD 1111100ddddd0bbb
        IRBitLoadStore <= IR(2 downto 0);

        -- e.g. BRBC 111101rrrrrrrbbb
        IRBitFlowControl <= IR(2 downto 0);

        -- Immediate relative jump address
        -- e.g. RJMP 1100jjjjjjjjjjjj
        IRImmProgRel <= std_logic_vector(resize(signed(IR(11 downto 0)), IRImmProgRel'length)); -- PC = PC +  j

        -- e.g. BRBC 111101rrrrrrrbbb
        IRImmConRel <= std_logic_vector(resize(signed(IR(9 downto 3)), IRImmConRel'length)); -- PC = PC + r
        
        -- Select for IO registers
        -- e.g. IN 10110ppdddddpppp
        IRIOPortSrc <= IR(10 downto 9) & IR(3 downto 0);
        
        -- We need to add 32 to the address to convert it to the appropraite range to send 
        -- to the register array. That is, we need 0xxxxx->01xxxxx and 1xxxxx->10xxxxx, which 
        -- is accomplished by taking bit5 & not bit5 & bits4-0
        RegIOSrc <= IRIOPortSrc(5) & (not IRIOPortSrc(5)) & IRIOPortSrc(4 downto 0);
        

        -- Set some default output values

        -- Most instructions are single-cycle
        CycleCount <= 1;
        
        -- ALU operation needs an arbitrary default
        ALUOp <= ALUOpADD;
        
        -- Zero flag is only propagated for one instruction (CPSE)
        PropagateZero <= '0';

        -- Default to not latching into a register
        EnableIn <= '0';
        
        -- Most ALU operations use these values
        SelRegInput <= SelRegInputALUResult;
        SelIn <= RegASelSrc;
        SelA <= RegASelSrc;
        SelB <= RegBSelSrc;
        
        SelOpA <= SelOpARegAOut;
        SelOpB <= SelOpBRegBOut;
        ImmOpB <= IRImmOp;
        StatMask <= FlagsNone;
        
        -- Default to not-load/store instructions
        SelWord <= SelWordNone;
        EnableWord <= '0';
        
        -- Default to load to keep data data bus at Hi-Z
        SelLoadStore <= SelLoad;

        SelDataAB <= SelDataABBase;
        SelStoreVal <= SelStoreValRegAOut;
        ImmOffset <= IRImmOffset;
        UseAddrBase <= '1';
    
        -- Don't latch second instruction word unless specified
        LatchImmAddr <= '0';

        -- Default to relative PC update using the next value on ProgAB
        ProgLoad <= '1';  
        SelPCInput <= SelPCInputProgAB;

        -- Default to not reading and to not writing
        DataRd <= '1';
        DataWr <= '1';


        -- Default to incrementing PC only on the last cycle of an instruction. 
        -- Multi-word instructions will need to increment PC themselves to get 
        -- the next word in the instruction
        if Cycle = CycleCount then
            -- Increment
            ImmProgOffset <= (0=> '1', others => '0');
            EnableIR <= '1';
        else
            -- Don't change
            ImmProgOffset <= (others => '0');
            EnableIR <= '0';
        end if;
        
        
        -- These signals enable the registers to be memory-mapped and accessed 
        -- through load/store instructions. IsInternalAddr is an active high 
        -- signal from the data memory access unit indicating whether or not 
        -- the given address points to a memory-mapped register. 
        -- 
        -- If the address is internal, IOPulse is pulled high so that the 
        -- read/write pulse doesn't occur. 
        --
        -- For load instructions, IsInternalAddr is used to select whether to 
        -- connect RegBOut or DataDB to the register array input. Normal loads 
        -- from memory would get input from the data bus, but a load from a 
        -- register instead gets input from RegBOut. RegBOut will be set to the 
        -- internal address regardless of whether or not is is valid, but the 
        -- mux will connect it only if it's valid.
        --
        -- For store instructions, the data to store will always be put on the 
        -- data bus. However, the data bus will also be selected as the 
        -- register array input, and the select for which register to write to 
        -- will be set to the internal address regardless of whether or not it 
        -- is valid. If it is valid, the input will be latched to update that 
        -- register; if not, the value will not be latched (but will still be 
        -- available on the data bus for external memory to access).

        IOPulse <= CLK or IsInternalAddr;

        case (IsInternalAddr) is
            when '1' => LoadSelRegInput <= SelRegInputRegBOut;
            when '0' => LoadSelRegInput <= SelRegInputDataDB;
            when others => null;
        end case;

        case (IsInternalAddr) is
            when '1' => StoreEnableRegIn <= '1';
            when '0' => StoreEnableRegIn <= '0';
            when others => null;
        end case;
        

        ------------------------------------------------------------------------
        -- Instruction Definitions
        ------------------------------------------------------------------------
              
        -- Add/Sub Block instructions
        
        if std_match(IR, OpADC) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpADC;
            StatMask <= FlagsZCNVSH;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpADD) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpADD;
            StatMask <= FlagsZCNVSH;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpADIW) then
            EnableIn <= '1';

            -- two cycle instruction
            CycleCount <= 2;
            if Cycle = 1 then
                -- need to switch to low reg of reg pair source and the shorter 
                -- immediate operand
                ALUOp <= ALUOpADD;
                SelIn <= RegWordLoSrc;
                SelA <= RegWordLoSrc;
                SelOpB <= SelOpBImm;
                ImmOpB <= IRImmOpAlt;
                StatMask <= FlagsZCNVS;
            end if;
            if Cycle = 2 then
                -- now use high reg of reg pair and 0 for immediate operand
                ALUOp <= ALUOpADC;
                SelIn <= RegWordHiSrc;
                SelA <= RegWordHiSrc;
                SelOpB <= SelOpBImm;
                ImmOpB <= "00000000";
                StatMask <= FlagsZCNVS;
            end if;
        end if;
        
        if std_match(IR, OpCP) then
            -- compare, disable register write
            ALUOp <= ALUOpSUB;
            EnableIn <= '0';
            StatMask <= FlagsZCNVSH;
        end if;
        
        if std_match(IR, OpCPC) then
            -- compare, disable register write
            ALUOp <= ALUOpSBC;
            EnableIn <= '0';
            StatMask <= FlagsZCNVSH;
            PropagateZero <= '1';
        end if;
        
        if std_match(IR, OpCPI) then
            -- compare, disable register write; also need to switch to alt 
            -- register source (upper half) and select immediate operand
            ALUOp <= ALUOpSUB;
            EnableIn <= '0';
            SelIn <= RegASelAltSrc;
            SelA <= RegASelAltSrc;
            SelOpB <= SelOpBImm;
            StatMask <= FlagsZCNVSH;
        end if;
        
        if std_match(IR, OpDEC) then
            -- set ALUOp and immediate operand to do a decrement
            ALUOp <= ALUOpSUB;
            SelOpB <= SelOpBImm;
            ImmOpB <= "00000001";
            StatMask <= FlagsZNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpINC) then
            -- set ALUOp and immediate operand to do an increment
            ALUOp <= ALUOpADD;
            SelOpB <= SelOpBImm;
            ImmOpB <= "00000001";
            StatMask <= FlagsZNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpNEG) then
            -- subtract from 0; need to send A output to B input
            ALUOp <= ALUOpSUB;
            SelOpA <= SelOpA0;
            SelOpB <= SelOpBRegAOut;
            StatMask <= FlagsZCNVSH;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpSBC) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpSBC;
            StatMask <= FlagsZCNVSH;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpSBCI) then
            -- need to switch to alt register source (upper half) and select 
            -- immediate operand
            ALUOp <= ALUOpSBC;
            SelIn <= RegASelAltSrc;
            SelA <= RegASelAltSrc;
            SelOpB <= SelOpBImm;
            StatMask <= FlagsZCNVSH;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpSBIW) then
            EnableIn <= '1';

            -- two cycle instruction
            CycleCount <= 2;
            if Cycle = 1 then
                -- need to switch to low reg of reg pair source and the shorter 
                -- immediate operand
                ALUOp <= ALUOpSUB;
                SelIn <= RegWordLoSrc;
                SelA <= RegWordLoSrc;
                SelOpB <= SelOpBImm;
                ImmOpB <= IRImmOpAlt;
                StatMask <= FlagsZCNVS;
            end if;
            if Cycle = 2 then
                -- now use high reg of reg pair and 0 for immediate operand
                ALUOp <= ALUOpSBC;
                SelIn <= RegWordHiSrc;
                SelA <= RegWordHiSrc;
                SelOpB <= SelOpBImm;
                ImmOpB <= "00000000";
                StatMask <= FlagsZCNVS;
            end if;
        end if;
        
        if std_match(IR, OpSUB) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpSUB;
            StatMask <= FlagsZCNVSH;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpSUBI) then
            -- need to switch to alt register source (upper half) and select 
            -- immediate operand
            ALUOp <= ALUOpSUB;
            SelIn <= RegASelAltSrc;
            SelA <= RegASelAltSrc;
            SelOpB <= SelOpBImm;
            StatMask <= FlagsZCNVSH;
            EnableIn <= '1';
        end if;
    

    
        -- Shift/Rotate Block instructions
        
        if std_match(IR, OpASR) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpASR;
            StatMask <= FlagsZCNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpLSR) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpLSR;
            StatMask <= FlagsZCNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpROR) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpROR;
            StatMask <= FlagsZCNVS;
            EnableIn <= '1';
        end if;
        
        
        -- F-Block instructions
        
        if std_match(IR, OpAND) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpAND;
            StatMask <= FlagsZNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpANDI) then
            -- need to switch to alt register source (upper half) and select 
            -- immediate operand
            ALUOp <= ALUOpAND;
            SelIn <= RegASelAltSrc;
            SelA <= RegASelAltSrc;
            SelOpB <= SelOpBImm;
            StatMask <= FlagsZNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpCOM) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpNOT;
            StatMask <= FlagsZCNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpEOR) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpXOR;
            StatMask <= FlagsZNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpOR) then
            -- defaults fine, just set ALUOp and StatMask
            ALUOp <= ALUOpOR;
            StatMask <= FlagsZNVS;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpORI) then
            -- need to switch to alt register source (upper half) and select 
            -- immediate operand
            ALUOp <= ALUOpOR;
            SelIn <= RegASelAltSrc;
            SelA <= RegASelAltSrc;
            SelOpB <= SelOpBImm;
            StatMask <= FlagsZNVS;
            EnableIn <= '1';
        end if;
        
        

        -- Status instructions
        
        if std_match(IR, OpBCLR) then
            -- disable register write and use IR data to set StatMask
            ALUOp <= ALUOpBCLR;
            EnableIn <= '0';
            StatMask <= (others => '0');
            StatMask(to_integer(unsigned(IRBitSetClear))) <= '1';
        end if;
        
        if std_match(IR, OpBSET) then
            -- disable register write and use IR data to set StatMask
            ALUOp <= ALUOpBSET;
            EnableIn <= '0';
            StatMask <= (others => '0');
            StatMask(to_integer(unsigned(IRBitSetClear))) <= '1';
        end if;
        
        if std_match(IR, OpBLD) then
            -- use IR data to set ALUOp (changing 1 bit of a register)
            ALUOp <= ALUOpBLDPrefix & IRBitLoadStore;
            EnableIn <= '1';
        end if;
        
        if std_match(IR, OpBST) then
            -- use IR data to set ALUOp and disable register write (changing T
            -- bit of status register)
            ALUOp <= ALUOpBSTPrefix & IRBitLoadStore;
            EnableIn <= '0';
            StatMask <= FlagsT;
        end if;
        
        if std_match(IR, OpSWAP) then
            -- defaults fine, just set ALUOp (no status register change)
            ALUOp <= ALUOpSWAP;
            EnableIn <= '1';
        end if;
        

        
        -- Data Memory Access Unit instructions
        
        if std_match(IR, OpLDX) then
            -- load the base address from register X and set the offset to 0
            ImmOffset <= (others => '0');
            -- SelDataAB doesn't matter since offset is 0
            SelWord <= SelWordX;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';  
            end if;
            if Cycle = 2 then
                -- latch the loaded register only (no increment/decrement, so X 
                -- doesn't need to be latched)
                EnableIn <= '1';
                EnableWord <= '0';  
                DataRd <= IOPulse;
            end if;
        end if;
       
        if std_match(IR, OpLDXI) then
            -- load the base address from register X and set the offset to +1
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABBase; -- post-increment
            SelWord <= SelWordX;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
       
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register and the updated value of X
                EnableIn <= '1';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpLDXD) then
            -- load the base address from register X and set the offset to -1
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABTarget; -- pre-decrement
            SelWord <= SelWordX;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
       
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register and the updated value of X
                EnableIn <= '1';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpLDYI) then
            -- load the base address from register Y and set the offset to +1
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABBase; -- post-increment
            SelWord <= SelWordY;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
       
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register and the updated value of Y
                EnableIn <= '1';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpLDYD) then
            -- load the base address from register Y and set the offset to -1
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABTarget; -- pre-decrement
            SelWord <= SelWordY;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
       
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register and the updated value of Y
                EnableIn <= '1';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpLDZI) then
            -- load the base address from register Z and set the offset to +1
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABBase; -- post-increment
            SelWord <= SelWordZ;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
       
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register and the updated value of Z
                EnableIn <= '1';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpLDZD) then
            -- load the base address from register Z and set the offset to -1
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABTarget; -- pre-decrement
            SelWord <= SelWordZ;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
       
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register and the updated value of Z
                EnableIn <= '1';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpLDDY) then
            -- load the base address from register Y and use the offset from IR
            SelDataAB <= SelDataABTarget; -- load with displacement
            SelWord <= SelWordY;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
               EnableIn <= '0';
               EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register only (load with displacement 
                -- doesn't update the base address)
                EnableIn <= '1';
                EnableWord <= '0';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpLDDZ) then
            -- load the base address from register Y and use the offset from IR
            SelDataAB <= SelDataABTarget; -- load with displacement
            SelWord <= SelWordZ;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- latch the loaded register only (load with displacement 
                -- doesn't update the base address)
                EnableIn <= '1';
                EnableWord <= '0';
                DataRd <= IOPulse;
            end if;
        end if;
       
        if std_match(IR, OpLDI) then
            -- not reading from memory space, just writing a register
            -- can't use memory mapped registers here either
            SelRegInput <= SelRegInputImmOpB;
            EnableIn <= '1';
            SelIn <= RegASelAltSrc; -- only upper half of registers
            StatMask <= FlagsNone;
        end if;
        
        if std_match(IR, OpLDS) then
            -- use offset from the register holding second word of instruction, 
            -- and disable using a base address
            ImmOffset <= ImmAddrReg;
            SelDataAB <= SelDataABTarget; -- no base address
            UseAddrBase <= '0';
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
            
            CycleCount <= 3;
            if Cycle = 1 then
                -- latch the next word of the instruction (containing the 
                -- address we're loading from)
                ImmProgOffset <= (0 => '1', others => '0');
                EnableIn <= '0';
                EnableWord <= '0';
                LatchImmAddr <= '0';
            end if;
            if Cycle = 2 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
                LatchImmAddr <= '1';
            end if;
            if Cycle = 3 then
                -- latch the loaded reigster only (no base address to update)
                EnableIn <= '1';
                EnableWord <= '0';
                LatchImmAddr <= '0';
                DataRd <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpMOV) then
            -- connect the register output to the input and latch it
            SelRegInput <= SelRegInputRegBOut;
            EnableIn <= '1';
            StatMask <= FlagsNone;
        end if;
        
        if std_match(IR, OpSTX) then
            -- load the base address from register X and set the offset to 0
            -- the default register output select is already correct
            ImmOffset <= (others => '0');
            -- SelDataAB doesn't matter since offset is 0
            SelWord <= SelWordX;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data only (no increment/decrement, so X doesn't need 
                -- to be latched)
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '0';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTXI) then
            -- load the base address from register X and set the offset to +1
            -- the default register output select is already correct
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABBase; -- post-increment
            SelWord <= SelWordX;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data and latch the updated value of X
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '1';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTXD) then
            -- load the base address from register X and set the offset to -1
            -- the default register output select is already correct
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABTarget; -- pre-decrement
            SelWord <= SelWordX;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data and latch the updated value of X
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '1';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTYI) then
            -- load the base address from register Y and set the offset to +1
            -- the default register output select is already correct
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABBase; -- post-increment
            SelWord <= SelWordY;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data and latch the updated value of Y
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '1';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTYD) then
            -- load the base address from register Y and set the offset to -1
            -- the default register output select is already correct
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABTarget; -- pre-decrement
            SelWord <= SelWordY;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data and latch the updated value of Y
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '1';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTZI) then
            -- load the base address from register Z and set the offset to +1
            -- the default register output select is already correct
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABBase; -- post-increment
            SelWord <= SelWordZ;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data and latch the updated value of Z
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '1';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTZD) then
            -- load the base address from register Z and set the offset to -1
            -- the default register output select is already correct
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABTarget; -- pre-decrement
            SelWord <= SelWordZ;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data and latch the updated value of Z
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '1';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTDY) then
            -- load the base address from register Y and use the offset from IR
            -- the default register output select is already correct
            SelDataAB <= SelDataABTarget; -- store with displacement
            SelWord <= SelWordY;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data only (store with displacement doesn't update the 
                -- base address)
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '0';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTDZ) then
            -- load the base address from register Z and use the offset from IR
            -- the default register output select is already correct
            SelDataAB <= SelDataABTarget; -- store with displacement
            SelWord <= SelWordZ;
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- output data only (store with displacement doesn't update the 
                -- base address)
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '0';
                DataWr <= IOPulse;
            end if;
        end if;
        
        if std_match(IR, OpSTS) then
            -- use offset from the register holding second word of instruction, 
            -- and disable using a base address
            ImmOffset <= ImmAddrReg;
            SelDataAB <= SelDataABTarget; -- no base address
            UseAddrBase <= '0';
            StatMask <= FlagsNone;

            -- set these in case the address is a memory-mapped register
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 3;
            if Cycle = 1 then
                -- latch the next word of the instruction (containing the 
                -- address we're loading into)
                ImmProgOffset <= (0 => '1', others => '0');
                EnableIn <= '0';
                EnableWord <= '0';
                LatchImmAddr <= '0';
            end if;
            if Cycle = 2 then
                -- don't latch anything
                EnableIn <= '0';
                EnableWord <= '0';
                LatchImmAddr <= '1';
            end if;
            if Cycle = 3 then
                -- output data only (no base address to update)
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '0';
                LatchImmAddr <= '0';
                DataWr <= IOPulse;
            end if;
        end if;

        if std_match(IR, OpPOP) then
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABTarget;
            SelWord <= SelWordSP;
            StatMask <= FlagsNone;

            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
       
            CycleCount <= 2;
            if Cycle = 1 then
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                EnableIn <= '1';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if; 
        end if;
        
        if std_match(IR, OpPUSH) then
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABBase;
            SelWord <= SelWordSP;
            StatMask <= FlagsNone;
            
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 2;
            if Cycle = 1 then
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                EnableWord <= '1';
                DataWr <= IOPulse;
            end if;
        end if;

        -- this has to be AFTER all the store instructions so that, if StatusWrite 
        -- comes back as 1, these control signals will take precedence
        if std_match(IR, OpSTX)  or std_match(IR, OpSTXI) or std_match(IR, OpSTXD) or 
           std_match(IR, OpSTYI) or std_match(IR, OpSTYD) or std_match(IR, OpSTZI) or 
           std_match(IR, OpSTZD) or std_match(IR, OpSTDY) or std_match(IR, OpSTDZ) or
           std_match(IR, OpSTS)  or std_match(IR, OpPUSH) then

            -- tell ALU to set status register directly
            ALUOp <= ALUOpSTAT;

            -- normally data to write is on data bus, but the source of that is 
            -- the A bus output from the register array, which is the default 
            -- connection to operand A of the ALU

            if StatusWrite = '1' and Cycle = CycleCount then
                -- let the new value go through
                StatMask <= "11111111";

                -- register array still setup to latch a value, but it doesn't 
                -- matter since the register it's trying to latch to doesn't exist
            end if;
        end if;



        -- Flow control instructions

        if std_match(IR, OpJMP) then
            -- Don't write anything to registers for JMP instruction
            EnableIn <= '0'; 
            EnableWord <= '0';

            CycleCount <= 3;

            if Cycle = 1 then
                -- increment PC and latch the next word, which is the address to jump to
                ImmProgOffset <= (0 => '1', others => '0');
                LatchImmAddr <= '1';
            end if;
            if Cycle = 2 then
                -- idle
                LatchImmAddr <= '0';
            end if;
            if Cycle = 3 then
                -- do a non-relative jump to the word we latched earlier
                ProgLoad <= '0';
                ImmProgOffset <= ImmAddrReg;                        
            end if;
        end if;
           
        if std_match(IR, OpRJMP) then
            -- Don't write anything to registers for RJMP instruction
            EnableIn <= '0';
            EnableWord <= '0';

            CycleCount <= 2;

            if Cycle = 1 then
                -- We need PC = PC + 1 + j, so first just do the + 1
                ImmProgOffset <= (0 => '1', others => '0');
            end if;
            if Cycle = 2 then
                -- Now do the + j (the relative offset)
                ImmProgOffset <= IRImmProgRel;
            end if; 
        end if;
            
        if std_match(IR, OpIJMP) then
            -- No register writes
            EnableIn <= '0';
            EnableWord <= '0';

            CycleCount <= 2;

            if Cycle = 1 then
                -- don't need to do anything here
            end if;
            if Cycle = 2 then
                -- do a non-relative jump to the address in Z
                ProgLoad <= '0';
                ImmProgOffset <= InputZ;
            end if;   
        end if;         
                
        if std_match(IR, OpCALL) then
            -- post-decrement of SP (SP points to first empty slot)
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABBase;
            SelWord <= SelWordSP;

            -- technically needed for memory-mapped registers, but there's 
            -- probably an issue if the stack pointer is pointing to them...
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 4;
            if Cycle = 1 then
                -- fetch the next word, which is where we're jumping to
                ImmProgOffset <= (0 => '1', others => '0'); 
                LatchImmAddr <= '1';

                -- don't update anything yet
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 2 then
                -- update PC to point to where we'll return to, but don't latch anything
                LatchImmAddr <= '0';
                ImmProgOffset <= (0 => '1', others => '0');

                -- don't update anything yet
                EnableIn <= '0';
                EnableWord <= '0';
            end if; 
            if Cycle = 3 then
                -- PC is pointing to the return address now, don't change it
                ImmProgOffset <= (others => '0');

                -- store the high byte of the return address
                SelStoreVal <= SelStoreValPCHigh;
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                DataWr <= IOPulse;

                -- update SP to point at the next free slot
                EnableWord <= '1';
            end if;
            if Cycle = 4 then
                -- output the address we're calling (PC will still be the return address)
                ProgLoad <= '0'; -- Non-Relative 
                ImmProgOffset <= ImmAddrReg;

                -- store the low byte of the return address
                SelStoreVal <= SelStoreValPCLow;
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                DataWr <= IOPulse;

                -- update SP to point at the next free slot
                EnableWord <= '1';
            end if;
        end if;
    
        if std_match(IR, OpRCALL) then
            -- post-decrement of SP (SP points to first empty slot)
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABBase;
            SelWord <= SelWordSP;
            
            -- technically needed for memory-mapped registers, but there's 
            -- probably an issue if the stack pointer is pointing to them...
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 3;
            if Cycle = 1 then
                -- update PC to point to where we'll return to
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1

                EnableIn <= '0';
                EnableWord <= '0';
            end if; 
            if Cycle = 2 then
                -- PC is pointing to the return address now, don't change it
                ImmProgOffset <= (others => '0');

                -- store the high byte of the return address
                SelStoreVal <= SelStoreValPCHigh;
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                DataWr <= IOPulse;

                -- update SP to point at the next free slot
                EnableWord <= '1';
            end if;
            if Cycle = 3 then
                -- output the address we're calling (PC will still be the return address)
                ImmProgOffset <= IRImmProgRel; -- PC = PC + 1 + j

                -- store the low byte of the return address
                SelStoreVal <= SelStoreValPCLow;
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                DataWr <= IOPulse;
                
                -- update SP to point at the next free slot
                EnableWord <= '1';
            end if;
        end if;   
            
        if std_match(IR, OpICALL) then
            -- post-decrement of SP (SP points to the first empty slot)
            ImmOffset <= (others => '1');
            SelDataAB <= SelDataABBase;
            SelWord <= SelWordSP;
            
            -- technically needed for memory-mapped registers, but there's 
            -- probably an issue if the stack pointer is pointing to them...
            SelIn <= InternalAddr;
            SelRegInput <= SelRegInputDataDB;
            
            CycleCount <= 3;
            if Cycle = 1 then
                -- update PC to point to where we'll return to
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1

                EnableIn <= '0';
                EnableWord <= '0';
            end if; 
            if Cycle = 2 then
                -- PC is point to the return address now, don't change it

                -- store the high byte of the return address
                SelStoreVal <= SelStoreValPCHigh;
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                DataWr <= IOPulse;

                -- update SP to point at the next free slot
                EnableWord <= '1';
            end if;
            if Cycle = 3 then
                -- output the address we're calling (PC will still be the return address)
                ProgLoad <= '0'; -- Non-Relative
                ImmProgOffset <= InputZ; -- use address in Z register

                -- store the low byte of the return address
                SelStoreVal <= "01"; -- (SP) = (PC+1)[7:0]
                SelLoadStore <= SelStore;
                EnableIn <= StoreEnableRegIn;
                DataWr <= IOPulse;

                -- update SP to point at the next free slot
                EnableWord <= '1';
            end if;
        end if; 
 
        if std_match(IR, OpRET) then
            -- pre-increment of SP
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABTarget;
            SelWord <= SelWordSP;
            
            -- technically needed for memory-mapped registers, but there's 
            -- probably an issue if the stack pointer is pointing to them...
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
            
            CycleCount <= 4;
            if Cycle = 1 then
                -- store the low byte of PC (on the data bus) into PC and update SP
                SelPCInput <= SelPCInputDataDBLow;
                EnableIn <= '0';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
            if Cycle = 2 then
                -- store the high byte of PC (on the data bus) into PC and update SP
                SelPCInput <= SelPCInputDataDBHigh;
                EnableIn <= '0';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if; 
            if Cycle = 3 then
                -- idle
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 4 then
                -- PC already has the correct return address; no need to increment it
                ImmProgOffset <= (others => '0');
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
        end if; 
 
        if std_match(IR, OpRETI) then
            -- pre-increment of SP
            ImmOffset <= (0 => '1', others => '0');
            SelDataAB <= SelDataABTarget;
            SelWord <= SelWordSP;
            
            -- technically needed for memory-mapped registers, but there's 
            -- probably an issue if the stack pointer is pointing to them...
            SelB <= InternalAddr;
            SelRegInput <= LoadSelRegInput;
            
            CycleCount <= 4;
            if Cycle = 1 then
                -- store the low byte of PC (on the data bus) into PC and update SP
                SelPCInput <= SelPCInputDataDBLow;
                EnableIn <= '0';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if;
            if Cycle = 2 then
                -- store the high byte of PC (on the data bus) into PC and update SP
                SelPCInput <= SelPCInputDataDBHigh;
                EnableIn <= '0';
                EnableWord <= '1';
                DataRd <= IOPulse;
            end if; 
            if Cycle = 3 then
                -- set the interrupt status flag
                ALUOp <= ALUOpBSET;
                StatMask <= (FLAG_I => '1', others => '0');

                -- otherwise idle
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
            if Cycle = 4 then
                -- PC already has the correct return address; no need to increment it
                ImmProgOffset <= (others => '0');
                EnableIn <= '0';
                EnableWord <= '0';
            end if;
        end if; 
           
        if std_match(IR, OpBRBC) then
            EnableIn <= '0';
            EnableWord <= '0';

            -- check if the appropriate bit in the status register is cleared
            if(StatRegIn(to_integer(unsigned(IRBitFlowControl))) = '0') then
                -- take the branch, which occurs on the second cycle
                CycleCount <= 2;
            else
                -- don't branch by skipping the second cycle
                CycleCount <= 1;
            end if;    
               
            if Cycle = 1 then
                -- just increment PC, needed for both branch and no branch
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
            end if;
            if Cycle = 2 then
                -- perform the relative branch
                ImmProgOffset <= IRImmConRel; -- PC = PC + 1 + r
            end if;
        end if;
           
        if std_match(IR, OpBRBS) then
            EnableIn <= '0';
            EnableWord <= '0';

            -- check if the appropriate bit in the status register is set
            if(StatRegIn(to_integer(unsigned(IRBitFlowControl))) = '1') then
                -- take the branch, which occurs on the second cycle
                CycleCount <= 2;
            else
                -- don't branch by skipping the second cycle
                CycleCount <= 1;
            end if;    
               
            if Cycle = 1 then
                -- just increment PC, needed for both branch and no branch
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
            end if;
            if Cycle = 2 then
                -- perform the relative branch
                ImmProgOffset <= IRImmConRel; -- PC = PC + 1 + r
            end if;
        end if;
           
        if std_match(IR, OpCPSE) then
            -- compare the two registers (default values fine) by subracting 
            -- them in the ALU, but don't latch the result
            ALUOp <= ALUOpSUB;
            EnableIn <= '0';

            if Cycle = 1 then
                -- check the zero flag that's directly connected from the ALU
                if ZeroFlag = '1' then
                    -- equal, so do the skip (which starts on the second cycle)
                    CycleCount <= 2;
                else
                    -- not equal, don't skip by only running for one cycle
                    CycleCount <= 1;
                end if;
                
                -- increment PC, needed for both skip and no skip
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
                
                -- latch the next word in case we're skipping so we can tell how 
                -- long the instruction we're skipping is
                LatchImmAddr <= '1';
            end if;
            if Cycle = 2 then
                -- increment PC, needed for skipping both one and two word instructions
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1

                -- check if this is a two word instruction
                if (std_match(ImmAddrReg, OpLDS) or std_match(ImmAddrReg, OpSTS) or 
                    std_match(ImmAddrReg, OpJMP) or std_match(ImmAddrReg, OpCALL)) then
                    -- two word instruction, we need to skip the next word too
                    CycleCount <= 3;
                else
                    -- one word instruction, skip is done after this cycle
                    CycleCount <= 2;
                end if;
            end if;
            if Cycle = 3 then
                -- increment PC to skip the second word of the instruction
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
                CycleCount <= 3;
            end if;
        end if;      

        if std_match(IR, OpSBRC) then
            EnableIn <= '0';

            if Cycle = 1 then
                -- check if the appropriate bit in the A register bus output is cleared
                if(RegAVal(to_integer(unsigned(IRBitFlowControl))) = '0') then
                    -- do the skip (which starts on the second cycle)
                    CycleCount <= 2;
                else
                    -- don't skip by only running for one cycle
                    CycleCount <= 1;
                end if;

                -- increment PC, needed for both skip and no skip
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
                
                -- latch the next word in case we're skipping so we can tell how 
                -- long the instruction we're skipping is
                LatchImmAddr <= '1';
            end if;
            if Cycle = 2 then
                -- increment PC, needed for skipping both one and two word instructions
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1

                -- check if this is a two word instruction
                if (std_match(ImmAddrReg, OpLDS) or std_match(ImmAddrReg, OpSTS) or 
                    std_match(ImmAddrReg, OpJMP) or std_match(ImmAddrReg, OpCALL)) then
                    -- two word instruction, we need to skip the next word too
                    CycleCount <= 3;
                else
                    -- one word instruction, skip is done after this cycle
                    CycleCount <= 2;
                end if;
            end if;
            if Cycle = 3 then
                -- increment PC to skip the second word of the instruction
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
                CycleCount <= 3;
            end if;
        end if;      

        if std_match(IR, OpSBRS) then
            EnableIn <= '0';
            
            if Cycle = 1 then
                -- check if the appropriate bit in the A register bus output is set
                if(RegAVal(to_integer(unsigned(IRBitFlowControl))) = '1') then
                    -- do the skip (which starts on the second cycle)
                    CycleCount <= 2;
                else
                    -- don't skip by only running for one cycle
                    CycleCount <= 1;
                end if;

                -- increment PC, needed for both skip and no skip
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
                
                -- latch the next word in case we're skipping so we can tell how 
                -- long the instruction we're skipping is
                LatchImmAddr <= '1';
            end if;
            if Cycle = 2 then
                -- increment PC, needed for skipping both one and two word instructions
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1

                -- check if this is a two word instruction
                if (std_match(ImmAddrReg, OpLDS) or std_match(ImmAddrReg, OpSTS) or 
                    std_match(ImmAddrReg, OpJMP) or std_match(ImmAddrReg, OpCALL)) then
                    -- two word instruction, we need to skip the next word too
                    CycleCount <= 3;
                else
                    -- one word instruction, skip is done after this cycle
                    CycleCount <= 2;
                end if;
            end if;
            if Cycle = 3 then
                -- increment PC to skip the second word of the instruction
                ImmProgOffset <= (0 => '1', others => '0'); -- PC = PC + 1
                CycleCount <= 3;
            end if;
        end if;  
        
        if std_match(IR, OpIN) then
            -- put the IO register address on the B register output and connect it to the input
            SelB <= RegIOSrc;
            SelRegInput <= SelRegInputRegBOut;
            EnableIn <= '1';
        end if;
           
        if std_match(IR, OpOUT) then
            -- put the IO register address on the register input and connect the standard 
            -- register output to it
            SelIn <= RegIOSrc;
            SelB <= RegASelSrc;
            SelRegInput <= SelRegInputRegBOut;
            EnableIn <= '1';
        end if;

        -- OpNOP does nothing, and control signal defaults result in nothing 
        -- happening (except PC increment), so don't need a conditional for it


        -- While we're in reset, don't try to increment PC
        -- This needs to be AFTER all other instructions so that it takes 
        -- precedence over the other places where we change ImmProgOffset
        if Reset = '0' then
            ImmProgOffset <= (others => '0');
        end if;

    end process;


	-- Instruction register; holds the currently executing instruction.
    -- Latch the value on ProgDB if IR enable is set, which is always on 
    -- the last cycle of the previous instruction
	process (CLK) 
	begin
		if rising_edge(CLK) then
            if EnableIR = '1' then
                IR <= ProgDB;
            end if;
		end if;
	end process;
	

    -- Immediate Address register: holds the second word of a two-word 
    -- instruction; i.e., the immediate memory address for LDS and STS. Only 
    -- latched on the first cycle after an LDS or STS instruction is received 
    process (CLK)
    begin
        if rising_edge(CLK) then
            if LatchImmAddr = '1' then
                ImmAddrReg <= ProgDB;
            end if;
        end if;
    end process; 
    

    -- Simple counter: used to keep track of the cycle number for multi-cycle 
    -- instructions; incremented/reset on rising edge of CLK
    process (CLK)
    begin
        if rising_edge(CLK) then
            if Cycle < CycleCount then
                -- increment cycle number
                Cycle <= Cycle + 1;
            else
                -- reset cycle number
                Cycle <= 1;
            end if;
        end if;
    end process;
        
end Behavioral;
