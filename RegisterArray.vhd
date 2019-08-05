library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.opcodes.all;
use xil_defaultlib.constants.all;

--
-- Entity Name: 
-- 	 RegisterArray
--
-- Description: 
--   This is an entity for the general purpose register set. The register set has NUM_REGS registers. 
--   This includes both the standard registers (r0-r31) and the I/O registers (64).
--
--   It receives data from RegIn to write the value into a desired register. SelIn signal is decoded to select
--   the register to write. EnableIn is set when writing a register and reset when not writing a register.
--   In case of instructions that do not save the result in a register, EnableIn will be reset.
--   SelA and SelB select the registers to output on channel A and B, respectively.
--   RegIn may come from different sources.(e.g. ALU output, data bus, etc.) However, a MUX that selects 
--   the sourcesof RegIn is implemented outside the RegisterArray entity in following assignments.
--
--   Additionally, the X, Y, Z, and SP register pairs can be accessed directly and independently 
--   for addressing. SelWord selects which of these to access, and EnableWord enables writing the 
--   value on RegWordIn to them. The Z register is also always output on a separate read-only bus 
--   for use with IJMP and ICALL.
--
-- Inputs
--	CLK: The source clock
--  	EnableIn: Enables writing to a register in the register set (1 bit)
--	SelIn: Selects the register to be written (REG_SEL_SIZE bits)
--	SelA: Selects the register to be output on OperandA bus (REG_SEL_SIZE bits)
--	SelB: Selects the register to be output on OperandB bus (REG_SEL_SIZE bits)
--	RegIn: The data to be written to a register in RegisterArray (5 bits)
--
--      SelWord: Selects register pair to be read/written (X, Y, Z, SP) (4 bits)
--      EnableWord: Enables writing to a register pair (1 bit)
--      RegWordIn: The data to be written to a register pair (WORD_SIZE bits)
--
--      StatRegIn: status register input so that it can still be accessed through 
--                 the register array even though it is in the ALU (REG_SIZE bits)
--
--      Reset: active-low reset to initialize SP to all 1s (1 bit)
--
-- Outputs
--	RegAOut: The register value output on OperandA bus (REG_SIZE bits)
--      RegBOut: The register value output on OperandB bus (REG_SIZE bits)
--      RegWordOut : The register pair output (X, Y, Z, or SP) (WORD_SIZE bits)
--      RegZOut : The register pair Z output, needed for IJMP and ICALL since the 
--                RegWordOut bus is taken up by SP (WORD_SIZE bits)
--      StatusWrite : high if a write to the status register was requested; this 
--                    operation can't be done by the register array and must be 
--                    redirected through the ALU
--
-- Revision History
--	 01/24/2019	 Sung Hoon Choi	 Created
--	 01/25/2019	 Sung Hoon Choi	 Completed the code, First simulation
--	 02/02/2019	 Sung Hoon Choi	 Corrected an error in DecoderOut
--	 02/03/2019	 Sung Hoon Choi	 Added comments
--   02/05/2019  Sung Hoon Choi  Added independent access of X, Y, Z pair registers
--   02/10/2019  Sung Hoon Choi  Added I/O registers including the stack pointer.(r94:r93)
--   02/10/2019  Garret Sullivan Updated comments
--   02/19/2019  Garret Sullivan Move status register out of RegisterArray
--   02/25/2019  Garret Sullivan Updated comments
--

entity RegisterArray is
    port (
        -- Clock signal
        CLK     : in std_logic;

        -- Register array read/write control signals
        EnableIn : in std_logic;                                  -- Enables writing to a reg
        SelIn    : in std_logic_vector(REG_SEL_SIZE-1 downto 0);  -- Selects reg to write
        SelA     : in std_logic_vector(REG_SEL_SIZE-1 downto 0);  -- Selects reg to output on A bus
        SelB     : in std_logic_vector(REG_SEL_SIZE-1 downto 0);  -- Selects reg to output on B bus

        -- Register array input
        RegIn    : in std_logic_vector(REG_SIZE-1 downto 0);  -- The data to write to a reg

        -- Register array outputs
        RegAOut  : out std_logic_vector(REG_SIZE-1 downto 0); -- The register value output on A bus
        RegBOut  : out std_logic_vector(REG_SIZE-1 downto 0); -- The register value output on B bus
        
        -- Homework 4
        -- Loading and reading XYZ and SP registers independent from other registers.
        SelWord    : in sel_word;  -- value defined in constants.vhd
        EnableWord : in std_logic; -- Is the current opcode Load or Store?
        RegWordIn  : in std_logic_vector(WORD_SIZE-1 downto 0); -- updated X, Y, Z, or SP
        RegWordOut : out std_logic_vector(WORD_SIZE-1 downto 0);

        -- Homework 5
        -- Needed for ICALL
        RegZOut    : out std_logic_vector(WORD_SIZE-1 downto 0);
        
        Reset : in std_logic;

        StatRegIn   : in std_logic_vector(REG_SIZE-1 downto 0);
        StatusWrite : out std_logic
    );
