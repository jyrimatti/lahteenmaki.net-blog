Applicative Parsing
===================

:Abstract: Implementing a combinatorial parser utilizing applicative parsing.
:Authors: Jyri-Matti Lähteenmäki
:Date: 2018-02-18
:Status: Published

Years ago in the university I learned something about creating parsers. Not much, though, and it all seemed fairly difficult with `Flex/Bison <http://aquamentus.com/flex_bison.html>`__ and friends. Later in life, when getting familiar with `Scala <http://www.scala-lang.org>`__ and `Haskell <https://www.haskell.org>`__, I learned about combinatorial parsing, which finally made parsing feel easy.

I’ve been waiting for some spare time to learn some monadic parser combinator library, since they feel like state of the art, and a good thing to spend some time on. Then I learned about monads, and that most parsing doesn’t actually need monadic actions.

Then I heared about *Applicative Parsing*, and learned that even the state of the art monadic parser combinator libraries in Haskell actually come with applicative interfaces.

So, what’s going on? What does parsing really have to do with abstractions like `Applicative <https://hackage.haskell.org/package/base/docs/Control-Applicative.html>`__ and `Monad <https://hackage.haskell.org/package/base/docs/Control-Monad.html>`__?

Let’s try to parse a small language without any kind of parsing library to see what we can come up with. Everybody seems to like lisps, so let’s parse this:

