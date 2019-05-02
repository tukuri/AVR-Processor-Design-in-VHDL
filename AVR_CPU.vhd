----------------------------------------------------------------------------
--
--  Atmel AVR CPU Entity Declaration
--
--  This is the entity declaration for the complete AVR CPU.  The design
--  should implement this entity to make testing possible.
--
--  Revision History:
--     11 May 98  Glen George       Initial revision.
--      9 May 00  Glen George       Updated comments.
--      7 May 02  Glen George       Updated comments.
--     21 Jan 08  Glen George       Updated comments.
--     23 Feb 19  Sung Hoon Choi    Assembled components
--     25 Feb 19  Garret Sullivan   Updated comments
--     25 Feb 19  Sung Hoon Choi    Updated header
--
----------------------------------------------------------------------------


--
--  AVR_CPU
--
--  This is the complete entity declaration for the AVR CPU.  It is used to
--  test the complete design.
--  IR is updated by ProgDB at the control unit. Data Memory Access unit sets 
--  the address of data to read or write (DataAB) and read from or write to
--  the data memory.(Load, POP: read/ Store, PUSH: write) DataWr and DataRd 
--  are write enable signals and read enable signals for Data Memory Access Unit,
--  respectively. They are toggled at the last cycles of instructions that
--  use Data bus.Program address (ProgAB) can be updated by the immediate value 
--  included in the instruction(thus from control unit) or updated by the stack pointer
--  SP (in case of RET and RETI), or updated incrementally(PC+1) within the Program
--  Memory Access unit.Register Array can be updated either through the RegOutB itself, or
--  DataDB or Immediate value or the ALU output. The source to update
--  register array can be selected through a control signal. Note that the status 
--  registers are included in the ALU unit.
--  Inside Register Array, r27:r26(X), r29:r28(Y), r31:r30(Z) are the pairs of 
--  registers that need an independent access for load and store instructions.
--  Thus, there are separate logic for them inside Register Array. SP is also
--  a pair of registers that has an independent access for RET and RETI instructions.
--  In this case, (SP) is transferred to PC through DataDB bus. Also, note that
--  control logic has an independent access to Register Pair Z (for ICALL, IJMP)
--  and status flag z (for CPSE)
--  
--  Inputs:
--    ProgDB - program memory data bus (16 bits)
--    Reset  - active low reset signal
--    INT0   - active low interrupt
--    INT1   - active low interrupt
--    clock  - the system clock
--
--  Outputs:
--    ProgAB - program memory address bus (16 bits)
--    DataAB - data memory address bus (16 bits)
--    DataWr - data write signal
--    DataRd - data read signal
--
--  Inputs/Outputs:
--    DataDB - data memory data bus (8 bits)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.opcodes.all;
use xil_defaultlib.constants.all;


entity  AVR_CPU  is

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

end  AVR_CPU;

architecture behavioral of AVR_CPU is

component ControlUnit is
    port (
        CLK    : in std_logic;
        Reset  : in std_logic;
        ProgDB : in std_logic_vector(WORD_SIZE-1 downto 0);

        IsInternalAddr : in std_logic;
        InternalAddr   : in std_logic_vector(REG_SEL_SIZE-1 downto 0);
        
        -- Used for IJMP and ICALL
        -- From Register Array
        InputZ      : in std_logic_vector(WORD_SIZE-1 downto 0);
        StatRegIn   : in std_logic_vector(REG_SIZE-1 downto 0);
        ZeroFlag    : in std_logic;
        RegAVal     : in std_logic_vector(BYTE_SIZE-1 downto 0);
       
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

        StatusWrite : in std_logic;

        -- Control Bus
        DataRd       : out std_logic;
        DataWr       : out std_logic
    );
end component;

component RegisterArray is
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
        RegWordOut : out std_logic_vector(WORD_SIZE-1 downto 0);

        -- Homework 5
        RegZOut    : out std_logic_vector(WORD_SIZE-1 downto 0);
        RegWordIn  : in  std_logic_vector(WORD_SIZE-1 downto 0); -- updated X, Y, Z, or SP
        SelWord    : in  sel_word;  -- value defined in constants.vhd
        EnableWord : in  std_logic; -- Is the current opcode Load or Store?
        
        Reset : in std_logic;

        StatRegIn   : in std_logic_vector(REG_SIZE-1 downto 0);
        StatusWrite : out std_logic
    );
end component;

component ALU is
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
end component;

