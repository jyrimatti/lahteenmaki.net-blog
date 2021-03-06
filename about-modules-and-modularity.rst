About modules and modularity
============================

:Abstract: Once upon a time on a specific tuesday the Internet was shaken and stirred by someone breaking half the NPM-packages by removing a critical dependency from NPM, namely left-pad.
:Authors: Jyri-Matti Lähteenmäki
:Status: Draft

Once upon a time on a specific tuesday the Internet was shaken and stirred by `someone breaking half the NPM-packages <http://www.theregister.co.uk/2016/03/23/npm_left_pad_chaos/>`__ by removing a *critical* dependency from NPM, namely left-pad.

Critical, say?

Left-pad is only an 11-line function. Some have pointed out that the NPM-philosophy (?) of using even individual functions as modules just doesn't work. `Some have even suggested <http://www.haneycodes.net/npm-left-pad-have-we-forgotten-how-to-program/>`__ that we should implement small and simple functions ourselves, reinvent the wheels. Some have noted that the NPM-philosophy (?) of loose versioning (practically always depend on most recent stuff) simply doesn't work.

Dumping "modules" altogether `isn't even a new idea <http://lambda-the-ultimate.org/node/5079>`__. As pretty as the idea is, I think it's flawed. We need lot's of modularity on different levels to make codebase more comprehensible. On my current day job I have multiple "projects" or "products", `some libs <https://github.com/solita/functional-utils/>`__ moved to GitHub, multiple `Gradle-projects <https://gradle.org/>`__, multiple source sets within some of them, hierarchical Java-package structure, multiple levels of classes (public, package-private in same file, nested classes...) and in the bottom there are functions divided in some sensible way throughout the classes.

All these levels are needed since more the merrier. What would happen if we dumped all structure and moved all functions to a single, global class and called it our package repository? Oh god... We need reusable modules of different sizes, and individual functions should probably be more like an exception than a rule.

Increasing code reuse is a noble goal, but how often do we actually want to reuse a single function? Sometimes yes, like left-pad, but when we are doing left-padding chances are we're gonna need some other string-handling functions next. Or actually collection handling, which left-pad more generally is.

Pushing even small functions to reusable modules might be partly due to problems of the underlying language. Could you write correct implementation of isArray? I most certainly couldn't. Line count or character count is not relevant here, but it would be better to publish such functions as a bigger module, e.g. 'lang-helpers'.

Version ranges are a nice idea, but I simply don't want my code to break just because someone else released a new version of a transitive dependency. Since I'm a functional programmer, when I request version x.y.z of a library I'm expecting to get exactly the same whole thing back tomorrow and in a different build environment.

But we need something like version ranges, otherwise practically no code would ever compile or run due to different version requirements in different transitive dependencies. Could there be other solutions? We could safely depend on the latest version in "the world" if "the world" was somehow versioned. That is, in addition to a mutable NPM repo (or `Hackage <https://hackage.haskell.org/>`__ in the Haskell world), there should be some kind of "blessed snapshots" that are known to work (like `Stackage <https://www.stackage.org/>`__ in the Haskell world). `Nix <https://nixos.org/nix/>`__ seems to offer this kind of thinking for pretty much everything.

This kind of approach works well for highly static languages: when it compiles, the dependencies are compatible with a relatively high confidence. Determining compatibility in NPM packages would have to rely on unit tests, which, IMHO, is most often not enough.

So, what would be the optimal solution for NPM? Or is the JavaScript world simply doomed to fail? I wouldn't mind ;)
