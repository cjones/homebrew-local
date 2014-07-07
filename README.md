README
======

This repository is a "tap" for the OSX package manager [homebrew][]. It
contains build instructions for custom packages, patches, etc. and is
probably of little interest to anyone besides me. For whatever reason,
[homebrew][] only allows custom repositories from [github][] instead of
arbitrary repository URLs, at least as far as I could tell, hence this.

Feel free to use anything here, but be forewarned that I disclaim any
responsibility for problems you might encounter as a result (note: most
of these exist precisely because they are doing something either frowned
upon in the [homebrew][] ecosystem, or at least entirely unsupported.
Please don't open issues against this, they will most likely be ignored.


USAGE
=====

To use, enter the following from a Terminal or [iTerm2][] window:

    $ brew tap cjones/local

This will "tap" the formulae in this repository, which means it clones
the repository into "$(brew --prefix)/Library/Taps/" and symlinks ruby
files into ../Formula/ as if they were part of [homebrew][]. You can
then install them as normal, or optionally by a fully qualified path
that includes the tap source, for example:

    $ brew install cjones/local/bash-completion2-patched

See the [wiki page][brew-tap] for more information.


FORMULA
=======

 *  [bash-completion2-patched.rb][1]

    Description.

 *  [macports.rb][2]

    Description.

        $ example installer code
        $ more lorem ipsum action

 *  [mplayer-devel.rb][3]

    Description.

        $ example usage --maybe


LICENSE
=======

Unless otherwise noted, all source files in this repository are
implicitly licensed under the "new BSD" license (also known as
"modified" BSD license and/or "2-clause", meaning the advertising clause
of the original BSD license has been removed). The full copy of the
license text can be found on the [OSI website][license].


WOW THIS IS A PRETTY THOROUGH README
====================================

I am playing with/learning markdown syntax. :P


[homebrew]: http://brew.sh/
[github]: https://github.com/
[iterm2]: https://code.google.com/p/iterm2/
[brew-tap]: https://github.com/Homebrew/homebrew/wiki/brew-tap
[license]: http://opensource.org/licenses/BSD-2-Clause

[1]: https://github.com/cjones/homebrew-local/blob/master/bash-completion2-patched.rb
[2]: https://github.com/cjones/homebrew-local/blob/master/macports.rb
[3]: https://github.com/cjones/homebrew-local/blob/master/mplayer-devel.rb
