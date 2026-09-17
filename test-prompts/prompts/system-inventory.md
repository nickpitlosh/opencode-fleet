# Domain: System Inventory & Discovery

Write a comprehensive system inventory script that discovers and catalogs everything about a Linux server. Requirements:
1. Hardware: CPU topology, memory banks (with DIMM slots), GPU(s), NVMe/SATA drives (model, serial, wear level), NICs (firmware, link speed), USB devices, PCIe devices with link width/speed
2. Software: Kernel version, loaded modules, systemd services (enabled/failed), installed packages by manager (apt/dpkg/rpm/nix), running containers, cron jobs, systemd timers
3. Network: Interfaces, routes, firewall rules, listening sockets, DNS config, NTP status
4. Security: SELinux/AppArmor status, open ports, SUID files, world-writable files, failed login attempts
5. Output as structured JSON to stdout, with a --format flag for JSON/YAML/Markdown report
6. Implement caching: results cached for 5 minutes by default

Deliver: inventory.sh (self-contained, no external deps beyond standard POSIX + jq)
