Haskell and non-blocking asynchronous IO
========================================

:Authors: Jyri-Matti Lähteenmäki
:Date: 2013-01-05

Here begins my journey to the magnificent world of Haskell.

I was chatting with a co-worker a while back about the influence of
programming languages to code quality etc. He mentioned
`node.js <http://nodejs.org/>`__ and working with
`Promises <http://en.wikipedia.org/wiki/Promise_(programming)>`__. I
kind of responded that I don't really like *Promise-hell* or
*Callback-hell* and would rather just say what I want sequentially.

A while back I started implementing a chat server and client. In
Haskell. Just for fun and to learn the language. Googling for examples I
quickly wrote something like:

.. code:: haskell

    acceptLoop socket = do
        (h,_,_) <- accept socket
        hSetBuffering h NoBuffering
        forkIO $ incoming h
        acceptLoop socket

The function ``forkIO`` kind of scared me and I decided to later come
back to it and find out how to do asynchronous non-blocking IO in
Haskell since it's such a buzz-word nowadays.

Well, turns out Haskell is one of those rare languages that `does
non-blocking IO by
default <http://stackoverflow.com/questions/3847108/what-is-the-haskell-response-to-node-js>`__.
``forkIO`` function doesn't spawn a new operating system thread, but
instead a light-weight (i.e. green) thread. They claim that one can
spawn tens of thousands of concurrent threads on a regular laptop. A
regular OS thread can be spawned with ``forkOS`` function if needed.

Basically this means that I have been programming with non-blocking IO
all the time without realizing it. It's still sequential, but could
parallel operations be added easily, and without all the hassle with
promises?

Let's first define some long running operation, pretending that it's
fetching something over a slow network connection, or whatever:

.. code:: haskell

    -- some long-running "remote" operation
    longRemoteOperation :: String -> IO (String)
    longRemoteOperation a = do
        -- random delay to make parallel operations finish in random order
        d <- getStdRandom (randomR (1000000,1001000))
        _ <- threadDelay d
        putStr a
        return a

Synchronous (that is, sequential) operations would be the basic case.
This function performs *n* operations one after another:

.. code:: haskell

    -- runs n operations synchronously
    sync :: Int -> IO ()
    sync 0 = return ()
    sync n = do
        _ <- longRemoteOperation (show n)
        sync (pred n)

The two asynchronous versions (green threads and native threads) need a
hack to prevent the program from exiting before all the threads are
finished. Please forgive me:

.. code:: haskell

    -- runs n operations asynchronously using Haskell green threads
    greenThread :: Int -> IO ()
    greenThread = async forkIO

    -- runs n operations asynchronously using native OS threads
    osThread :: Int -> IO ()
    osThread = async forkOS

    -- a hack to wait until all threads are finished before exiting program
    async :: (IO () -> IO t) -> Int -> IO ()
    async forkMode n = do
            mvars <- replicateM n $ run $ longRemoteOperation "*"
            forM_ mvars takeMVar
         where
            run f = do
                x <- newEmptyMVar
                _ <- forkMode $ (void f) `finally` putMVar x ()
                return x

The previous functions can be used to find out how many threads my poor
little laptop can handle, but they do not resemble the way async
operations are normally written. So let's write two more functions to
see how parallel operation differs from sequential in practice:

.. code:: haskell

    -- runs 5 operations sequntially
    sequential :: IO ()
    sequential = do
        a1 <- longRemoteOperation "1"
        [a2, a3, a4] <- mapM longRemoteOperation ["2", "3", "4"]
        a5 <- longRemoteOperation "5"
        putStrLn $ foldl1 (++) [a1, a2, a3, a4, a5]

    -- runs one operation, then 3 parallel, then one more
    parallel :: IO ()
    parallel = do
        a1 <- longRemoteOperation "1"
        [a2, a3, a4] <- mapConcurrently longRemoteOperation ["2", "3", "4"]
        a5 <- longRemoteOperation "5"
        putStrLn $ foldl1 (++) [a1, a2, a3, a4, a5]

Whoa, hold on a second! The difference is like one word? And no meddling
with promises?

