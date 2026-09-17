# Test Prompt Domains

## Overview

16 domains covering systems knowledge, programming, engineering, and theoretical disciplines.
Each prompt requires the agent to produce deliverables across the full complexity spectrum.

## Domain List

| # | Domain ID | Full Name | Key Skills Tested |
|---|-----------|-----------|-------------------|
| 1 | web-frontend | Web Frontend | HTML5 semantics, CSS architecture, vanilla JS, OT algorithms, real-time sync |
| 2 | assembly | Assembly Programming | x86-64, memory management, suffix arrays, algorithm optimization |
| 3 | fpga | FPGA Design | SystemVerilog, RISC-V pipeline, branch prediction, testbenches |
| 4 | system-inventory | System Inventory | Hardware discovery, software cataloging, security auditing, reporting |
| 5 | mechanical | Mechanical Engineering | Thermal analysis, CFD, OpenFOAD, heat sink design, parametric CAD |
| 6 | documentation | System Documentation | Technical writing, Diátaxis framework, Mermaid diagrams, API docs |
| 7 | test-programming | Test Engineering | Contract testing, parallel execution, mutation testing, CI/CD |
| 8 | gui-design | GUI/UX Design | Accessibility, design systems, WCAG compliance, medical interfaces |
| 9 | directory-services | Directory Services | AD/LDAP architecture, partitioning, replication, GPO, Samba |
| 10 | network-kernel | Network Kernel Programming | eBPF/XDP, IPv6 parsing, packet filtering, Bloom filters |
| 11 | ui-psychology | UI Psychology & Zeitgeist | Cognitive psychology, decision theory, content moderation design |
| 12 | math | Mathematics | Number theory, geometry, combinatorics, proofs, linear algebra |
| 13 | distro-management | Distribution Management | PKGBUILD, ebuild, debian packaging, Nix flakes, reproducible builds |
| 14 | radio-ee | Radio & Electrical Engineering | RF design, filter/LNA/mixer topology, SDR signal processing |
| 15 | quantum-hydro | Quantum Hydrodynamic Theory | Madelung equations, Bohmian trajectories, Gross-Pitaevskii, BEC |
| 16 | quantum-computing | Quantum Computing | Qiskit, Grover, QEC, VQE, QFT, resource estimation |

## Evaluation Metrics

| Metric | Description | Scale |
|--------|-------------|-------|
| **size_bytes** | Response size in bytes | 0–∞ |
| **word_count** | Total word count | 0–∞ |
| **line_count** | Total lines | 0–∞ |
| **fkgl** | Flesch-Kincaid Grade Level | 0–20+ |
| **commands** | Number of commands/code blocks detected | 0–∞ |
| **unique_words** | Count of unique words (4+ chars) | 0–∞ |
| **errors** | Estimated error markers (exceptions, tracebacks) | 0–∞ |
| **parallelism** | Mentions of parallel/concurrent patterns | 0–10 |
| **adherence** | How well deliverables match prompt requirements | 0–10 |
| **functionality** | Heuristic score for code structure & completeness | 0–10 |
| **cost_usd** | Estimated API cost (~$0.003/1K tokens) | $0–∞ |
| **composite_score** | func×3 + adh×2 + par×1.5 - err×0.5 | 0–90 |

## Academic Hierarchy (24 Divisions)

| Range | Title |
|-------|-------|
| 0.0–3.75 | Unclassified |
| 3.75–7.50 | Novice |
| 7.50–11.25 | Apprentice |
| 11.25–15.00 | Student |
| 15.00–18.75 | Pupil |
| 18.75–22.50 | Acolyte |
| 22.50–26.25 | Candidate |
| 26.25–30.00 | Associate |
| 30.00–33.75 | Journeyman |
| 33.75–37.50 | Practitioner |
| 37.50–41.25 | Bachelor |
| 41.25–45.00 | Bachelor of Science |
| 45.00–48.75 | Bachelor of Arts |
| 48.75–52.50 | Master |
| 52.50–56.25 | Master of Science |
| 56.25–60.00 | Master of Arts |
| 60.00–63.75 | Master of Philosophy |
| 63.75–67.50 | Licentiate |
| 67.50–71.25 | Senior Practitioner |
| 71.25–75.00 | Expert |
| 75.00–78.75 | Professor |
| 78.75–82.50 | Distinguished Professor |
| 82.50–86.25 | Doctor of Science |
| 86.25–90.00 | Doctor of Philosophy |

## Running

```bash
# Run full gauntlet (all 28 agents × 16 domains = 448 prompts)
./test-prompts/scripts/gauntlet.sh

# Run subset
./test-prompts/scripts/gauntlet.sh --agents stacy,luna,kira --domains math,web-frontend

# Evaluate results
./test-prompts/scripts/evaluate.sh

# Rank agents
./test-prompts/scripts/rank.sh
```
