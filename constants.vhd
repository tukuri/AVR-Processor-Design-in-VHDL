--------------------------------------------------------------------------------
--
-- Constants
--
-- This package defines various constants for use by the CPU. Constants include 
-- static values, such as BYTE_SIZE and other signal widths, ALU opcodes for 
-- communication between the control unit and ALU, and control unit select 
-- signals.
--
-- Revision History
--     02/04/19    Garret Sullivan    Initial revision
--     02/09/19    Garret Sullivan    Added data memory access constants
--     02/10/19    Garret Sullivan    Added SP to sel_word
--     02/24/19    Garret Sullivan    Added selects for prog mem access
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package constants is

    -- basic constant definitions

    constant BYTE_SIZE             : natural := 8;
    constant WORD_SIZE             : natural := 2*BYTE_SIZE;
    constant REG_SIZE              : natural := BYTE_SIZE;
    constant REG_SEL_SIZE          : natural := 7;
    constant IR_REG_WORD_SEL_SIZE  : natural := 2;
    constant REG_BIT_IDX_SIZE      : natural := 3;
    constant NUM_REGS              : natural := 96;

    constant REG_X_LOW             : natural := 26;
    constant REG_X_HIGH            : natural := 27;
    constant REG_Y_LOW             : natural := 28;
    constant REG_Y_HIGH            : natural := 29;
    constant REG_Z_LOW             : natural := 30;
    constant REG_Z_HIGH            : natural := 31;
    constant REG_SP_LOW            : natural := 93;
    constant REG_SP_HIGH           : natural := 94;
    constant REG_STATUS            : natural := 95;

    constant FLAG_I : natural := 7;
    constant FLAG_T : natural := 6;
    constant FLAG_H : natural := 5;
    constant FLAG_S : natural := 4;
    constant FLAG_V : natural := 3;
    constant FLAG_N : natural := 2;
    constant FLAG_Z : natural := 1;
    constant FLAG_C : natural := 0;
    
    
    -- ALU opcode definitions

    subtype opcode_alu is std_logic_vector(5 downto 0);
   
    -- F-Block instructions (low 4 bits from table)
       
    constant ALUOpSetFBlock : opcode_alu := "00----";
   
    constant ALUOpAND : opcode_alu := "001000"; -- AND
    constant ALUOpNOT : opcode_alu := "000011"; -- NOT
    constant ALUOpXOR : opcode_alu := "000110"; -- XOR
    constant ALUOpOR  : opcode_alu := "001110"; -- OR
   
    -- Add/Sub Block instructions
   
    constant ALUOpSetAddSub : opcode_alu := "010---";
   
    constant ALUOpADD : opcode_alu := "010000"; -- ADC
    constant ALUOpADC : opcode_alu := "010001"; -- ADD
    constant ALUOpSUB : opcode_alu := "010010"; -- SUB
    constant ALUOpSBC : opcode_alu := "010011"; -- SBC
   
    -- Shift/Rotate Block Instructions
   
    constant ALUOpSetShift : opcode_alu := "011---";
   
    constant ALUOpASR : opcode_alu := "011000"; -- ASR
    constant ALUOpLSR : opcode_alu := "011001"; -- LSR
    constant ALUOpROR : opcode_alu := "011010"; -- ROR

    -- Bit Transfer Instructions

    constant ALUOpSetBST : opcode_alu := "100---";
    constant ALUOpSetBLD : opcode_alu := "101---";
   
    constant ALUOpBSTPrefix : std_logic_vector(2 downto 0) := "100";
    constant ALUOpBLDPrefix : std_logic_vector(2 downto 0) := "101";

    -- Other Instructions

    constant ALUOpBCLR : opcode_alu := "110000";
    constant ALUOpBSET : opcode_alu := "110001";
    constant ALUOpSWAP : opcode_alu := "110010";
    constant ALUOpSTAT : opcode_alu := "111011";


    -- ALU select definitions
   
    subtype sel_op_a is std_logic;
   
    constant SelOpARegAOut : sel_op_a := '0';
    constant SelOpA0       : sel_op_a := '1';
   
    subtype sel_op_b is std_logic_vector(1 downto 0);
   
    constant SelOpBRegBOut : sel_op_b := "00";
    constant SelOpBRegAOut : sel_op_b := "01";
    constant SelOpBImm     : sel_op_b := "10";
    
    
    -- Register pair acess definitions    

    subtype sel_word is std_logic_vector(3 downto 0);
    
    constant SelWordNone : sel_word := "0000";
    constant SelWordX    : sel_word := "0001";
    constant SelWordY    : sel_word := "0010";
    constant SelWordZ    : sel_word := "0100";
    constant SelWordSP   : sel_word := "1000";


    -- Data memory access unit select definitions
    
    subtype sel_load_store is std_logic;
    
    constant SelLoad  : sel_load_store := '1';
    constant SelStore : sel_load_store := '0';
    
    subtype sel_data_ab is std_logic;
    
    constant SelDataABBase   : sel_data_ab := '1';
    constant SelDataABTarget : sel_data_ab := '0';


    -- Register input source select definitions
    
    subtype sel_reg_input is std_logic_vector(1 downto 0);
    
    constant SelRegInputDataDB    : sel_reg_input := "00";
    constant SelRegInputImmOpB    : sel_reg_input := "01";
    constant SelRegInputALUResult : sel_reg_input := "10";
    constant SelRegInputRegBOut   : sel_reg_input := "11";


    -- Data memory access store value source definitions

    subtype sel_store_val is std_logic_vector(1 downto 0);

    constant SelStoreValRegAOut : sel_store_val := "11";
    constant SelStoreValPCHigh  : sel_store_val := "10";
    constant SelStoreValPCLow   : sel_store_val := "01";


    -- Program memory access PC input source definitions

    subtype sel_pc_input is std_logic_vector(1 downto 0);

    constant SelPCInputProgAB     : sel_pc_input := "11";
    constant SelPCInputDataDBHigh : sel_pc_input := "10";
    constant SelPCInputDataDBLow  : sel_pc_input := "01";

end package;