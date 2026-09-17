# Domain: Documentation of Complex Systems

Write comprehensive technical documentation for a distributed key-value store (similar to etcd/Raft). Requirements:
1. Architecture Overview: consensus protocol, data flow, failure modes
2. API Reference: all RPC methods with request/response protobuf schemas
3. Deployment Guide: single-node dev, multi-node prod, Kubernetes operator
4. Operations Runbook: backup/restore, rolling upgrade, member replacement, disk full handling
5. Performance Tuning: latency vs durability trade-offs, snapshot tuning, compaction strategies
6. Security: TLS setup, RBAC policies, audit logging, network policies
7. Include Mermaid diagrams for: consensus state machine, data replication flow, deployment topology
8. Use Diátaxis framework: tutorials, how-to guides, explanation, reference

Deliver: docs/ directory with at least 8 markdown files, diagrams, and a mkdocs.yml
