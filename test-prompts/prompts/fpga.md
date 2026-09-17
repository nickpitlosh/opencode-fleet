# Domain: FPGA Programming (Verilog/VHDL)

Design a pipelined RISC-V RV32I processor core in SystemVerilog. Requirements:
1. 5-stage pipeline: IF, ID, EX, MEM, WB
2. Full forwarding unit and hazard detection
3. Implement the complete RV32I ISA (all 47 instructions)
4. Add a simple branch predictor (2-bit saturating counter)
5. Provide a testbench with at least 10 assembly test programs targeting corner cases
6. Include a constraints file for Xilinx Artix-7 (xc7a35t)
7. Document: pipeline diagram, resource utilization estimate, max frequency analysis

Deliver: core.sv, alu.sv, control.sv, forwarding.sv, predictor.sv, tb.sv, tests/*.asm, constraints.xdc, docs.md
