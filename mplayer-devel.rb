require 'formula'

class MPlayerDevelDownloadStrategy < SubversionDownloadStrategy

  def initialize name, resource
    f = Formula['ffmpeg']
    @mplayer_rev = resource.specs.delete(:mplayer_rev)
    @libdvd_rev = resource.specs.delete(:libdvd_rev)
    @ffmpeg_ref = resource.specs.delete(:ffmpeg_ref)
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

  def target *parts
    Pathname.new(File.join(Dir.pwd, *parts))
  end

  def _stage_git name, ref=nil
    dst = target(name)
    quiet_safe_system 'git', 'clone', '--no-checkout', @ffmpeg.cached_download, dst
    dst.cd { quiet_safe_system 'git', 'checkout', '-f', ref } unless ref.nil?
  end

  def _stage_svn name, rev=nil
    args = ['svn', 'export', '--force', '--ignore-externals']
    args << '-r' << rev unless rev.nil?
    quiet_safe_system *args + [@clone.join(name), target(name)]
  end

  def stage
    _stage_svn '.', @mplayer_rev
    _stage_svn 'libdvdnav', @libdvd_rev
    _stage_svn 'libdvdread4', @libdvd_rev
    _stage_git 'ffmpeg', @ffmpeg_ref
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
  version '36449'
  #version "37238"
  revision 2

  url 'svn://svn.mplayerhq.hu/mplayer/trunk',
      :using       => MPlayerDevelDownloadStrategy,
      :mplayer_rev => version,
      :ffmpeg_ref  => "09887096734eabaac5454b3fb5e4489457ac9434",
      :libdvd_rev  => "1257"
  #   :ffmpeg_ref  => "9195c26d454ca750359db87b1127cd4926c536bd",
  #   :libdvd_rev  => "1294"

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
  option 'with-dirac',           'Enable dirac codec support'
  option 'with-aa',              'Enable animated ASCII art video output'
  option 'with-caca',            'Enable animated ASCII art video output'
  option 'without-osd',          'Disable on-screen display (menus, etc)'
  option 'without-encoders',     'Build without common encoders (x264, xvid, etc.)'
  option 'without-apple-remote', 'Disable Apple Infrared Remote support'

  #option 'with-openjpeg',       'Enable OpenJPEG support (currently broken)'
  #depends_on FormulaHamstringer

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
  #depends_on 'openjpeg' if build.with? 'openjpeg'

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
  def lang;    'en'               end
  def gdb;     'gdb3'             end
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
            "--language=#{lang}",
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
    args << "--enable-menu"                  if build.with?    'osd' or  build.with?    'fribidi'
    args << "--disable-fontconfig" \
         << "--disable-freetype"             if build.without? 'osd' and build.without? 'fribidi'
    args << "--enable-smb"                   if build.with?    'smb'
    args << "--enable-debug=#{gdb}" \
         << "--disable-altivec"              if build.with?    'debug'
    args << "--disable-xvid" \
         << "--disable-x264" \
         << "--disable-faac" \
         << "--disable-libdv" \
         << "--disable-twolame"              if build.without? "encoders"
    args << "--disable-smb"                  if build.without? "smb"
    args << "--disable-apple-remote"         if build.without? "apple-remote"
    args << "--disable-esd"                  if build.without? "esd"
    args << "--disable-speex"                if build.without? "speex"
    args << "--disable-fribidi"              if build.without? "fribidi"
    args << "--disable-libdts"               if build.without? "dts"
    args << "--disable-sdl"                  if build.without? "sdl"
    args << "--disable-liba52"               if build.without? "a52"
    args << "--disable-libschroedinger-lavc" \
         << "--disable-libdirac-lavc"        if build.without? "dirac"
    args << "--disable-aa"                   if build.without? "aa"
    args << "--disable-caca"                 if build.without? "caca"

    if MacOS.prefer_64_bit?
      args << "--disable-qtx"
    else
      args << "--enable-qtx"
    end
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
    conf.install Dir.glob('etc/*.conf')
  end
end

__END__
diff -rupN original/configure patched/configure
--- original/configure	2013-09-14 03:57:24.000000000 -0700
+++ patched/configure	2014-07-10 19:01:04.000000000 -0700
@@ -1507,8 +1507,7 @@ if test -e ffmpeg/mp_auto_pull ; then
 fi
 
 if ! test -e ffmpeg ; then
-    echo "No FFmpeg checkout, press enter to download one with git or CTRL+C to abort"
-    read tmp
+    echo "No FFmpeg checkout, attempting to fetch from upstream repository"
     if ! git clone --depth 1 git://source.ffmpeg.org/ffmpeg.git ffmpeg ; then
         rm -rf ffmpeg
         echo "Failed to get a FFmpeg checkout"
