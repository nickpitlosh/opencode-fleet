# Domain: Quantum Computing

Implement a comprehensive quantum computing demonstration using Qiskit. Requirements:

1. **Grover's Algorithm**: Implement Grover search for a 4-qubit database. Build the oracle for finding |1011⟩, implement the diffusion operator, and determine optimal iteration count. Show statevector at each stage.

2. **Quantum Error Correction**: Implement the [[7,1,3]] Steane code. Encode a logical |+⟩ state, inject a bit-flip error on qubit 3, perform syndrome measurement, and correct. Show the full circuit.

3. **Variational Quantum Eigensolver (VQE)**: Find the ground state energy of H₂ molecule using STO-3G basis. Implement UCCSD ansatz, use COBYLA optimizer, and compare with exact diagonalization.

4. **Quantum Fourier Transform**: Build a 5-qubit QFT circuit from gates. Apply to |00101⟩ and verify output matches mathematical expectation. Compute gate count and depth.

5. **Resource Estimation**: For Shor's algorithm factoring 15, estimate: total qubits (logical), T-gate count, circuit depth, and physical qubits needed with surface code (d=15, physical error rate 10⁻³).

Deliver: grover.py, steane_qec.py, vqe_h2.py, qft.py, resource_estimation.md, README.md
