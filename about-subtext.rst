About Subtext
=============

:Abstract: Some thoughts related to Subtext.
:Authors: Jyri-Matti Lähteenmäki
:Date: 2016-01-04
:Status: Published

I watch a video, which I highly recommend to everyone:

https://vimeo.com/140738254

I decided to write some thoughts on three issues discussed in the video.

1. Program logic as text versus table
2. Fibonacci and readability/editability
3. Melee example and maintainability

Let me emphasize that I really liked the video and I agree with most of
the things in there. The visualized ability to restrict function
argument was especially interesting.

Program logic as text versus table
----------------------------------

I wrote the code in Haskell just to get some feeling out of it. :

.. code:: haskell

    -- If I forget a case:
    -- warning| Pattern match(es) are non-exhaustive...
    -- Like the red column in the table.
    foo1 :: Bool -> Bool -> Bool -> Int
    foo1 a b c
       | a         = 1
       | b || c    = 2
    -- | otherwise = 3

    -- Original working solution.
    foo2 :: Bool -> Bool -> Bool -> Int
    foo2 a b c
     | a         = 1
     | b || c    = 2
     | otherwise = 3

    -- The problem:
    -- add b && c -> 3

    -- First try. Carelessly slipped it to the end.
    -- No warning for overlap, probably since the guard is a runtime check?
    foo3 :: Bool -> Bool -> Bool -> Int
    foo3 a b c
     | a         = 1
     | b || c    = 2
     | otherwise = 3
     | b && c    = 3

    -- If written without guards:
    -- warning| Pattern match(es) are overlapped...
    -- Like the conflict in the table.
    foo4 :: Bool -> Bool -> Bool -> Int
    foo4 True _    _    = 1
    foo4 _    True _    = 2
    foo4 _    _    True = 2
    foo4 _    _    _    = 3
    foo4 _    True True = 3

    -- So, gotta think what we actually wanted to do.
    -- The right place is probably as the first rule:

    foo5 :: Bool -> Bool -> Bool -> Int
    foo5 _    True True = 3
    foo5 True _    _    = 1
    foo5 _    True _    = 2
    foo5 _    _    True = 2
    foo5 _    _    _    = 3

So, no need for a table... but there's some code duplication. Could do
with guards, but since dynamic, the compiler could not refactor the
expression like the semantic table did in the video. I guess the
compiler could refactor the code to use guards, but it would lose the
knowledge of the patterns.

If Haskell had syntax like the following, I guess it could work.
Something like this `has been
proposed <http://wiki.haskell.org/MultiCase>`__. The compiler could warn
about incomplete/overlapping patterns. The compiler would "know" about
the logic and thus could refactor the expressions:

.. code:: haskell

    foo6 :: Bool -> Bool -> Bool -> Int
    foo6 _    True True = 3
    foo6 True _    _    = 1
    foo6 _    True _
       | _    _    True = 2
    foo6 _    _    _    = 3

So, I don't think it's about "semantic tables" but just a language
feature.

Fibonacci and readability/editability
-------------------------------------

.. code:: haskell

    -- IMHO this is more readable than a table.
    fib :: Int -> Int
    fib 0 = 0
    fib 1 = 1
    fib n | n >= 2 = fib (n-1) + fib (n-2)

The assertion for the natural number could even be lifted to type level,
even though it is for some reason stated in the video that it's not a
type but an assertion. I don't know what the author means by that since
they are all "just assertions" in the end...

.. code:: haskell

    type Nat = Int -- well, something else here...
    fib2 :: Nat -> Nat
    fib2 0 = 0
    fib2 1 = 1
    fib2 n = fib2 (n-1) + fib2 (n-2)

The compiler can offer various suggestions on what is applicable and
where. Taken further, for example in Agda, the compiler can even output
placeholders where the programmer inserts suitable values. Pretty much
like to the table.

So, I don't think it's about "semantic tables" but just a language
feature.

Melee example and maintainability
---------------------------------

.. code:: haskell

    -- here's one possible implementation.

    data Attack = Magic | Melee
    data Surprise = Surprise | NoSurprise

    power Magic = 5
    power Melee = 4

    effectiveness Surprise   attack = power attack * 3
    effectiveness NoSurprise attack = power attack * 2

    damage :: (Fractional a, Ord a) => Attack -> Surprise -> a -> a
    damage attack@Magic surprise defense
      | eff >= defense = eff - defense
      | otherwise      = 0
      where eff = effectiveness surprise attack
    damage attack@Melee surprise defense = (eff / defense) * 2
      where eff = effectiveness surprise attack

The concepts of *power and effectiveness* can be separated from damage,
so the problem might not be as big as the video hinted. But, as the
video said, text is linear by nature. It would be awesome to be able to
interactively restrict function arguments to dim out expressions that
are never executed.

Visualizing the execution flow is something I actually don't like. I'm a
functional programmer and I try to think *in space* and not *in time*. I
think declaratively, I usually don't care how the code executes.

So, I don't think it's about "semantic tables" but just a language
feature.

To summarise
------------

Since GHC represents code as a syntax tree, it could surely

1. print out a table representation of the code, right?
2. provide an editable table to edit the expressions, right?
3. visualize the code execution in that table, right?

So, again, I don't think it's about semantic tables, but just another
tool to interact with the code.

I like a text editor, but I certainly agree that we should be editing a
syntax tree instead of a plain-text-representation of it.

How about creating a text editor, that only allows one to write
expressions that form a valid syntax tree in the places where they are
written?
