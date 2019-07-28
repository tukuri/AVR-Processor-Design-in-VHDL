# AVR-CPU-Design-in-VHDL

Designed and implemented an 8-bit Harvard Architecture CPU that is able to perform most of the operations (including multi-cycle operations) of AVR instruction set.
The control unit contains a state machine to decode the instructions that take different number of cycles.
The files that end with "TB" are testbenches while others are design files. The testbenches use VHDL assertions for testing.
ALU_TB is the testbench for ALU, MEM_TB is the testbench for the memory unit, and CPU_TB is the testbench for the entire CPU.
After completing the entire CPU, we wrote a AVR Assembly test code and ran a supplied program that strips necessary information from the .LST file so that 
we could use it for the VHDL testbench. The entire design was tested by running all of the implemented instructions on it.