Before we get too exited I have to admit that this only demonstrates a
basic case of performing three operations in parallel and only
continuing when all three are finished. More complicated workflows might
also complicate the code, but my poor imagination couldn't come up with
realistic requirements, so I satisfied with this. Please see
`Control.Concurrent.Async <http://hackage.haskell.org/packages/archive/async/2.0.0.0/doc/html/Control-Concurrent-Async.html>`__
for more information.

Let's add a main method and perform some timing to make sure everything
is happening as we expect:

.. code:: haskell

    -- module declaration and imports, for completeness...
    module Main where

    import System.Environment (getArgs)
    import Control.Exception (finally)
    import Control.Concurrent
    import Control.Concurrent.Async (mapConcurrently)
    import Control.Monad (forM_, replicateM, void)
    import System.Random (getStdRandom, randomR)


    main :: IO ()
    main = do
        args <- getArgs
        case args of
            ["sync", n]    -> sync (read n)
            ["green", n]   -> greenThread $ read n
            ["os", n]      -> osThread $ read n
            ["sequential"] -> sequential
            ["parallel"]   -> parallel
            _       -> return ()

Let's first try the simple synchronous version with five operations. In
each case the code prints a thread-number (or a star) when the thread
finishes:

.. code:: bash

    mac:asyncIO inferior$ time ./asyncIO "sync" 5
    54321
    real  0m5.013s
    user  0m0.006s
    sys   0m0.010s

The the whole thing took five seconds as expected. Next the forked:

.. code:: bash

    mac:asyncIO inferior$ time ./asyncIO "green" 5
    *****
    real  0m1.020s
    user  0m0.004s
    sys   0m0.006s
    mac:asyncIO inferior$ time ./asyncIO "os" 5
    *****
    real  0m1.008s
    user  0m0.003s
    sys   0m0.005s

Both green threads and native threads run similarly, and take about one
second, as expected. But how about if we increase the number of threads:

.. code:: bash

    mac:asyncIO inferior$ time ./asyncIO "green" 2000 > /dev/null

    real  0m1.041s
    user  0m0.041s
    sys   0m0.033s
    mac:asyncIO inferior$ time ./asyncIO "os" 2000 > /dev/null

    real  0m1.504s
    user  0m0.554s
    sys   0m0.511s

With 2000 threads the green-thread version still performs in about a
second, but the native threads took 50% longer.

Now if I try with 3000 native threads I get:
``asyncIO: user error (Cannot create OS thread.)`` Unfortunately this
seems to be the OS limit:

.. code:: bash

    mac:asyncIO inferior$ sysctl kern.num_taskthreads
    kern.num_taskthreads: 2048

Anyone know how to increase the limit on a Mac?

Still, 20000 and 100000 green threads perform really nice, and I doubt
that no matter what the limits, 100000 native threads would kill my
laptop =) :

.. code:: bash

    mac:asyncIO inferior$ time ./asyncIO "green" 20000 > /dev/null

    real  0m1.331s
    user  0m0.380s
    sys   0m0.243s
    mac:asyncIO inferior$ time ./asyncIO "green" 100000 > /dev/null

    real  0m2.889s
    user  0m1.905s
    sys   0m1.037s

We still have the two "regular programming style" methods remaining.
Let's verify that they run as expected. Each thread prints again it's
number when it finishes. Finally all numbers are printed again as a
"complete result". See the code if you can't figure out my
explanation... :

.. code:: bash

    mac:asyncIO inferior$ time ./asyncIO "sequential"
    1234512345

    real  0m5.011s
    user  0m0.005s
    sys   0m0.009s
    mac:asyncIO inferior$ time ./asyncIO "parallel"
    1324512345

    real  0m3.012s
    user  0m0.005s
    sys   0m0.008s

Indeed, *sequential* takes five seconds and always prints the numbers in
order, whereas *parallel* takes three seconds as expected, and the order
of the second, third and fourth digit randomly changes, even though the
final result is always in the correct order.

Haskell seems to make this stuff really easy. Yes, I know, not
everything in Haskell is easy...

Feel free to leave a Node.js example to the comments. We'll see which
one is more readable ;)