@@ -2989,8 +2988,8 @@ if ppc && ( test "$_altivec" = yes || te
 
     # check if AltiVec is supported by the compiler, and how to enable it
     echocheck "GCC AltiVec flags"
-    if $(cflag_check -maltivec -mabi=altivec) ; then
-    _altivec_gcc_flags="-maltivec -mabi=altivec"
+    if $(cflag_check -faltivec -maltivec -mabi=altivec) ; then
+    _altivec_gcc_flags="-faltivec -maltivec -mabi=altivec"
     # check if <altivec.h> should be included
         if $(header_check altivec.h $_altivec_gcc_flags) ; then
             def_altivec_h='#define HAVE_ALTIVEC_H 1'
@@ -4429,6 +4428,9 @@ echores "$_x11_headers"
 
 
 echocheck "X11"
+if test "$_x11" = yes; then
+  libs_mplayer="$libs_mplayer -lXext -lX11"
+fi
 if test "$_x11" = auto && test "$_x11_headers" = yes ; then
   for I in "" -L/usr/X11R7/lib -L/usr/local/lib -L/usr/X11R6/lib -L/usr/lib/X11R6 \
            -L/usr/X11/lib -L/usr/lib32 -L/usr/openwin/lib -L/usr/local/lib64 -L/usr/X11R6/lib64 \
@@ -6441,6 +6443,9 @@ if test "$_tremor" = auto; then
   _tremor=no
   statement_check tremor/ivorbiscodec.h 'vorbis_synthesis(0, 0)' -logg -lvorbisidec && _tremor=yes && _libvorbis=no
 fi
+if test "$_libvorbis" = yes; then
+  vorbislibs=$($_pkg_config --libs vorbisenc vorbis)
+fi
 if test "$_libvorbis" = auto; then
   _libvorbis=no
   for vorbislibs in '-lvorbisenc -lvorbis -logg' '-lvorbis -logg' ; do
@@ -6873,13 +6878,14 @@ if test "$_qtx" = auto ; then
   test "$_win32dll" = yes || test "$quicktime" = yes && _qtx=yes
 fi
 if test "$_qtx" = yes ; then
-    def_qtx='#define CONFIG_QTX_CODECS 1'
-    win32 && _qtx_codecs_win32=yes && def_qtx_win32='#define CONFIG_QTX_CODECS_WIN32 1'
-    codecmodules="qtx $codecmodules"
-    darwin || win32 || _qtx_emulation=yes
+  def_qtx='#define CONFIG_QTX_CODECS 1'
+  win32 && _qtx_codecs_win32=yes && def_qtx_win32='#define CONFIG_QTX_CODECS_WIN32 1'
+  darwin && extra_ldflags="$extra_ldflags -framework Carbon -framework QuickTime" && def_quicktime='#define CONFIG_QUICKTIME 1'
+  codecmodules="qtx $codecmodules"
+  darwin || win32 || _qtx_emulation=yes
 else
-    def_qtx='#undef CONFIG_QTX_CODECS'
-    nocodecmodules="qtx $nocodecmodules"
+  def_qtx='#undef CONFIG_QTX_CODECS'
+  nocodecmodules="qtx $nocodecmodules"
 fi
 echores "$_qtx"
 
@@ -8041,6 +8047,7 @@ extra_ldflags="$extra_ldflags -lm"
 # XML documentation tests
 echocheck "XML catalogs"
 for try_catalog in \
+  /usr/local/etc/xml/catalog \
   /etc/sgml/catalog \
   /usr/share/xml/docbook/*/catalog.xml \
   /opt/local/share/xml/docbook-xml/*/catalog.xml \
@@ -8068,6 +8075,7 @@ fi
 
 echocheck "XML chunked stylesheet"
 for try_chunk_xsl in \
+  /usr/local/opt/docbook-xsl/docbook-xsl/html/chunk.xsl \
   /usr/share/xml/docbook/*/html/chunk.xsl \
   /usr/share/sgml/docbook/stylesheet/xsl/nwalsh/html/chunk.xsl \
   /usr/share/sgml/docbook/yelp/docbook/html/chunk.xsl \
@@ -8084,7 +8092,7 @@ for try_chunk_xsl in \
 done
 
 if test -z "$chunk_xsl"; then
-  chunk_xsl=/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/html/chunk.xsl
+  chunk_xsl=/usr/local/opt/docbook-xsl/docbook-xsl/html/chunk.xsl
   echores "not found, using default"
   fake_chunk_xsl=yes
 else
@@ -8093,6 +8101,7 @@ fi
 
 echocheck "XML monolithic stylesheet"
 for try_docbook_xsl in \
+  /usr/local/opt/docbook-xsl/docbook-xsl/html/docbook.xsl \
   /usr/share/xml/docbook/*/html/docbook.xsl \
   /usr/share/sgml/docbook/stylesheet/xsl/nwalsh/html/docbook.xsl \
   /usr/share/sgml/docbook/yelp/docbook/html/docbook.xsl \
@@ -8109,7 +8118,7 @@ for try_docbook_xsl in \
 done
 
 if test -z "$docbook_xsl"; then
-  docbook_xsl=/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/html/docbook.xsl
+  docbook_xsl=/usr/local/opt/docbook-xsl/docbook-xsl/html/docbook.xsl
   echores "not found, using default"
 else
   echores "docbook.xsl"
@@ -8146,6 +8155,7 @@ EOF
 echocheck "XML DTD"
 #FIXME: This should prefer higher version numbers, not the other way around ..
 for try_dtd in \
+  /usr/local/opt/docbook/docbook/xml/4*/docbookx.dtd \
   /usr/share/xml/docbook/*/dtd/4*/docbookx.dtd \
   /usr/share/xml/docbook/*/docbookx.dtd \
   /usr/share/sgml/docbook/*/docbookx.dtd \
@@ -8161,7 +8171,7 @@ for try_dtd in \
 done
 
 if test -z "$dtd"; then
-  dtd=/usr/share/sgml/docbook/dtd/xml/4.1.2/docbookx.dtd
+  dtd=/usr/local/opt/docbook/docbook/xml/4.1.2/docbookx.dtd
   echores "not found, using default"
 else
   echores "docbookx.dtd"
diff -rupN original/ffmpeg/configure patched/ffmpeg/configure
--- original/ffmpeg/configure	2014-07-10 18:59:12.000000000 -0700
+++ patched/ffmpeg/configure	2014-07-10 19:01:04.000000000 -0700
@@ -3915,7 +3915,7 @@ elif enabled ppc; then
         if ! enabled_any pic ppc64; then
             nogas=warn
         fi
-        check_cflags -maltivec -mabi=altivec &&
+        check_cflags -faltivec -maltivec -mabi=altivec &&
         { check_header altivec.h && inc_altivec_h="#include <altivec.h>" ; } ||
         check_cflags -faltivec
 
diff -rupN original/ffmpeg/libavutil/mem.h patched/ffmpeg/libavutil/mem.h
--- original/ffmpeg/libavutil/mem.h	2014-07-10 18:59:13.000000000 -0700
+++ patched/ffmpeg/libavutil/mem.h	2014-07-10 19:01:04.000000000 -0700
@@ -51,7 +51,7 @@
         static const t __attribute__((aligned(n))) v
 #elif defined(__GNUC__)
     #define DECLARE_ALIGNED(n,t,v)      t __attribute__ ((aligned (n))) v
-    #define DECLARE_ASM_CONST(n,t,v)    static const t av_used __attribute__ ((aligned (n))) v
+    #define DECLARE_ASM_CONST(n,t,v)    __private_extern__ const t av_used __attribute__ ((aligned (n))) v
 #elif defined(_MSC_VER)
     #define DECLARE_ALIGNED(n,t,v)      __declspec(align(n)) t v
     #define DECLARE_ASM_CONST(n,t,v)    __declspec(align(n)) static const t v
diff -rupN original/libvo/vo_corevideo.h patched/libvo/vo_corevideo.h
--- original/libvo/vo_corevideo.h	2013-07-15 18:33:46.000000000 -0700
+++ patched/libvo/vo_corevideo.h	2014-07-10 19:01:04.000000000 -0700
@@ -26,6 +26,7 @@
 #import <Cocoa/Cocoa.h>
 #import <QuartzCore/QuartzCore.h>
 #import <Carbon/Carbon.h>
+#import <OpenGL/gl.h>
 #import "osx_objc_common.h"
 
 // MPlayer OS X VO Protocol
diff -rupN original/libvo/vo_corevideo.m patched/libvo/vo_corevideo.m
--- original/libvo/vo_corevideo.m	2013-07-15 18:33:46.000000000 -0700
+++ patched/libvo/vo_corevideo.m	2014-07-10 19:01:04.000000000 -0700
@@ -25,6 +25,7 @@
 #include <sys/mman.h>
 #include <unistd.h>
 #include <CoreServices/CoreServices.h>
+#include <OpenGL/gl.h>
 //special workaround for Apple bug #6267445
 //(OSServices Power API disabled in OSServices.h for 64bit systems)
 #ifndef __POWER__
