# AVR-Processor-Design-in-VHDL

Designed and implemented an 8-bit CPU for Atmel AVR microcontroller, which is able to perform most of the instructions (including multi-cycle instructions) on the AVR instruction set and also meets the specifications of the AVR instruction set. Program memory access units, Data memory access units, program memory, and data memory were also implemented. Note that the Atmel AVR is an 8-bit RISC Harvard architecture microcontroller.

The control unit contains a state machine to decode the instructions that take different number of cycles.
While *most* of ALU instructions take single cycle, most of Load/Store and PUSH/POP instructions take 2 cycles.
Branch instructions such as JMP, CALL, RET take 3 or 4 cycles since while the size of program addresses is a word(16-bits), the CPU can load/store only 8 bits at a time. These branch instructions perform updating the Stack Pointers as well.
Skip instructions such as CPSE, SBRC, SBRS take different number of cycles depending on the size of instruction that is to be skipped. For example, if the instruction to be skipped is a two-word instruction instead of a one-word instruction, then the skip instruction takes one extra cycle since the program counter(PC) has to increment one more time.

The CPU also supports memory mapping of registers and I/O ports into the data memory space.
Reads and writes to the registers(addresses 0 to 31) and I/O ports(addresses 32 to 95) are redirected to internal registers, not to the external data memory bus.

The files that end with "TB" are testbenches while others are design files. The testbenches use VHDL assertions for testing.
ALU_TEST_TB is the testbench for ALU, MEM_TEST_TB is the testbench for the memory unit, and AVR_CPU_TB is the testbench for the entire CPU.
After completing the entire CPU, we wrote a AVR Assembly test code(testcode_asm) and ran a supplied program that strips necessary information from the .LST file so that we could use it for the VHDL testbench. The entire design was tested by running all of the implemented instructions on it.

**Note that the processor's block diagram below is not the final version of the actually implemented CPU. Several changes (such as routing) have been made to the design after drawing this block diagram.**

![CPU_Design](https://user-images.githubusercontent.com/44155516/62416274-4cfbf200-b5ec-11e9-9a24-65645394e837.jpg)
