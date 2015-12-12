require 'formula'

class MPlayerDevelDownloadStrategy < SubversionDownloadStrategy

  def initialize(name, resource)
    f = Formula['ffmpeg']
    @ffmpeg = (Class.new(Formula) { head "#{f.head.url}", :shallow => false }).new(f.name, f.path, :head).head
    super name, resource
  end

  def fetch
    super
    @ffmpeg.fetch
  end

  def clear_cache
    super
    @ffmpeg.clear_cache
  end

  def stage
    super
    dst = Pathname.new(File.join(Dir.pwd, "ffmpeg"))
    quiet_safe_system 'git', 'clone', '--no-checkout', @ffmpeg.cached_download, dst
    dst.cd { quiet_safe_system 'git', 'checkout', '-f', "4ea4d2f438c9a7eba37980c9a87be4b34943e4d5" }
    quiet_safe_system 'svn', 'export', "-r", "1257", "svn://svn.mplayerhq.hu/dvdnav/trunk/libdvdnav/src", "libdvdnav"
    quiet_safe_system 'svn', 'export', "-r", "1257", "svn://svn.mplayerhq.hu/dvdnav/trunk/libdvdread/src", "libdvdread4"
  end
end

class FormulaHamstringer < Requirement
  fatal true
  satisfy { ENV['BUILD_BROKEN_MPLAYER'] == 'yes' }
  def message; "This formula is disabled (still a work in progress)" end
end

