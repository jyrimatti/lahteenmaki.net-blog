Monads and comonads are just alternative solutions to a problem
========================

:Abstract: Monads are only about function composition. Comonads are only about function composition. They are just tools for solving problems relates to composing functions, nothing magical.
:Authors: Jyri-Matti Lähteenmäki
:Status: Draft
:Date: 2018-??-??

This blog post consists of two parts:
1) Monads and Comonads are just about composing funny looking functions.
2) Monads and Comonads are just (often interchangeable) tools for solving specific problems.

Disclaimer:
Yes, I realize this is a monad tutorial.
I'm aware that I may be suffering from the Monad tutorial fallacy (https://byorgey.wordpress.com/2009/01/12/abstraction-intuition-and-the-monad-tutorial-fallacy/).
I'm aware that I might actually not understand monads at all.
Please forgive me if I'm completely missing every possibly point ever made.
I beg you to correct my mistakes in the comments.



1) Monads and Comonads are just about composing funny looking functions.

Functional languages are all about functions and putting them together, so regular function composition plays a really important role:
(.) = (b -> c) -> (a -> b) -> (a -> c)

But what about when you have modified functions like this:
(a -> m b) and (b -> m c)

And what about when you have weird functions like this:
(w a -> b) and (w b -> c)

Aligned with each other, these look awfully similar:
(.)   :: (  b ->   c) -> (  a ->   b) -> (  a ->   c)
(..)  :: (  b -> m c) -> (  a -> m b) -> (  a -> m c)
(...) :: (w b ->   c) -> (w a ->   b) -> (w a ->   c)

Would it be valid to say something like "If these functions obey the laws of function composition, then m and w have certain properties"?

I'm not mathy enough to understand category theory, but my intuition tells me that whenever two functions of the form a -> mb compose obeying the laws of function 
composition, then m forms a Monad.
Similarly, whenever to functions of the form w a -> b compose obeying the laws of function composition, then w forms a Comonad.

Functions of the form a -> m b apparently form something called a Kleisli category.
Similarly, functions of the form w a -> b form CoKleisli category.

The Haskell laws for Monad typeclass are apparently the laws of function composition if looked in Kleisli category (https://wiki.haskell.org/Monad_laws).
I suspect that the same holds for Comonads, even though I haven't found anything to back this intuition.

Bind might be more natural to implement in Haskell since it's just what is needed for do-notation.
It may also be easier for the compiler to optimize.
But I'm afraid that it completely misses the elegant intuition of function composition, and makes understanding the essence of Monads and Comonads unnecesserily difficult.

This makes about 95% of monad tutorials in the internet somewhat incorrect. The reason is, I believe, that they focus on a particular problem which someone just happens
to have used a monadic approach to solve. It's kind of incorrect to say for example that "reading from an environment is a Monad" since one can
even more naturally solve that particular problem using Comonads.




2) Monads and Comonads are just (often interchangeable) tools for solving specific problems. 

I'm claiming that when you have a problem which can be represented as function composition, you could probably solve it in three different ways:
1) compose monadic function
2) compose comonadic functions
3) use something else

Reader monad and environment comonad example...

How about safe division?

Of course we could solve it by just manually performing whatever ad-hoc magic and throwing exceptions on failure or whatever,
but that's not really interesting.

monadic...

comonadic...

Why would we want to do something like this?
While Monads compose with other Monads (at least with Monad transformers: http://hackage.haskell.org/package/transformers),
Comonads compose with other Comonads (with Comonad transformers: https://hackage.haskell.org/package/comonad).

One could always compose her custom type by making it a Category, but it wouldn't compose with anything else.

So, monads and comonads are useful tools to solve problems since they allows us to compose our functions with other existing functions.



(>=>>>>) :: Functor f => (a -> f b) -> (b -> f c) -> (a -> f c)
(>=>>>>) amb bmc a = let
    mb = amb a
    case mb of
        Pure b -> bmc b
        Free m -> Free (fmap (>>= bmc) m)




A huge thing would be if we could (semi)automatically switch our approach from monadic to comonadic and backwards.
Maybe this (http://hackage.haskell.org/package/kan-extensions-5.1/docs/Control-Monad-Co.html) could provide
something like that, I don't know. Please let me know in the comments :)