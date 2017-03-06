Statically typed Vector and Matrix algebra
==========================================

:Authors: Jyri-Matti Lähteenmäki
:Date: 2012-01-12

I took a `course on Machine Learning <http://www.ml-class.org/>`__ a
while back, just for fun. `Stanford University <http://stanford.edu/>`__
seems to have really put some effort into free courses in the Internet,
since `Artificial Intelligence <https://www.ai-class.com/>`__ and
`Introduction to Databases <http://www.db-class.org/>`__ were also time
well spent.

The exercises in `Octave <http://www.gnu.org/software/octave/>`__
reminded me of
`Matlab <http://www.mathworks.se/products/matlab/index.html>`__ and the
pain I had to endure while studying in `Tampere University of
Technology <http://www.tut.fi/>`__. It would be so much easier if the
editor actually complained when trying to multiply matrices of
incompatible dimensions etc. Could
`Scala <http://www.scala-lang.org/>`__ perhaps be used to provide some
static type safety to matrix operations?

Well, you guessed it.

Creating a linear algebra library wouldn't be the most exciting project
(well, not this time, anyway...) so I decided to make a thin wrapper for
`Scalala <https://github.com/scalala/Scalala>`__. I was not striving for
a full-featured library, but instead more like a proof-of-concept, so I
only implemented a few operations.

I'm not smart enough to come up with the required type algebra, so I
shamelessly copied the hard parts from
`here <http://apocalisp.wordpress.com/2010/06/08/type-level-programming-in-scala/>`__.
Hopefully some day I'm going to understand all those lines that went
almost unmodified through my clipboard...

`Haskell <http://www.haskell.org/>`__ is another great language and can
provide more or less similar type safety. Since I don't speak Haskell
that well, I'll let you read about a Haskell implementation
`here <https://github.com/leonidas/codeblog/blob/master/2011/2011-12-21-static-vector-algebra.md>`__.

I made my `code available in
GitHub <https://github.com/inferior/scalam>`__. Feel free to use it as
you will. The name *net.lahteenmaki.scalam* is due to my total lack of
imagination, sorry about that.

Here's a demo. First of all, only a single import is needed to use all
the functionality:

.. code:: scala

    scala> import net.lahteenmaki.scalam._
    import net.lahteenmaki.scalam._

Create some regular vectors containing integers:

.. code:: scala

    scala> val v2 = Vector(1,2)
    v2: net.lahteenmaki.scalam.RowVector[Int,D2] = 1  2

    scala> val v3 = Vector(1,2,3)
    v3: net.lahteenmaki.scalam.RowVector[Int,D3] = 1  2  3

or doubles. Actually anything ``scalala.scalar.Scalar[T]``:

.. code:: scala

    scala> Vector(1.0,2.0)
    res1: net.lahteenmaki.scalam.RowVector[Double,D2] = 1.00000   2.00000

Trying to create a vector with differing element types gives a compiler
error:

.. code:: scala

    scala> Vector(1,2.0)
    <console>:11: error: T is not a scalar value
                  Vector(1,2.0)
                        ^

Transposing a row vector creates a column vector of the same dimension:

.. code:: scala

    scala> v2.T
    res3: net.lahteenmaki.scalam.ColumnVector[Int,D2] =1 2

I included some implicits to create vectors from tuples:

.. code:: scala

    scala> (1,2).T
    res4: net.lahteenmaki.scalam.ColumnVector[Int,D2] =1 2

There's nothing special in scalar multiplication, except that the
element types change similar to Scalala:

.. code:: scala

    scala> v2*2
    res5: net.lahteenmaki.scalam.RowVector[Int,D2] = 2  4

    scala> v2*2.0
    res6: net.lahteenmaki.scalam.RowVector[Double,D2] = 2.00000   4.00000

Addition should retain the dimensions and be only allowed to vectors of
the same dimension:

