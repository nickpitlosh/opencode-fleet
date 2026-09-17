# Domain: Quantum Hydrodynamic Theory

Derive and analyze the Madelung formulation of quantum mechanics as a hydrodynamic system. Requirements:

1. **Derivation**: Starting from the Schrödinger equation, derive the continuity equation and Euler-like equation for the probability current. Show explicitly how the quantum potential Q = -(ℏ²/2m)(∇²√ρ)/√ρ emerges.

2. **Bohmian Trajectories**: For a Gaussian wave packet scattering off a step potential V₀, write the equations of motion for Bohmian particles. Implement a numerical solver in Python (scipy.integrate.solve_ivp).

3. **Quantum Turbulence**: Explain how quantized vortices in superfluid He-4 relate to quantum hydrodynamic theory. Derive the Onsager-Feynman quantization condition ∮vₛ·dl = nℏ/m.

4. **Numerical Simulation**: Implement a split-step Fourier method to solve the 1D Gross-Pitaevskii equation for a Bose-Einstein condensate in a harmonic trap. Include: ground state (imaginary time), dynamics (real time), vortex nucleation via rotation.

5. **Connection to Classical Navier-Stokes**: Derive the classical limit ℏ→0 of the Madelung equations. Identify where quantum effects become negligible (decoherence scale).

Deliver: derivation.md (full equations), quantum_turbulence.md, gpe_solver.py, simulation_results.png (or data), references.md
