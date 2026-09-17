# Domain: IPv6 & Ethernet Frame Kernel Programming

Write a Linux kernel module (eBPF/XDP) that implements a high-performance packet filter. Requirements:

**XDP Program (C, compiled with clang):**
1. Parse Ethernet → IPv6 → TCP/UDP headers with full bounds checking
2. Implement a Bloom filter for known-malicious IPv6 prefixes (/32 and /48)
3. Rate-limit ICMPv6 Neighbor Discovery packets to prevent NDP exhaustion
4. Pass allowed packets to the kernel stack, drop malicious ones at driver level
5. Use BPF_MAP_TYPE_LPM_Trie for prefix matching, BPF_MAP_TYPE_PERCPU_ARRAY for stats

**Userspace Loader (Python with ctypes/libbpf):**
1. Load and attach the XDP program to a network interface
2. Populate the Bloom filter from a configuration file
3. Read statistics via perf event buffer
4. Provide a CLI with: load, unload, list, stats, add-prefix, remove-prefix

**IPv6 Specifics:**
1. Handle extension headers (Hop-by-Hop, Routing, Fragment, AH, ESP, Mobility)
2. Validate flow label field for ECMP routing simulation
3. Implement SEND (SEcure Neighbor Discovery) verification stub

**Testing:**
1. Generate test traffic with scapy: valid packets, malformed headers, extension header chains, rate-limit testing
2. Benchmark: measure packets/second before and after filter attachment

Deliver: xdp_filter.c, loader.py, setup.py, tests/test_traffic.py, Makefile, README.md