.. code:: scala

    scala> v2 + v2
    res7: net.lahteenmaki.scalam.RowVector[Int,D2] = 2  4

    scala> Vector(1,2) + Vector(1.0,2.0)
    res8: net.lahteenmaki.scalam.RowVector[Double,Succ[Succ[D0]]] = 2.00000   4.00000

    scala> v2 + v3
    <console>:13: error: overloaded method value + with alternatives:
     [B](other: net.lahteenmaki.scalam.RowVector[B,D2])
        (implicit o: v2.BinOp[B,scalala.operators.OpAdd])
        net.lahteenmaki.scalam.RowVector[B,D2]
     <and>
     [B](other: net.lahteenmaki.scalam.Matrix[B,D1,D2])
        (implicit o: v2.BinOp[B,scalala.operators.OpAdd])
        net.lahteenmaki.scalam.Matrix[B,D1,D2]
     cannot be applied to (net.lahteenmaki.scalam.RowVector[Int,D3])
                  v2 + v3
                     ^

Yes, we did get a compile time error. Splendid.

Vector multiplication is also only defined for compatible sizes:

.. code:: scala

    scala> v2 * v2.T
    res10: net.lahteenmaki.scalam.Matrix[Int,D1,D1] = 5

    scala> v2 * v2
    <console>:12: error: Could not find a way to  values of type
    net.lahteenmaki.scalam.RowVector[Int,D2] and scalala.operators.OpMulMatrixBy
                  v2 * v2
                     ^

    scala> v2 * v3
    <console>:13: error: Could not find a way to  values of type
    net.lahteenmaki.scalam.RowVector[Int,D3] and scalala.operators.OpMulMatrixBy
                  v2 * v3
                     ^

Again, the compiler won't let me multiply a row vector with another one.
Nice.

How about concatenating vectors? :

.. code:: scala

    scala> v2 ++ v3
    res13: net.lahteenmaki.scalam.RowVector[Int,Add[D2,D3]] = 1  2  1  2  3

    scala> val v: RowVector[Int,D5] = v2 ++ v3
    v: net.lahteenmaki.scalam.RowVector[Int,D5] = 1  2  1  2  3

    scala> v2 ++ v2.T
    <console>:12: error: type mismatch;
     found   : net.lahteenmaki.scalam.ColumnVector[Int,D2]
     required: net.lahteenmaki.scalam.Matrix[Int,D1,?]
                  v2 ++ v2.T
                           ^

The compiler can deduce the dimension of the result, and won't let me
concatenate a row vector with a column vector. Just what I wanted.

Then the classic over-indexing case:

.. code:: scala

    scala> v2[D1]
    res15: Int = 1

    scala> v2[D2]
    res16: Int = 2

    scala> v2[D3]
    <console>:12: error: Cannot prove that
    D3#Compare[D2]#Match[True,True,False,Bool] =:= True.
                  v2[D3]
                    ^

Spectacular. The compiler won't let me get an element n+1 from an
n-dimensional vector.

Same operations can be implemented for matrices, as well as some helper
methods for constructing simple matrices:

