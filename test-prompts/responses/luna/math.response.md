1. **Arithmetic & Number Theory**

By Fermat’s little theorem, since \(13\nmid 2\),

\[
2^{12}\equiv 1\pmod{13}.
\]

Reduce the exponent:

\[
1000=12\cdot 83+4.
\]

Therefore,

\[
2^{1000}=2^{12\cdot 83+4}
\equiv (2^{12})^{83}2^4
\equiv 1^{83}\cdot 16
\equiv 3\pmod{13}.
\]

\[
\boxed{2^{1000}\equiv 3\pmod{13}}
\]

2. **Algebra**

From \(x+y=7\),

\[
y=7-x.
\]

Substitute into \(x^2+y^2=25\):

\[
x^2+(7-x)^2=25,
\]

\[
2x^2-14x+49=25,
\]

\[
2x^2-14x+24=0,
\]

\[
x^2-7x+12=0,
\]

\[
(x-3)(x-4)=0.
\]

Thus \(x=3\) or \(x=4\). Correspondingly,

\[
\boxed{(x,y)=(3,4),(4,3)}.
\]

These are all the real solutions. Since the resulting quadratic has only these two roots, they are also all the complex solutions.

3. **Geometry**

For a regular dodecahedron with edge length \(a\):

\[
V=\frac{15+7\sqrt5}{4}a^3.
\]

With \(a=2\),

\[
V=\frac{15+7\sqrt5}{4}(8)
=\boxed{30+14\sqrt5}.
\]

Each vertex has three regular pentagons. A pentagon’s interior angle is

\[
\frac{(5-2)180^\circ}{5}=108^\circ.
\]

Thus the angle defect at each vertex is

\[
360^\circ-3(108^\circ)=36^\circ=\boxed{\frac{\pi}{5}}.
\]

There are \(20\) vertices, so the total defect is

\[
20\cdot \frac{\pi}{5}=\boxed{4\pi}.
\]

The circumsphere radius is

\[
R=\frac{a}{2}\sqrt3(1+\sqrt5).
\]

For \(a=2\),

\[
\boxed{R=\sqrt3(1+\sqrt5)}.
\]

4. **Probability**

A full house consists of three dice showing one value and two dice showing another.

Total outcomes:

\[
6^5=7776.
\]

Favorable outcomes:

- Choose the value occurring three times: \(6\) ways.
- Choose the value occurring twice: \(5\) ways.
- Choose which three positions contain the triple: \(\binom53=10\) ways.

Thus

\[
P=\frac{6\cdot5\cdot10}{6^5}
=\frac{300}{7776}
=\boxed{\frac{25}{648}}.
\]

5. **Calculus**

Using

\[
\ln(1+u)=u-\frac{u^2}{2}+\frac{u^3}{3}-\frac{u^4}{4}+\cdots,
\]

with \(u=x^3\),

\[
\ln(1+x^3)
=x^3-\frac{x^6}{2}+\frac{x^9}{3}-\frac{x^{12}}{4}+\cdots.
\]

Therefore, through order \(x^{12}\),

\[
\boxed{\ln(1+x^3)
=x^3-\frac{x^6}{2}+\frac{x^9}{3}-\frac{x^{12}}{4}+O(x^{15})}.
\]

The series converges when

\[
|x^3|<1,
\]

so

\[
\boxed{R=1}.
\]

6. **Linear Algebra**

\[
A=
\begin{pmatrix}
1&2&3\\
4&5&6\\
7&8&9
\end{pmatrix}.
\]

Row-reduce:

\[
\begin{pmatrix}
1&2&3\\
4&5&6\\
7&8&9
\end{pmatrix}
\to
\begin{pmatrix}
1&2&3\\
0&-3&-6\\
0&-6&-12
\end{pmatrix}
\to
\begin{pmatrix}
1&2&3\\
0&-3&-6\\
0&0&0
\end{pmatrix}.
\]

There are two pivots, so

\[
\boxed{\operatorname{rank}(A)=2}.
\]

To find the null space, solve

\[
x+2y+3z=0,\qquad -3y-6z=0.
\]

The second equation gives \(y=-2z\). Substituting into the first:

\[
x-4z+3z=0 \implies x=z.
\]

Let \(z=t\). Then

\[
(x,y,z)=t(1,-2,1).
\]

Thus

\[
\boxed{\operatorname{Null}(A)=\operatorname{span}\{(1,-2,1)\}}.
\]

The determinant is

\[
\det(A)
=1(45-48)-2(36-42)+3(32-35)
=-3+12-9=0.
\]

Hence \(A\) is singular. Row reduction also produces a zero row, showing that the rows are linearly dependent and confirming singularity.

7. **Combinatorics**

Let \(x_i\) be the number of balls in box \(i\), with

\[
x_1+x_2+x_3+x_4+x_5=20,\qquad x_i\ge2.
\]

Set

\[
y_i=x_i-2.
\]

Then \(y_i\ge0\) and

\[
y_1+y_2+y_3+y_4+y_5=20-10=10.
\]

By stars and bars, the number of solutions is

\[
\binom{10+5-1}{5-1}
=\binom{14}{4}
=\boxed{1001}.
\]

8. **Proof that \(\sqrt3\) is irrational**

Assume, for contradiction, that

\[
\sqrt3=\frac pq
\]

for integers \(p,q\) with \(q\ne0\) and \(\gcd(p,q)=1\). Squaring gives

\[
p^2=3q^2.
\]

Consider the exponent of the prime \(3\) in each side.

- In \(p^2\), every prime exponent is even.
- In \(3q^2\), the exponent of \(3\) is \(1+2k\), which is odd.

Thus the same integer \(p^2=3q^2\) would have both an even and an odd exponent of \(3\), which is impossible by unique prime factorization.

Therefore,

\[
\boxed{\sqrt3\text{ is irrational}}.
\]
