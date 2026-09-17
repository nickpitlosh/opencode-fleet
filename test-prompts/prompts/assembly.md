# Domain: Assembly Programming

Write a complete x86-64 NASM program for Linux that implements a memory-efficient suffix array construction algorithm. Requirements:
1. Use the DC3/skew algorithm with O(n) time complexity
2. Implement custom memory allocation using mmap/munmap (no libc malloc)
3. Read input from stdin, write suffix array to stdout as binary
4. Include a Python reference implementation for verification
5. Optimize for cache locality: document your cache miss rate assumptions
6. Provide a Makefile with `make`, `make test`, `make bench` targets
7. Handle input sizes up to 100MB within 512MB RAM constraint

Deliver: suffix_array.asm, reference.py, Makefile, README with complexity analysis