.. code:: scala

    scala> val m22 = Matrix.ones[Int,D2]
    m22: net.lahteenmaki.scalam.Matrix[Int,D2,D2] =
    1  1
    1  1

    scala> val m23 = Matrix.ones[Int,D2,D3]
    m23: net.lahteenmaki.scalam.Matrix[Int,D2,D3] =
    1  1  1
    1  1  1

    scala> Matrix.zeros[Double,D2]
    res18: net.lahteenmaki.scalam.Matrix[Double,D2,D2] =
     0.00000   0.00000
     0.00000   0.00000

    scala> Matrix.rand[D5,D5]
    res19: net.lahteenmaki.scalam.Matrix[Int,D5,D5] =
    8   6   10  2   2  
    3   2   11  1   15
    10  1   18  9   5  
    11  5   8   10  18
    0   17  2   12  24

    scala> m22.T
    res20: net.lahteenmaki.scalam.Matrix[Int,D2,D2] =
    1  1
    1  1

    scala> m22 + m22
    res21: net.lahteenmaki.scalam.Matrix[Int,D2,D2] =
    2  2
    2  2

    scala> m22 + m23
    <console>:13: error: type mismatch; 
    found   : net.lahteenmaki.scalam.Matrix[Int,D2,D3] 
    required: net.lahteenmaki.scalam.Matrix[?,D2,D2]
                  m22 + m23
                        ^

    scala> m22 * 5.5
    res23: net.lahteenmaki.scalam.Matrix[Double,D2,D2] =
     5.50000   5.50000
     5.50000   5.50000

    scala> m22 * m23
    res24: net.lahteenmaki.scalam.Matrix[Int,D2,D3] =
    2  2  2
    2  2  2

    scala> m22 * v2
    <console>:13: error: Could not find a way to  values of type
     net.lahteenmaki.scalam.RowVector[Int,D2] and scalala.operators.OpMulMatrixBy
                  m22 * v2
                     ^

    scala> v3 * Matrix.rand[D1,D5]
    <console>:12: error: Could not find a way to  values of type
     net.lahteenmaki.scalam.Matrix[Int,D1,D5] and scalala.operators.OpMulMatrixBy
                  v3 * Matrix.rand[D1,D5]
                    ^

    scala> m23 * m22
    <console>:13: error: Could not find a way to  values of type
     net.lahteenmaki.scalam.Matrix[Int,D2,D2] and scalala.operators.OpMulMatrixBy
                  m23 * m22
                     ^

    scala> m23[D1,D1]
    res28: Int = 1

    scala> m23[D2,D3]
    res29: Int = 1

    scala> m23[D3,D3]
    <console>:12: error: Cannot prove that
     D3#Compare[D2]#Match[True,True,False,Bool] =:= True.
                  m23[D3,D3]
                     ^

Everything is working for small vectors and matrices, but how about
bigger ones? I actually only declared dimensions from D1 to D22, but one
could always declare more, probably generate them:

.. code:: scala

    scala> val v7 = Vector(1,2,3,4,5,6,7)
    v7: net.lahteenmaki.scalam.RowVector[Int,D7] = 1  2  3  4  5  6  7

    scala> val v21 = v7 ++ v7 ++ v7
    v21: net.lahteenmaki.scalam.RowVector[Int,Add[Add[D7,D7],D7]] =
     1  2  3  4  5  6  7  1  2  3  4  5  6  7  1  2  3  4  5  6  7

    scala> val v23 = v21 ++ Vector(22,23)
    v23: net.lahteenmaki.scalam.RowVector[Int,Add[Add[Add[D7,D7],D7],D2]] =
     1  2  3  4  5  6  7  1  2  3  4  5  6  7  1  2  3  4  5  6  7  22  23

    scala> v23[D23]
    <console>:14: error: not found: type D23
                  v23[D23]
                      ^
    <console>:14: error: Cannot prove that
     (Add[Add[Add[D7,D7],D7],D2],)#Match[True,True,False,Bool] =:= True.
                  v23[D23]
                     ^

    scala> type D23 = Succ[D22]
    defined type alias D23

    scala> v23[D23]
    res32: Int = 23

So, this is nice. Almost too good to be true?

There are some issues, of course. You probably noticed already in the
beginning that the produced error messages aren't exactly helpful for an
average programmer. This *might* be improved if Scala introduced more
features like ``@implicitNotFound`` that could be used to provide the
compiler with custom error messages.

Also, in cases where the dimension changes, the compiler cannot deduce
the resulting dimension, but instead gives out the cryptic
``Add[Add[...]]`` signatures which need to be manually casted to
"readable" signatures, if needed. This might be just an issue with my
implementation, though, I don't know.

Perhaps the biggest problem might turn out to be performance. Compiling
Scala is already a heavy job, and handling types for a 10000x10000
matrix might just be beyond any possible compiler optimizations.