class MplayerDevel < Formula

  homepage 'http://www.mplayerhq.hu/'
  conflicts_with 'mplayer', :because => 'Provides the same binaries.'

  ## OLDER WORKING VERSION
  version "37559"
  revision 8
  url 'svn://svn.mplayerhq.hu/mplayer/trunk', :using => MPlayerDevelDownloadStrategy

  patch :DATA

  option 'with-debug',           'Compile with debugging symbols'
  option 'with-esd',             'Enable EsounD audio output'
  option 'with-html-docs',       'Enable building HTML documentation'
  option 'with-fribidi',         'Enable FriBidi Unicode support (implies --with-osd)'
  option 'with-smb',             'Enable Samba support'
  option 'with-speex',           'Enable Speex playback'
  option 'with-dts',             'Enable non-passthrough DTS playback'
  option 'with-sdl',             'Enable SDL video output'
  option 'with-a52',             'Enable AC-3 codec support'
  option 'with-aa',              'Enable animated ASCII art video output'
  option 'with-caca',            'Enable animated ASCII art video output'
  option 'without-osd',          'Disable on-screen display (menus, etc)'
  option 'without-encoders',     'Build without common encoders (x264, xvid, etc.)'
  option 'without-apple-remote', 'Disable Apple Infrared Remote support'

  depends_on 'git'        => [:build, :optional]
  depends_on 'subversion' => [:build, :optional]
  depends_on 'pkg-config' => :build
  depends_on 'yasm'       => :build

  if build.with? 'html-docs'
    depends_on 'docbook'     => :build
    depends_on 'docbook-xsl' => :build
  end

  depends_on 'gcc' => :build if MacOS.version >= :mountain_lion

  depends_on 'libiconv' => :optional
  depends_on 'ncurses'  => :optional
  depends_on 'zlib'     => :optional

  depends_on 'lame'
  depends_on 'libass'
  depends_on 'libjpeg'
  depends_on 'libmad'
  depends_on 'libogg'
  depends_on 'libpng'
  depends_on 'libvorbis'
  depends_on 'lzo'
  depends_on 'opus'
  depends_on 'theora'

  if build.with? 'encoders'
    depends_on 'faac'
    depends_on 'libdv'
    depends_on 'twolame'
    depends_on 'x264'
    depends_on 'xvid'
  end

  if build.with? 'osd' or build.with? 'fribidi'
    depends_on 'fontconfig'
    depends_on 'freetype'
  end

  if build.with? 'dirac'
    depends_on 'dirac'
    depends_on 'schroedinger'
  end

  depends_on 'esound' if build.with? 'esd'
  depends_on 'fribidi' if build.with? 'fribidi'
  depends_on 'samba' if build.with? 'smb'
  depends_on 'speex' if build.with? 'speex'
  depends_on 'libdca' if build.with? 'dts'
  depends_on 'sdl' if build.with? 'sdl'
  depends_on 'a52dec' if build.with? 'a52'
  depends_on 'aalib' if build.with? 'aa'
  depends_on 'libcaca' if build.with? 'caca'
  depends_on 'openjpeg' if build.with? 'openjpeg'

  fails_with :clang do
    build 211
    cause 'Inline asm errors during compile on 32bit Snow Leopard.'
  end unless MacOS.prefer_64_bit?

  def arch
    if MacOS.prefer_64_bit?
      Hardware::CPU.arch_64_bit
    else
      Hardware::CPU.arch_32_bit
    end
  end

  def player;  'mplayer'          end
  def encoder; 'mencoder'         end
  def ident;   'midentify'        end
  def conf;    etc/player         end
  def docs;    share/'doc'/player end

  def configure_args
    args = ["--prefix=#{prefix}",
            "--bindir=#{bin}",
            "--datadir=#{docs}",
            "--mandir=#{man}",
            "--confdir=#{conf}",
            "--libdir=#{lib}",
            "--codecsdir=#{lib}/codecs",
            "--cc=#{ENV.cc}",
            "--host-cc=#{ENV.cc}",
            "--target=#{arch}-Darwin",
            "--language=en",
            "--enable-macosx-bundle",
            "--enable-macosx-finder",
            "--enable-png",
            "--enable-jpeg",
            "--enable-liblzo",
            "--enable-theora",
            "--enable-libvorbis",
            "--enable-libopus",
            "--enable-mad",
            "--disable-live",
            "--disable-cdparanoia",
            "--disable-enca",
            "--disable-libcdio",
            "--disable-toolame",
            "--disable-xmms",
            "--disable-musepack",
            "--disable-x11",
            "--disable-gl",
            "--disable-arts",
            "--disable-lirc",
            "--disable-mng",
            "--disable-gif",
            "--disable-apple-ir"]
    args << "--enable-menu" if build.with? 'osd' or build.with? 'fribidi'
    args << "--disable-fontconfig" \
         << "--disable-freetype" if build.without? 'osd' and build.without? 'fribidi'
    args << "--enable-smb" if build.with? 'smb'
    args << "--enable-debug=gdb3" \
         << "--disable-altivec" if build.with? 'debug'
    args << "--disable-xvid" \
         << "--disable-x264" \
         << "--disable-faac" \
         << "--disable-libdv" \
         << "--disable-twolame" if build.without? "encoders"
    args << "--disable-libschroedinger-lavc" \
         << "--disable-libdirac-lavc" if build.without? "dirac"
    args << "--disable-smb" if build.without? "smb"
    args << "--disable-apple-remote" if build.without? "apple-remote"
    args << "--disable-esd" if build.without? "esd"
    args << "--disable-speex" if build.without? "speex"
    args << "--disable-fribidi" if build.without? "fribidi"
    args << "--disable-libdca" if build.without? "dts"
    args << "--disable-sdl" if build.without? "sdl"
    args << "--disable-liba52" if build.without? "a52"
    args << "--disable-aa" if build.without? "aa"
    args << "--disable-caca" if build.without? "caca"
    args << "--disable-qtx" if MacOS.prefer_64_bit?
    args << "--enable-qtx" if !MacOS.prefer_64_bit?
    args << "--extra-cflags=" + %x[pkg-config --cflags libopenjpeg].chomp if build.with? 'openjpeg'
    return args
  end

  def install
    ENV.O1 if ENV.compiler == :llvm
    ENV.append_to_cflags "-mdynamic-no-pic" if Hardware.is_32_bit? && Hardware::CPU.intel? && ENV.compiler == :clang
    (buildpath/'VERSION').write "devel-r#{version}" + (revision > 0 ? "_#{revision}" : "")

    system "./configure", *configure_args
    system "make", "-j#{ENV.make_jobs}", "mplayer", "mencoder", "V=1"
    system "make", "doc" if build.with? 'html-docs'

    bin.install 'mplayer' => player, 'mencoder' => encoder, 'TOOLS/midentify.sh' => ident
    man1.install 'DOCS/man/en/mplayer.1' => "#{player}.1"
    man1.install_symlink "#{player}.1" => "#{encoder}.1"
    docs.install 'DOCS/HTML' => 'html' if build.with? 'html-docs'
    docs.install 'DOCS/tech', 'AUTHORS', 'LICENSE', 'README', 'Changelog', 'Copyright'

    mv 'etc/example.conf', 'etc/mplayer.conf'
    Pathname.glob('etc/*.conf').each do |src|
      dst = conf/src.basename
      if dst.exist?
        bak = dst.dirname/(dst.basename.to_s + ".bak")
        rm bak if bak.exist?
        cp dst, bak
      end
    end
    conf.install Dir.glob('etc/*.conf')
  end
