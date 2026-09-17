# Domain: Radio, Electrical Engineering & Circuit Design

Design a software-defined radio (SDR) receiver front-end for the 2-meter amateur band (144-148 MHz). Requirements:

**RF Front-End (Circuit Design):**
1. Bandpass filter: 5th-order Chebyshev, 144-148 MHz, 50Ω impedance, IL ≤ 1dB. Provide component values and Q factor analysis
2. LNA design: using BFU730F, target NF < 1.5dB, gain > 20dB, OIP3 > +20dBm. Provide bias network and stability analysis (Rollett K-factor)
3. Mixer: passive double-balanced using ADE-1, LO drive +7dBm. Compute conversion loss and isolation
4. Image rejection: compute image frequency for IF=10.7 MHz with high-side LO, design Hartley image-reject topology
5. Complete schematic in KiCAD format with BOM including DigiKey part numbers

**Signal Processing (Python):**
1. Implement FM demodulation: polar discriminator with de-emphasis (75μs)
2. CTCSS tone detection: Goertzel algorithm, all 38 standard tones
3. Digital filter: decimate from 2.4 MSPS to 48 kSPS using half-band filters
4. SNR estimation: using M2M4 estimator

**System Analysis:**
1. Link budget: 5W TX, 10km range, compute required receiver sensitivity
2. Noise figure: cascade analysis using Friis formula
3. Dynamic range: compute SFDR, blocking, and reciprocal mixing performance

Deliver: kicad-project/, sdr_receiver.py, link-budget.ods, analysis.md, schematic.pdf (or .kicad_sch)
