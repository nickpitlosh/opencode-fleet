# Domain: Mechanical Engineering

Perform a complete thermal and structural analysis of a heat sink for a 150W TDP CPU. Requirements:
1. Calculate required thermal resistance given: T_junction_max=100°C, T_ambient=35°C, TIM resistance=0.1 cm²·°C/W
2. Design a pin-fin heat sink: determine optimal pin diameter, height, and spacing using correlations (e.g., Elsayed-Elshafei for staggered arrays)
3. Perform CFD simulation setup: generate a OpenFOAM case directory with all required files (blockMeshDict, controlDict, fvSchemes, fvSolution, thermophysicalProperties)
4. Calculate natural convection Nusselt number using Churchill-Chu correlation
5. Estimate weight and material cost for aluminum 6061-T6 vs copper C11000
6. Provide a FreeCAD Python script that generates the 3D model parametrically

Deliver: analysis.pdf (or markdown with equations), heat_sink_openfoam/, freecad_script.py, BOM.csv
