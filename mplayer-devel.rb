require 'formula'

class BrokenFormula < Requirement
  # i..think this is the right syntax. or one of the many, i guess. ruby = :(
  fatal true
  satisfy { 4 < 2 }
  def message
    "This module is currently disabled due to extreme brokeness."
  end
end

class MplayerDevel < Formula
  homepage 'http://www.mplayerhq.hu/'
  head "svn://svn.mplayerhq.hu/mplayer/trunk", :using => :svn

  option 'without-osd', 'Disable on-screen display (menus, etc)'
  option 'without-encoders', 'Build without common encoders (x264, xvid, etc.)'

  depends_on BrokenFormula

  depends_on 'git' => :build
  depends_on 'subversion' => :build
  depends_on 'pkg-config' => :build
  depends_on 'yasm' => :build

  depends_on 'lame'
  depends_on 'libass'
  depends_on 'libiconv'
  depends_on 'libjpeg'
  depends_on 'libmad'
  depends_on 'libogg'
  depends_on 'liboil'
  depends_on 'libpng'
  depends_on 'libvorbis'
  depends_on 'lzo'
  depends_on 'ncurses'
  depends_on 'openjpeg'
  depends_on 'opus'
  depends_on 'theora'
  depends_on 'zlib'

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
    odie "This formula is .. a work in progress. To put it mildly. DO NOT USE!"

    dvdnav_url = "svn://svn.mplayerhq.hu/dvdnav/trunk"
    dvdnav_ver = "1257"
    ffmpeg_ver = "09887096734eabaac5454b3fb5e4489457ac9434"

    system "#{bin}/svn", "export", "-r#{dvdnav_ver}", "#{dvdnav_url}/libdvdnav/src", "./libdvdnav/"
    system "#{bin}/svn", "export", "-r#{dvdnav_ver}", "#{dvdnav_url}/libdvdread/src", "./libdvdread4/"
    system "#{bin}/git", "clone", "--depth", "5000", "git://git.videolan.org/ffmpeg.git", "./ffmpeg"

    cd 'ffmpeg' do
      system "git", "checkout", "-f" "#{ffmpeg_ver}"
    end

    #--extra-cflags="#{ENV.cflags}"
    #--extra-ldflags="#{ENV.ldflags}"
    #--cc=#{ENV.cc}
    #--host-cc=#{ENV.cc}
    #--datadir="#{prefix}/share/mplayer-devel"
    #--confdir="#{prefix}/etc/mplayer-devel"
    #--mandir="#{prefix}/share/man"

    args = %W[
      --prefix="#{prefix}"
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

    if build.with? 'osd'
      args << "--enable-menu"
    end

    if build.without? 'osd'
      args << "--disable-fontconfig"
      args << "--disable-freetype"
    end

    if build.without? 'encoders'
      args << "--disable-xvid"
      args << "--disable-x264"
      args << "--disable-faac"
      args << "--disable-libdv"
      args << "--disable-twolame"
    end

    odie "How did you get here? NO."
    system "sh -c 'exit 1' -"
    # system "./configure", *args
    # system "make"
    # system "make install"
  end

  test do
    system "sh -c true"
  end
end

__END__
