require 'formula'

class Macports < Formula
  # dummy to trick brew doctor :P this is installed by hand.
  homepage 'http://example.com/'
  url 'http://example.com/releases/macports-2.3.99.tar.gz'
  sha256 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
  def install
    system "exit 0"
  end
end