end

__END__
diff -rupN orig/configure new/configure
--- orig/configure	2015-11-21 12:29:12.000000000 -0800
+++ new/configure	2015-12-07 23:24:16.000000000 -0800
@@ -3088,8 +3088,8 @@ if ppc && ( test "$_altivec" = yes || te
 
     # check if AltiVec is supported by the compiler, and how to enable it
     echocheck "GCC AltiVec flags"
-    if $(cflag_check -maltivec -mabi=altivec) ; then
-    _altivec_gcc_flags="-maltivec -mabi=altivec"
+    if $(cflag_check -faltivec -maltivec -mabi=altivec) ; then
+    _altivec_gcc_flags="-faltivec -maltivec -mabi=altivec"
     # check if <altivec.h> should be included
         if $(header_check altivec.h $_altivec_gcc_flags) ; then
             def_altivec_h='#define HAVE_ALTIVEC_H 1'
@@ -4609,6 +4609,9 @@ echores "$_x11_headers"
 
 
 echocheck "X11"
+if test "$_x11" = yes ; then
+  libs_mplayer="$libs_mplayer -lXext -lX11"
+fi
 if test "$_x11" = auto && test "$_x11_headers" = yes ; then
   for I in "" -L/usr/X11R7/lib -L/usr/local/lib -L/usr/X11R6/lib -L/usr/lib/X11R6 \
            -L/usr/X11/lib -L/usr/lib32 -L/usr/openwin/lib -L/usr/local/lib64 -L/usr/X11R6/lib64 \
@@ -6561,6 +6564,9 @@ if test "$_tremor" = auto; then
   _tremor=no
   statement_check tremor/ivorbiscodec.h 'vorbis_synthesis(0, 0)' -logg -lvorbisidec && _tremor=yes && _libvorbis=no
 fi
+if test "$_libvorbis" = yes; then
+  vorbislibs=$($_pkg_config --libs vorbisenc vorbis)
+fi
 if test "$_libvorbis" = auto; then
   _libvorbis=no
   for vorbislibs in '-lvorbisenc -lvorbis -logg' '-lvorbis -logg' ; do
@@ -6995,6 +7001,7 @@ fi
 if test "$_qtx" = yes ; then
     def_qtx='#define CONFIG_QTX_CODECS 1'
     win32 && _qtx_codecs_win32=yes && def_qtx_win32='#define CONFIG_QTX_CODECS_WIN32 1'
+    darwin && extra_ldflags="$extra_ldflags -framework Carbon -framework QuickTime" && def_quicktime='#define CONFIG_QUICKTIME 1'
     codecmodules="qtx $codecmodules"
     darwin || win32 || _qtx_emulation=yes
 else
diff -rupN orig/ffmpeg/configure new/ffmpeg/configure
--- orig/ffmpeg/configure	2015-12-07 23:07:32.000000000 -0800
+++ new/ffmpeg/configure	2015-12-07 23:23:43.000000000 -0800
@@ -4997,7 +4997,7 @@ elif enabled ppc; then
 
     # AltiVec flags: The FSF version of GCC differs from the Apple version
     if enabled altivec; then
-        check_cflags -maltivec -mabi=altivec &&
+        check_cflags -faltivec -maltivec -mabi=altivec &&
         { check_header altivec.h && inc_altivec_h="#include <altivec.h>" ; } ||
         check_cflags -faltivec
 
