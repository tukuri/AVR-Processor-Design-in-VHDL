# AVR-CPU-Design-in-VHDL

Designed and implemented an 8-bit Harvard Architecture CPU that is able to perform most of the operations (including multi-cycle operations) of AVR instruction set and also meets the specifications(such as number of cycles for each operation) of AVR instruction set.

The control unit contains a state machine to decode the instructions that take different number of cycles.
While most of ALU instructions take single cycle, most of Load/Store and PUSH/POP instructions take 2 cycles.
Branch instructions such as JMP, CALL, RET take 3 or 4 cycles since while the size of program addresses is a word(16-bits), the CPU can load/store only 8 bits at a time. They need to complete updating the Stack Pointers as well.
Skip instructions such as CPSE, SBRC, SBRS take different number of cycles depending on the size of instruction that is to be skipped. For example, if the instruction to be skipped is a two-word instruction instead of a one-word instruction, then the skip instruction takes one extra cycle since the program counter(PC) has to increment one more time.
      
The files that end with "TB" are testbenches while others are design files. The testbenches use VHDL assertions for testing.
ALU_TB is the testbench for ALU, MEM_TB is the testbench for the memory unit, and CPU_TB is the testbench for the entire CPU.
After completing the entire CPU, we wrote a AVR Assembly test code and ran a supplied program that strips necessary information from the .LST file so that we could use it for the VHDL testbench. The entire design was tested by running all of the implemented instructions on it.