end RegisterArray;

architecture Behavioral of RegisterArray is

	-- Register Array is an array of DFFs
    component DFF
        port(
            clk: in std_logic; -- Clock signal
            En: in std_logic;  -- Enable DFF
            D: in std_logic_vector(REG_SIZE-1 downto 0);   -- Data to Save
            Q: out std_logic_vector(REG_SIZE-1 downto 0)); -- Output of DFF
    end component;
    
	-- Since the register array is a NUM_REGS registers of REG_SIZE bits, define it as a type
    type logic_vector_array is array (NUM_REGS-1 downto 0) of std_logic_vector(REG_SIZE-1 downto 0);

	-- Signifies the index of register to be enabled and updated with a new value
    signal SelIn_Decoded: natural;
    signal SelA_Decoded: natural;
    signal SelB_Decoded: natural;
	-- Values of each registers. SelA and SelB are used as MUX control signal to select one of 
    -- these values as an output
    signal SelMuxInput: logic_vector_array;

	-- The output of Select Decoder. This signal actually selects the register to be enabled and 
    -- written a new value
    signal DecoderOut: std_logic_vector(NUM_REGS-1 downto 0);

    -- Enable signals to determine when a register pair is selected
    signal EnXYZ: std_logic_vector(5 downto 0);
    signal EnSP: std_logic_vector(1 downto 0);

    -- Data sources for the register pairs to control whether data is loaded from RegIn or RegWordIn
    signal Pair_LowData : std_logic_vector(REG_SIZE-1 downto 0);
    signal Pair_highData: std_logic_vector(REG_SIZE-1 downto 0);
    signal SP_LowData : std_logic_vector(REG_SIZE-1 downto 0);
    signal SP_HighData: std_logic_vector(REG_SIZE-1 downto 0);
    
begin

---- Use the decoded SelIn as an index to enable & write the target register.
---- If EnableIn is reset, disable writing to any register
process(SelIn_Decoded, SelIn, EnableIn)
begin
    SelIn_Decoded <= to_integer(unsigned(SelIn));
    DecoderOut <= x"000000000000000000000000";

    -- if address is invalid (which it might be because of how memory-mapped registers are 
    -- implemented) just don't enable writing to any register
    if(SelIn_Decoded < NUM_REGS) then
        DecoderOut(SelIn_Decoded) <= EnableIn; -- Update only when EabledIn is set
    end if;
end process;

-- we're trying to write to status if the corresponding bit in DecoderOut is set
StatusWrite <= DecoderOut(REG_STATUS);


-- Generate registers. While their input is RegIn, their outputs are fed into a MUX for selecting 
-- Output A,B.
genGenReg: for i in 0 to REG_X_LOW-1 generate
    DFFs: DFF port map(CLK => CLK, En => DecoderOut(i), D => RegIn, Q => SelMuxInput(i));
end generate;

-- skip X, Y, Z register range

genIOReg: for i in REG_Z_HIGH+1 to REG_SP_LOW-1 generate
    DFFs: DFF port map(CLK => CLK, En => DecoderOut(i), D => RegIn, Q => SelMuxInput(i));
end generate;

-- skip SP register range

-- mux input for the status register is just the status register input itself
SelMuxInput(REG_STATUS) <= StatRegIn;


-- Homework 4
-- If the instruction is load/store, enable the flipflops and load the address to register pairs

-- If Opcode is Load or Store, update X Y Z registers independently from other registers
X_low:  DFF port map(CLK => CLK, En => EnXYZ(0), D => Pair_LowData,  Q => SelMuxInput(REG_X_LOW));
X_high: DFF port map(CLK => CLK, En => EnXYZ(1), D => Pair_HighData, Q => SelMuxInput(REG_X_HIGH));

Y_low:  DFF port map(CLK => CLK, En => EnXYZ(2), D => Pair_LowData,  Q => SelMuxInput(REG_Y_LOW));
Y_high: DFF port map(CLK => CLK, En => EnXYZ(3), D => Pair_HighData, Q => SelMuxInput(REG_Y_HIGH));

