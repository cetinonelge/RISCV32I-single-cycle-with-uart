# RV32I Single-Cycle CPU with UART Interface

This project implements a single-cycle processor for the RV32I RISC-V instruction set architecture using Verilog. It includes a fully integrated UART peripheral to allow serial communication with external devices such as PCs or terminals. The system is capable of executing programs loaded into a predefined instruction memory and supports essential RV32I instructions for basic computation, control flow, and memory operations. UART is testable only on FPGA, it is not tested via cocotb. 

## Features

- Single-cycle execution for all instructions
- Full support for base RV32I instruction set
- Memory-mapped UART output
- Register file and ALU implementation
- Instruction and data memory support
- Designed for simulation with cocotb

## Tools Used

- **Verilog HDL**
- **Icarus Verilog** (simulation)
- **Cocotb** (Python-based verification)
