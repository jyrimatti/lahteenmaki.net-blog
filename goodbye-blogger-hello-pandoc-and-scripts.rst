Goodbye Blogger, hello Pandoc and scripts
=========================================

:Abstract: How I moved my blog from Blogger to a more developer-friendly platform.
:Authors: Jyri-Matti Lähteenmäki
:Date: 2017-03-25
:Status: Published

When I started writing my first blog post, I wanted an easy platform where I could concentrate on writing. I'm not what you could call an active blogger, but I still needed something. `Blogger <https://www.blogger.com/>`__ was widely used (I think...) and had an iPhone client. And I kind of trusted Google.

Turns out Blogger was far from perfect. The iPhone client was awkward, but the main issue was code examples. They were (and still are) a major pain since apparently Blogger has no direct support for them. Another pain point is the rich text editor, which is a concept that will never work outside really small and specific use cases. Nowadays I can't even use Atlassian Confluence without losing my mind, since they removed wiki syntax.

I could have migrated to some other platform, like `Wordpress <https://wordpress.com>`__ or `Medium <https://medium.com>`__, but since my content is mostly just text, why not use a static site generator of some kind? I started reading about `Hakyll <https://jaspervdj.be/hakyll/>`__, but due to lack of time decided to begin with transforming my blog posts to some text format.

I don't really know which text format is the best, but based on quick googling, various Markdown formats (possibly excluding `CommonMark <http://commonmark.org>`__) were out of the question. `reStructuredText <http://docutils.sourceforge.net/rst.html>`__ seemed carefully thought and powerful. Did I make the right choice?

No matter which you choose, you don't even necessarily need an editor. `Markup.rocks <http://markup.rocks>`__ is a "webified" version of `Pandoc <http://pandoc.org>`__, which can be used to see how your markup turns into Html.

Since I already try to use `Nix <https://nixos.org/nix/>`__ for everything, Pandoc was really easy to invoke to transform my rst:s to HTML. Pandoc's default HTML template was easy to modify to create a complete custom page. Turns out I only needed a few lines of Bash (God forgive me!) to create the final blog with support for tagging, publishing nd RSS.

I like `Disqus <https://disqus.com>`__ for commenting, `AddThis <https://www.addthis.com>`__ for sharing, `Google Analytics <https://analytics.google.com/>`__ for analytics. These were easy to include since I was not confined to any limits of an existing blogging tool. The whole thing is a bunch of static files and a bash script, and thus easy `to store in GitHub <https://github.com/jyrimatti/lahteenmaki.net-blog>`__.

Feel free to clone the repo and adjust for your own blog. The only dependency is Nix, which you should have already ;)

Bash?!?
-------

Yeah, no one should ever use Bash for anything. You can replace it with any scripting language you like as long as it's found in Nixpkgs. Just add the depency to the nix-shell definition. I'll switch to something eventually, maybe pure Haskell.

But I don't have a server to host the blog!
-------------------------------------------

I'm not really familiar with Github's hosting services, but I guess if you just commit the generated HTML files, Github can host them for you. Please let me know what it takes.

Nice, but your "engine" is seriosly lacking features!
-----------------------------------------------------

Ok, like what? Let me know and I'll see what can be done.
