## 1. Arithmetic & Number Theory — 2^1000 mod 13

By Fermat's little theorem, since 13 is prime and gcd(2,13)=1: `2^12 ≡ 1 (mod 13)`.

Reduce the exponent: `1000 = 12·83 + 4`, so
`2^1000 = (2^12)^83 · 2^4 ≡ 1^83 · 2^4 ≡ 16 ≡ 3 (mod 13)`.

**Answer: 3**

## 2. Algebra — system

`x + y = 7 → y = 7 − x`. Substitute:
`x² + (7−x)² = 25` → `x² + 49 − 14x + x² = 25` → `2x² − 14x + 24 = 0` → `x² − 7x + 12 = 0` → `(x−3)(x−4) = 0`.

**Answer: (x, y) = (3,4) and (4,3).** The system reduces to a quadratic with real discriminant, so these are all solutions — there are **no complex solutions** (a line meets a circle in at most 2 points).

## 3. Geometry — dodecahedron, edge a = 2

Let a = 2.
- **Volume**: `V = (15+7√5)/4 · a³ = (15+7√5)/4 · 8 = 30 + 14√5`.
- **Angle defect**: 3 regular pentagons meet per vertex, each interior angle 108°. Defect per vertex = `360° − 3(108°) = 36°`. Over 20 vertices: `20 · 36° = 720°`, matching Descartes' total-defect theorem.
- **Circumradius**: `R = √3/4 · (1+√5) · a = √3/4 · (1+√5) · 2 = (√3/2)(1+√5)`.

**Answers:** V = `30 + 14√5`; defect = `36°`/vertex (720° total); R = `(√3/2)(1+√5)`.

## 4. Probability — full house in 5 dice

Total outcomes: `6^5`. Pick the triple value (6 ways), the pair value (5 ways), and the arrangement: `5!/(3!·2!) = 10`.

`P = (6·5·10)/6^5 = 300/7776`. Reduce by gcd 12: **`25/648`** (strict 3-of-a-kind + pair definition).

## 5. Calculus — Taylor series of ln(1+x³)

Substitute u = x³ into `ln(1+u) = u − u²/2 + u³/3 − u⁴/4 + …`:

`ln(1+x³) = x³ − x⁶/2 + x⁹/3 − x¹²/4 + …`

Radius of convergence: singularities at `1+x³=0`, i.e. x ∈ {−1, e^{iπ/3}, e^{i5π/3}}, all at distance 1. Since `|x³|<1 ⟺ |x|<1`, **R = 1**.

## 6. Linear Algebra

**Row reduction**: `R2−4R1 → [0,−3,−6]`, `R3−7R1 → [0,−6,−12]`. Since row 3 = 2·row 2, we get a zero row → **rank = 2**.

**Determinant**: `1(45−48) − 2(36−42) + 3(32−35) = −3 + 12 − 9 = 0` → singular.

**Null space**: from `x+2y+3z=0`, `−3y−6z=0` → `y = −2z`, `x = z`. So N(A) = `span{(1, −2, 1)}`, dim 1 = 3 − rank. ✓

**Why singular**: both arguments — det = 0, and row reduction produces a zero row (not full rank).

## 7. Combinatorics

Give each box 2 balls (10 used), leaving 10 balls into 5 boxes: stars-and-bars `C(10+5−1, 5−1) = C(14,4) = 1001`.

**Answer: 1001**

## 8. Proof — √3 irrational (non-standard method)

Use the **Rational Root Theorem**. √3 is a root of the monic integer polynomial `x² − 3 = 0`. Any rational root of a monic polynomial with integer coefficients must be an integer dividing 3, i.e. ∈ {±1, ±3}. But `(±1)² = 1 ≠ 3` and `(±3)² = 9 ≠ 3`. Hence x² − 3 has no rational root, so √3 is irrational. ∎

(Alternative distinct argument: if √3 = p/q in lowest terms, then p² = 3q²; the prime exponent of 3 is even on the left but odd on the right — contradicting unique prime factorization.)
