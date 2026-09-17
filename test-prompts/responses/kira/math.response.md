All results verified computationally. Here are the complete solutions.

---

## 1. Arithmetic & Number Theory: 2¹⁰⁰⁰ mod 13

**Fermat's little theorem:** since 13 is prime and gcd(2, 13) = 1,

$$2^{12} \equiv 1 \pmod{13}$$

**Reduce the exponent:** divide 1000 by 12:

$$1000 = 12 \cdot 83 + 4$$

**Compute:**

$$2^{1000} = (2^{12})^{83} \cdot 2^4 \equiv 1^{83} \cdot 16 \equiv 16 \equiv \boxed{3} \pmod{13}$$

---

## 2. Algebra: x² + y² = 25, x + y = 7

Square the linear equation:

$$(x+y)^2 = 49 \implies x^2 + 2xy + y^2 = 49 \implies 25 + 2xy = 49 \implies xy = 12$$

So x and y are roots of the quadratic t² − (x+y)t + xy = 0:

$$t^2 - 7t + 12 = 0 \implies (t-3)(t-4) = 0 \implies t = 3 \text{ or } t = 4$$

**Solutions:** (x, y) = **(3, 4)** and **(4, 3)**.

Both are real — and these are *all* solutions, real or complex: the substitutions above are equivalences over ℂ, and the resulting quadratic has exactly two roots (Bézout's theorem predicts 2·1 = 2 intersection points, counted with multiplicity). So there are no additional complex solutions.

---

## 3. Geometry: Regular dodecahedron, edge a = 2

**Volume.** The standard formula is V = ¼(15 + 7√5)a³. With a = 2, a³ = 8:

$$V = \frac{15 + 7\sqrt{5}}{4}\cdot 8 = \boxed{30 + 14\sqrt{5}}$$

**Angle defect.** Three regular pentagons meet at each vertex; each pentagon's interior angle is 108°, so the face angles sum to 324°:

$$\text{defect per vertex} = 360° - 324° = \boxed{36° = \tfrac{\pi}{5}}$$

A dodecahedron has 20 vertices, so the total defect is 20 × 36° = **720° = 4π**, exactly as Descartes' theorem (total defect = 4π for any convex polyhedron) requires. ✓

**Circumscribed sphere radius.** Formula: R = (a/4)√3(1 + √5). With a = 2:

$$R = \boxed{\frac{\sqrt{3}\,(1 + \sqrt{5})}{2}}$$

---

## 4. Probability: Full house with 5 dice

**Sample space:** 6⁵ = 7776 equally likely outcomes.

**Favorable** (three of one value + two of a different value):
- Choose the triple's value: 6 ways
- Choose the pair's value: 5 ways
- Choose which 3 of the 5 dice show the triple: C(5,3) = 10 ways

$$\text{favorable} = 6 \cdot 5 \cdot 10 = 300$$

$$P = \frac{300}{7776} = \boxed{\frac{25}{648}}$$

(gcd(300, 7776) = 12; 25 = 5² and 648 = 2³·3⁴ are coprime, so the fraction is fully reduced.)

---

## 5. Calculus: Taylor series of ln(1 + x³)

Start from the Mercator series, valid for |u| < 1:

$$\ln(1+u) = u - \frac{u^2}{2} + \frac{u^3}{3} - \frac{u^4}{4} + \cdots$$

Substitute u = x³:

$$\ln(1+x^3) = x^3 - \frac{x^6}{2} + \frac{x^9}{3} - \frac{x^{12}}{4} + O(x^{15})$$

That is, to order x¹²:

$$\ln(1+x^3) = \sum_{k=1}^{4} \frac{(-1)^{k+1}}{k} x^{3k} + O(x^{15})$$

**Radius of convergence:** the series in u converges iff |u| < 1 (singular at u = −1). Since u = x³, we need |x³| < 1, i.e. |x| < 1. The nearest singularity to 0 is at x = −1 (and the complex cube roots of −1), all of modulus 1, so:

$$R = \boxed{1}$$

---

## 6. Linear Algebra: A = [[1,2,3],[4,5,6],[7,8,9]]

**Determinant argument (singularity):**

$$\det A = 1(45-48) - 2(36-42) + 3(32-35) = -3 + 12 - 9 = 0$$

Since det A = 0, A is singular.

**Row-reduction argument:** apply R₂ ← R₂ − 4R₁, R₃ ← R₃ − 7R₁:

$$\begin{pmatrix} 1 & 2 & 3 \\ 0 & -3 & -6 \\ 0 & -6 & -12 \end{pmatrix} \xrightarrow{R_3 \leftarrow R_3 - 2R_2} \begin{pmatrix} 1 & 2 & 3 \\ 0 & -3 & -6 \\ 0 & 0 & 0 \end{pmatrix}$$

Only **2 nonzero rows** remain, so rank(A) = **2** < 3, confirming singularity (rows are linearly dependent: note R₃ = 2R₂ − R₁ in the original matrix, i.e. row 3 + row 1 = 2·row 2).

**Null space:** from row 2: −3y − 6z = 0 ⟹ y = −2z. From row 1: x + 2y + 3z = 0 ⟹ x = 4z − 3z = z. With z free:

$$\ker A = \operatorname{span}\left\{ \begin{pmatrix} 1 \\ -2 \\ 1 \end{pmatrix} \right\}$$

Check: rank 2 + nullity 1 = 3 ✓ (rank–nullity theorem).

---

## 7. Combinatorics: 20 identical balls, 5 distinct boxes, each ≥ 2

Substitute yᵢ = xᵢ − 2 ≥ 0 (pre-place 2 balls in each box). Then:

$$y_1 + y_2 + y_3 + y_4 + y_5 = 20 - 10 = 10, \qquad y_i \ge 0$$

By stars and bars:

$$\binom{10 + 5 - 1}{5 - 1} = \binom{14}{4} = \boxed{1001}$$

---

## 8. Proof: √3 is irrational (two non-standard methods)

The classic proof assumes √3 = p/q in lowest terms and derives 3 | p and 3 | q from p² = 3q². Here are two genuinely different arguments.

**Method 1 — Rational Root Theorem.**
√3 is a root of the monic polynomial x² − 3 ∈ ℤ[x]. By the rational root theorem, any rational root p/q (in lowest terms) of a monic integer polynomial must be an **integer** dividing the constant term 3. The only candidates are ±1, ±3, and:

$$(\pm1)^2 = 1 \ne 3, \qquad (\pm3)^2 = 9 \ne 3$$

So x² − 3 has no rational root. Since √3 is a root, √3 ∉ ℚ. ∎

**Method 2 — Minimal-denominator descent (no divisibility argument).**
Suppose √3 = a/b with a, b positive integers and b the **smallest possible** denominator. Since 1 < √3 < 2, we have b < a < 2b, hence:

$$0 < a - b < b$$

Now form a new fraction from a and b:

$$\frac{3b - a}{a - b} = \frac{3 - \tfrac{a}{b}}{\tfrac{a}{b} - 1} = \frac{3 - \sqrt{3}}{\sqrt{3} - 1} = \frac{\sqrt{3}\,(\sqrt{3} - 1)}{\sqrt{3} - 1} = \sqrt{3}$$

Its numerator 3b − a > b > 0 (since a < 2b) and its denominator a − b is a **positive integer strictly smaller than b**. This contradicts the minimality of b. Hence no such fraction exists and √3 is irrational. ∎

*(This is a geometric-flavored infinite descent — it argues about denominators directly rather than extracting factors of 3 from a parity-style argument.)*

---

**Summary of answers:**

| # | Answer |
|---|--------|
| 1 | 2¹⁰⁰⁰ ≡ **3** (mod 13) |
| 2 | **(3, 4)** and **(4, 3)** — both real, no others |
| 3 | V = **30 + 14√5**; defect **36°/vertex** (720° = 4π total); R = **√3(1+√5)/2** |
| 4 | **25/648** |
| 5 | x³ − x⁶/2 + x⁹/3 − x¹²/4 + O(x¹⁵); R = **1** |
| 6 | rank **2**; ker = span{(1, −2, 1)ᵀ}; det = 0 |
| 7 | **1001** |
| 8 | Proven via rational root theorem & minimal-denominator descent |