.. code:: scheme

    (print (+ "Hello " "World!”))

First the regular headers, without implicit ``Prelude`` to see what we actually use:

.. code:: haskell

    {-# LANGUAGE NoImplicitPrelude, LambdaCase, StandaloneDeriving, DeriveFunctor #-}
    module Parser where
    import Prelude (undefined,String,Char,Bool,($),(.),(==),(/=),Show,Maybe(Just,Nothing))

What is the syntax like for our toy language? A term is either a plain string, or either a concatenation or printing inside parentheses. Let’s make up an imaginary operator ``<|>`` to represent alternatives:

.. code:: haskell

    term = str <|> inparens (concat <|> print)
    (<|>) = undefined

“in parentheses” means that there’s a single term between opening and closing parenthesis character. Let’s also make up an operator ``<*>`` to represent sequential composition:

.. code:: haskell

    inparens t = char '(' <*> t <*> char ')'
    char = undefined
    (<*>) = undefined

What is left is to define the syntax for out three kinds of terms. A string is just zero or more characters between opening and closing double quote. Let's ignore any kind of escaping, and just forbid using double quotations marks inside strings:

.. code:: haskell

    str = char '"' <*> many (notChar '"') <*> char '"'
    notChar = undefined
    many = undefined

A concatenation is just the ``+`` character followed by zero or more terms:

.. code:: haskell

    concat = char '+' <*> many term

Printing is expressed with the string ``print`` followed by the term to print:

.. code:: haskell

    print = string "print" <*> term
    string = undefined

Parsing should eventually give us a data structure called an Abstract Syntax Tree, which we then could process further. A Haskell type for the nodes of our tree would be:

.. code:: haskell

    data Term = Str String | Concat [Term] | Print Term

Now we need a way to convert our syntax to a tree of Terms. Let’s make up another operator ``<$>`` that converts a parsing result to a data type of our choice:

.. code:: haskell

    (<$>) = undefined

    str    = Str    <$> (char '"' <*> many (notChar '"') <*> char '“')
    concat = Concat <$> (char '+' <*> many term)
    print  = Print  <$> (string "print" <*> term)

If you follow the imaginary types of these expressions, you’ll notice that if our expressions would be parsers that produced the data they parsed, the types would actually match. Expect that our sequential composition would produce too much results. For example, in parsing ``print`` we wouldn’t actually be interested in receiving the text ``print`` as long as it’s present in the syntax, we’d only be interested in the right hand side of the composition. Let’s solve this by defining two variants for our sequential composition, which ignore one side and only return the other:

.. code:: haskell

    -- "ignoring left and taking right"
    a *> b = undefined

    -- "taking left and ignoring right
    a <* b = undefined

Now we can improve our definitions:

.. code:: haskell

    str = char '"' *> many (notChar '"') <* char '"'
    concat = char '+' *> many term
    print = string "print" *> term

    inparens t = char '(' *> t <* char ')'

In the final syntax, the terms are often separated by white space. One way to handle this would be to define that a term can always starts with some white space:

.. code:: haskell

    term = space *> (str <|> inparens (concat <|> print))
    space = many $ char ' '

To actually be able to parse a string of characters and produce something else, we’ll need to implement the most primitive of our undefineds, namely ``char``. For this we need to think about what our Parser would actually be like. One definition is something which takes a string of characters and turns it into a list of things and remaining characters:

.. code:: haskell

    -- "a parser for things is a parser from strings to list of things and strings"
    newtype Parser thing = Parser { parse :: String -> [(thing,String)] }

Now we can define a primitive parser which either accepts or rejects a single character based on a given predicate, which can be used to implement the parsers accepting a single character:

.. code:: haskell

    satisfy :: (Char -> Bool) -> Parser Char
    satisfy pred = Parser $ \case
        x:xs | pred x -> [(x,xs)]
        _ -> []

    char    = satisfy . (==)
    notChar = satisfy . (/=)

At this point we have actually implemented the whole logic to actually parse our toy language. And we haven’t used a parsing library, monads or applicatives or pretty much anything! The only thing missing is a couple of undefineds: our five operators ``<|>``, ``<*>``, ``<*``, ``*>``, ``<$>`` as well as two combinators ``many`` and ``string``.

We could implements these ourselves, but if we take a close look at the names and semantics, we might recognize these as functions from Functor and Applicative. Let’s see if we can use these fundamental abstractions to implement the remaining pieces.

First we need a `Functor <https://hackage.haskell.org/package/base/docs/Data-Functor.html>`__ instance, which we can derive:

.. code:: haskell

    import qualified Data.Functor as F

    deriving instance F.Functor Parser

Then instances for ``Applicative`` and ``Alternative``, which we have to write manually. (See `One more thing<#one-more-thing>`_ for a way to automatically derive these):

.. code:: haskell

    import qualified Control.Applicative as A

    instance A.Applicative Parser where
        pure x = Parser $ \input -> [(x, input)]
        Parser af <*> Parser aa = Parser $ \input ->
            [(f a, input2) | (f, input1) <- af input, (a, input2) <- aa input1]

    instance A.Alternative Parser where
        empty = Parser $ \_ -> []
        (Parser p) <|> (Parser q) = Parser $ \input ->
            case p input of
                [] -> q input
                r -> r

And now the missing implementations are available from the ``Functor`` and ``Applicative`` modules:

.. code:: haskell

    (<$>)   = (F.<$>)
    (<|>)   = (A.<|>)
    a <*> b = a A.<*> b
    (*>)    = (A.*>)
    (<*)    = (A.<*)
    many    = A.many

The remaining ``string`` we'd have to implement ourselves, or use `Traversable <https://hackage.haskell.org/package/base/docs/Data-Traversable.html>`__:

.. code:: haskell

    import qualified Data.Traversable as T

    string = T.traverse char

Now we can implement the main parsing function and derive a ``Show`` instance to get a printable AST out:

.. code:: haskell

    deriving instance Show Parser

    parseProgram s = case parse term s of
         [(t,"")] -> Just t
         _        -> Nothing

which actually works!

.. code:: haskell

    > parseProgram "(print (+ \"Hello \" \"World!\"))"
    -- Just (Print (Concat [Str "Hello ",Str "World!"]))

This is *Applicative Parsing*.

The ``Applicative`` interface (together with ``Alternative`` and ``Functor``) happens to provide most what is needed to perform parsing. As the ``Applicative`` is a really abstract and general purpose interface, it really makes me wonder why combinatorial applicative parsing libraries aren't more popular through various programming languages.

I mentioned in the beginning that many existing monadic parser combinator libraries implement the applicative interface. This means, that if (or *when*) I would like to utilize a performant, battle-tested parser implementation providing nice error messages with line numbers, instead of this kind of self made junk, I can do it pretty much by just modifying the import statements. For example, to make this example work with `MegaParsec (6.x) <https://hackage.haskell.org/package/megaparsec>`__, I can do it like this:

.. code:: haskell

    {-# LANGUAGE NoImplicitPrelude, FlexibleContexts, DeriveFunctor #-}
    module ParserUsingMegaParsec where

    import Prelude (String,($),(.),(/=),Show,show,putStrLn)

    import Data.Functor ((<$>))
    import Control.Applicative (many,(<|>),(*>),(<*))
    import Control.Applicative.Combinators (between)

    import Text.Megaparsec (parse)
    import Text.Megaparsec.String (Parser)
    import Text.Megaparsec.Char (char,notChar,space,satisfy,string)

    data Term = Str String | Concat [Term] | Print Term
        deriving Show

    term :: Parser Term
    term = space *> (str <|> inparens (concat <|> print))

    str    = Str <$> (char '"' *> many (notChar '"') <* char '"')
    concat = Concat <$> (char '+' *> many term)
    print  = Print <$> (string "print" *> term)

    inparens = between (char '(') (char ')')

This is the whole implementation.

The big point is, that in order to do parsing, you don’t actually need to learn a parser generator or a parser combinator library. You only need to learn ``Functor`` and ``Applicative`` interfaces, which should already be (but unfortunately are not) taught in every university program related to software development.

``Monads`` are needed only when building a *context sensitive* parser, where a step requires some information from previous steps. Using the ``Applicative`` interface leaves (at least in theory) more optimisation possibilities for the implementation. If you want to build an understanding of monads in general, I’d recommend browsing through `my own presentations <https://lahteenmaki.net/#presentations>`__ since unfortunately, I believe, most ``Monad`` tutorials are missing the point even more than I am ;)

One more thing
--------------

Recently I ran into a `related blog post <http://vaibhavsagar.com/blog/2018/02/04/revisiting-monadic-parsing-haskell/>`__, which defined a way to reduce code by deriving the ``Applicative`` instances:

.. code:: haskell

    import qualified Control.Monad.Trans.State.Strict as ST

    newtype Parser thing = Parser { parse :: ST.StateT String Maybe thing }
        deriving (Functor, Applicative, Alternative)

    parseProgram = ST.runStateT . parse

    satisfy pred = Parser . ST.StateT $ \case
        x:xs | pred x -> pure (x,xs)
        _             -> empty

Please leave any questions and suggestions in the comments! Especially if you think I have completely missed some point, and have a chance to learn something :)

The (compiling and runnable) code examples are available in Github: https://github.com/jyrimatti/app-parsing
