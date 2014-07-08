require 'formula'

class BrokenFormula < Requirement
  fatal true
  satisfy { ENV['BUILD_BROKEN_MPLAYER'] == 'yes' }
  def message; "This formula is disabled (still a work in progress)" end
end

class NoExternalsSubversionDownloadStrategy < SubversionDownloadStrategy
  def fetch_repo target, url, revision=nil, ignore_externals=false
    super target, url, revision, true
  end
end

class MplayerDevel < Formula
  homepage 'http://www.mplayerhq.hu/'

  version "36449"
  url "svn://svn.mplayerhq.hu/mplayer/trunk",
    :using => NoExternalsSubversionDownloadStrategy,
    :revision => "#{version}"

  #patch :DATA

  option 'without-osd', 'Disable on-screen display (menus, etc)'
  option 'without-encoders', 'Build without common encoders (x264, xvid, etc.)'

  # hamstring formula before it can build deps
  depends_on BrokenFormula

  # build dependencies
  depends_on 'git' => :build
  depends_on 'subversion' => :build
  depends_on 'pkg-config' => :build
  depends_on 'yasm' => :build

  # compiler blacklsit stuff
  depends_on "gcc" if MacOS.version >= :mountain_lion
  fails_with :clang do
    build 211
    cause 'Inline asm errors during compile on 32bit Snow Leopard.'
  end unless MacOS.prefer_64_bit?
  
  # these are in the dupes tap. list as :optional?
  #depends_on 'libiconv'
  #depends_on 'ncurses'
  #depends_on 'zlib'
 
  # run depends
  depends_on 'lame'
  depends_on 'libass'
  depends_on 'libjpeg'
  depends_on 'libmad'
  depends_on 'libogg'
  depends_on 'liboil'
  depends_on 'libpng'
  depends_on 'libvorbis'
  depends_on 'lzo'
  depends_on 'openjpeg'
  depends_on 'opus'
  depends_on 'theora'

  if build.with? 'osd'
    depends_on 'fontconfig'
    depends_on 'freetype'
  end

  if build.with? 'encoders'
    depends_on 'faac'
    depends_on 'libdv'
    depends_on 'twolame'
    depends_on 'x264'
    depends_on 'xvid'
  end

  def install
    dvdnav_url = "svn://svn.mplayerhq.hu/dvdnav/trunk"
    dvdnav_ver = "1257"
    ffmpeg_url = "git://git.videolan.org/ffmpeg.git"
    ffmpeg_ver = "09887096734eabaac5454b3fb5e4489457ac9434"

    system "svn", "export", "--force", "-r#{dvdnav_ver}", "#{dvdnav_url}/libdvdnav/src", "./libdvdnav/"
    system "svn", "export", "--force", "-r#{dvdnav_ver}", "#{dvdnav_url}/libdvdread/src", "./libdvdread4/"
    system "git", "clone", "--depth", "5000", "#{ffmpeg_url}", "./ffmpeg"

    cd 'ffmpeg' do
      system "git", "checkout", "-f", "#{ffmpeg_ver}"
    end

    ENV.O1 if ENV.compiler == :llvm
    ENV.append_to_cflags "-mdynamic-no-pic" if Hardware.is_32_bit? && Hardware::CPU.intel? && ENV.compiler == :clang

    args = %W[
      --prefix=#{prefix}
      --cc=#{ENV.cc}
      --host-cc=#{ENV.cc}
      --enable-png
      --enable-jpeg
      --enable-liblzo
      --enable-theora
      --enable-libvorbis
      --enable-libopus
      --enable-mad
      --disable-smb
      --disable-live
      --disable-cdparanoia
      --disable-fribidi
      --disable-enca
      --disable-libcdio
      --disable-speex
      --disable-toolame
      --disable-xmms
      --disable-musepack
      --disable-sdl
      --disable-aa
      --disable-caca
      --disable-x11
      --disable-gl
      --disable-arts
      --disable-esd
      --disable-lirc
      --disable-mng
      --disable-libdirac-lavc
      --disable-libschroedinger-lavc
      --disable-liba52 
      --disable-gif
      --disable-apple-remote
    ]

    if MacOS.prefer_64_bit?
      args << "--disable-qtx"
      arch = "x86_64"
    else
      args << "--enable-qtx"
      arch = "i386"
    end

    args << "--target=#{arch}-Darwin"

    if build.with? 'osd'
      args << "--enable-menu"
    else
      args << "--disable-fontconfig" << "--disable-freetype"
    end

    if build.without? 'encoders'
      args << "--disable-xvid"
      args << "--disable-x264"
      args << "--disable-faac"
      args << "--disable-libdv"
      args << "--disable-twolame"
    end

    system "./configure", *args
    system "make"
    odie "aborting before insstall phase"
    system "make install"
  end
end

__END__