component DataMemAccess is
    port (
        AddrBase     : in  std_logic_vector(WORD_SIZE-1 downto 0);
        AddrOffset   : in  std_logic_vector(WORD_SIZE-1 downto 0);
        AddrTarget   : out std_logic_vector(WORD_SIZE-1 downto 0);
        
        UseAddrBase  : in  std_logic;
        
        SelLoadStore : in  sel_load_store;
		StoreVal     : in  std_logic_vector(REG_SIZE-1 downto 0); -- Can be RegBOut, PC[15:8], or PC[7:0]

        IsInternalAddr : out std_logic;
		
        SelDataAB    : in  sel_data_ab;
        DataAB       : out std_logic_vector(WORD_SIZE-1 downto 0);
        
        DataDB       : inout std_logic_vector(REG_SIZE-1 downto 0);
        DataWr       : in std_logic
    );
end component;

component ProgMemAccess is
port(
    ImmProgOffset: in std_logic_vector(15 downto 0); -- 22 bit program address (upper 6 bits are ignored in this implementation) from Control Unit
    ProgLoad: in std_logic; -- Relative or Non-Relative from Control Unit
    Clock: in std_logic; -- system clock
    Reset: in std_logic;
    DataDB: in std_logic_vector(7 downto 0);
    SelPCInput: in std_logic_vector(1 downto 0); -- Select updating PC[15:8] or PC[7:0] or ProgDB. For RET and RETI
    CurrProgAddr:out std_logic_vector(15 downto 0);
    ProgAB: out std_logic_vector(15 downto 0)-- 16 bit updated program address
     );
end component;


-- Define some signals to connect the various components together

-- Register array
signal EnableIn    : std_logic;
signal SelIn       : std_logic_vector(REG_SEL_SIZE-1 downto 0);
signal SelA        : std_logic_vector(REG_SEL_SIZE-1 downto 0);
signal SelB        : std_logic_vector(REG_SEL_SIZE-1 downto 0);
signal OperandA    : std_logic_vector(REG_SIZE-1 downto 0);
signal OperandB    : std_logic_vector(REG_SIZE-1 downto 0);
signal SelWord     : sel_word;
signal EnableWord  : std_logic;
signal RegDataIn   : std_logic_vector(REG_SIZE-1 downto 0);
signal SelRegInput : sel_reg_input;

-- ALU
signal ALUOp         : opcode_alu;
signal SelOpA        : sel_op_a;
signal SelOpB        : sel_op_b;
signal ImmOpB        : std_logic_vector(REG_SIZE-1 downto 0);
signal StatMask      : std_logic_vector(REG_SIZE-1 downto 0);
signal ALUOpA        : std_logic_vector(REG_SIZE-1 downto 0);
signal ALUOpB        : std_logic_vector(REG_SIZE-1 downto 0);
signal ALUResult     : std_logic_vector(REG_SIZE-1 downto 0);
signal StatReg       : std_logic_vector(REG_SIZE-1 downto 0);
signal ZeroFlag      : std_logic;
signal RegZOut       : std_logic_vector(WORD_SIZE-1 downto 0);
signal PropagateZero : std_logic;

-- Data memory access unit

signal AddrBase       : std_logic_vector(WORD_SIZE-1 downto 0);
signal AddrTarget     : std_logic_vector(WORD_SIZE-1 downto 0);
signal SelLoadStore   : sel_load_store;
signal SelDataAB      : sel_data_ab;
signal ImmOffset      : std_logic_vector(WORD_SIZE-1 downto 0);
signal UseAddrBase    : std_logic;
signal IsInternalAddr : std_logic;
signal SelStoreVal    : std_logic_vector(1 downto 0);

-- Program memory access unit
signal StoreVal      : std_logic_vector(REG_SIZE-1 downto 0);
signal PC            : std_logic_vector(WORD_SIZE-1 downto 0);
signal ProgLoad      : std_logic;
signal SelPCInput    : std_logic_vector(1 downto 0);
signal StatusWrite   : std_logic;
signal ImmProgOffset : std_logic_vector(WORD_SIZE-1 downto 0);