Z_low:  DFF port map(CLK => CLK, En => EnXYZ(4), D => Pair_LowData,  Q => SelMuxInput(REG_Z_LOW));
Z_high: DFF port map(CLK => CLK, En => EnXYZ(5), D => Pair_HighData, Q => SelMuxInput(REG_Z_HIGH));
    
-- Stack Pointer
SP_low:  DFF port map(CLK => CLK, En => EnSP(0), D => SP_LowData,  Q => SelMuxInput(REG_SP_LOW));
SP_high: DFF port map(CLK => CLK, En => EnSP(1), D => SP_HighData, Q => SelMuxInput(REG_SP_HIGH));
    
-- Transfer X or Y or Z or SP to data access unit as the base address.    
RegWordOut <=  SelMuxInput(REG_X_HIGH)  & SelMuxInput(REG_X_LOW)  when SelWord = SelWordX else
               SelMuxInput(REG_Y_HIGH)  & SelMuxInput(REG_Y_LOW)  when SelWord = SelWordY else
               SelMuxInput(REG_Z_HIGH)  & SelMuxInput(REG_Z_LOW)  when SelWord = SelWordZ else
               SelMuxInput(REG_SP_HIGH) & SelMuxInput(REG_SP_LOW) when SelWord = SelWordSP else
               (others => '0');

-- Output Z directly for IJMP and ICALL
RegZOut <= SelMuxInput(REG_Z_HIGH) & SelMuxInput(REG_Z_LOW); 

-- Enable writing to Stack Pointer (r94:r93) indepedently from other registers
-- SP needs to be set to all 1s when Reset is low
EnSP(0) <= '1'            when Reset = '0' else
           SelWord(3)     when EnableWord = '1' else
           DecoderOut(REG_SP_LOW);
EnSP(1) <= '1'            when Reset = '0' else
           SelWord(3)     when EnableWord = '1' else
           DecoderOut(REG_SP_HIGH);

-- Enable writing to X Y Z registers independently from other registers.
-- Enable for X
EnXYZ(0) <=  SelWord(0) when EnableWord = '1' else -- when the operation is load/store
             DecoderOut(REG_X_LOW);                -- when the operation is not load/store
EnXYZ(1) <=  SelWord(0) when EnableWord = '1' else -- when the operation is load/store
             DecoderOut(REG_X_HIGH);               -- when the operation is not load/store     
-- Enable for Y
EnXYZ(2) <=  SelWord(1) when EnableWord = '1' else -- when the operation is load/store
             DecoderOut(REG_Y_LOW);                -- when the operation is not load/store
EnXYZ(3) <=  SelWord(1) when EnableWord = '1' else -- when the operation is load/store
             DecoderOut(REG_Y_HIGH);               -- when the operation is not load/store   
-- Enable for Z
EnXYZ(4) <=  SelWord(2) when EnableWord = '1' else -- when the operation is load/store
             DecoderOut(REG_Z_LOW);                -- when the operation is not load/store
EnXYZ(5) <=  SelWord(2) when EnableWord = '1' else -- when the operation is load/store
             DecoderOut(REG_Z_HIGH);               -- when the operation is not load/store   

-- SP neesd to be set to all 1s when Reset is low
SP_LowData  <= (others => '1')                when Reset = '0' else
               RegWordIn(REG_SIZE-1 downto 0) when EnableWord = '1' else
               RegIn;
SP_HighData <= (others => '1')                         when Reset = '0' else
               RegWordIn(2*REG_SIZE-1 downto REG_SIZE) when EnableWord = '1' else
               RegIn;

Pair_LowData  <= RegWordIn(REG_SIZE-1 downto 0) when EnableWord = '1' else
                 RegIn;          
Pair_HighData <= RegWordIn(2*REG_SIZE-1 downto REG_SIZE) when EnableWord = '1' else
                 RegIn;


-- Choose the values to be output on RegAOut and RegBOut, by using SelA and SelB as the control 
-- signals for output MUX
SelA_Decoded <= to_integer(unsigned(SelA));
SelB_Decoded <= to_integer(unsigned(SelB));

-- if address is invalid (which it might be because of how memory-mapped registers are 
-- implemented), just output 0s
RegAOut <=  SelMuxInput(SelA_Decoded) when SelA_Decoded < NUM_REGS else
            (others => '0');
RegBOut <=  SelMuxInput(SelB_Decoded) when SelB_Decoded < NUM_REGS else
            (others => '0');

end Behavioral;