begin

    -- mux between various inputs to the ALU based on select control signals
    ALUOpA <= OperandA   when SelOpA = SelOpARegAOut else
              "00000000" when SelOpA = SelOpA0       else
              "XXXXXXXX";
              
    ALUOpB <= OperandB   when SelOpB = SelOpBRegBOut else
              OperandA   when SelOpB = SelOpBRegAOut else
              ImmOpB     when SelOpB = SelOpBImm     else
              "XXXXXXXX";
    
    -- mux between the possible input sources to the register array
    RegDataIn <= DataDB     when SelRegInput = SelRegInputDataDB    else
                 ImmOpB     when SelRegInput = SelRegInputImmOpB    else
                 ALUResult  when SelRegInput = SelRegInputALUResult else
                 OperandB   when SelRegInput = SelRegInputRegBOut  else
                 "XXXXXXXX";
    
    -- mux between the input sources to the data data bus via the data 
    -- memory access unit (either a register array output or the PC for calls)
    StoreVal <= OperandA                         when SelStoreVal = SelStoreValRegAOut else
                PC(2*REG_SIZE-1 downto REG_SIZE) when SelStoreVal = SelStoreValPCHigh  else
                PC(REG_SIZE-1 downto 0)          when SelStoreVal = SelStoreValPCLow   else
                "XXXXXXXX";


    -- connect up the signals to the control unit
    Control: ControlUnit
    port map(
         CLK => clock,
         Reset => Reset,
        --IR     : in opcode_word;
        ProgDB => ProgDB,

        IsInternalAddr => IsInternalAddr,
        InternalAddr => DataAB(REG_SEL_SIZE-1 downto 0),
        
        -- Used for IJMP and ICALL
        -- From Register Array
        InputZ => RegZOut,
        StatRegIn => StatReg,
        ZeroFlag => ZeroFlag,
        RegAVal => OperandA,
       
        -- Register Array (single register access)
        EnableIn => EnableIn,
        SelRegInput => SelRegInput,
        SelIn => SelIn,
        SelA => SelA,
        SelB => SelB,
        
        -- ALU
        ALUOp => ALUOp,
        SelOpA => SelOpA,
        SelOpB => SelOpB,
        ImmOpB  => ImmOpB,
        StatMask => StatMask,
        PropagateZero => PropagateZero,

        -- Register Array (register pair access)
        SelWord => SelWord,
        EnableWord => EnableWord,
        
        -- Data Memory Access Unit
        SelLoadStore => SelLoadStore,
        SelDataAB  => SelDataAB,
        SelStoreVal => SelStoreVal,
        ImmOffset => ImmOffset,
        UseAddrBase => UseAddrBase,
        
        -- Program Memory Access Unit
        ImmProgOffset => ImmProgOffset,
        ProgLoad => ProgLoad,
        SelPCInput => SelPCInput,

        StatusWrite => StatusWrite,

        -- Control Bus
        DataRd => DataRd,
        DataWr => DataWr
    );
        

    -- connect up the signals to the ALU
    ALU_unit: ALU
    port map (
        CLK => clock,

        -- ALU inputs
        ALUOp => ALUOp,
        OperandA => ALUOpA,
        OperandB => ALUOpB,
        StatMask => StatMask,
        PropagateZero => PropagateZero,

        -- ALU outputs
        Result => ALUResult,
        StatOut  => StatReg,
        FlagZero => ZeroFlag
    );


    -- connect up the signals to the register array
    RegArray: RegisterArray
    port map (
        -- Clock signal
        CLK => clock,

        -- Register array read/write control signals
        EnableIn => EnableIn,
        SelIn => SelIn,
        SelA  => SelA,
        SelB => SelB,

        -- Register array input
        RegIn => RegDataIn,

        -- Register array outputs
        RegAOut => OperandA,
        RegBOut => OperandB,
        
        -- Homework 4
        -- Loading and reading XYZ and SP registers independent from other registers.
        RegWordOut => AddrBase,

        -- Homework 5
        RegZOut => RegZOut,
        RegWordIn => AddrTarget,
        SelWord => SelWord,
        EnableWord => EnableWord,
        
        Reset => Reset,

        StatRegIn => StatReg,
        StatusWrite => StatusWrite
    );  
    

    -- connect up the signals to the data memory access unit
    DataMem: DataMemAccess
    port map(
        AddrBase => AddrBase,
        AddrOffset => ImmOffset,
        AddrTarget => AddrTarget,
        
        UseAddrBase => UseAddrBase,
        
        SelLoadStore => SelLoadStore,
		StoreVal => StoreVal,

        IsInternalAddr => IsInternalAddr,
		
        SelDataAB => SelDataAB,
        DataAB => DataAB,
        
        DataDB => DataDB,
        DataWr => DataWr
    );
    

    -- connect up the signals to the program memory access unit
    ProgMem: ProgMemAccess
    port map(
        ImmProgOffset => ImmProgOffset,
        ProgLoad => ProgLoad,
        Clock => clock,
        Reset => Reset,
        DataDB => DataDB,
        SelPCInput => SelPCInput,
        CurrProgAddr => PC,
        ProgAB => ProgAB
     );

end architecture;
