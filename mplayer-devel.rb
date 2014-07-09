require 'formula'

class MPlayerDevelDownloadStrategy < SubversionDownloadStrategy
  # custom downloader handles getting the right revisions of various
  # other things in one shot before patch phase occurs.

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
  # currently unused helper that when added as a depenency will cause
  # the build to immediately abort (unless env BUILD_BROKEN_MPLAYER=yes).
  # this was a courtesy to prevent accidentally installing 1000 deps for
  # a package that was, at the time, not working yet.
  fatal true
  satisfy { ENV['BUILD_BROKEN_MPLAYER'] == 'yes' }
  def message; "This formula is disabled (still a work in progress)" end
end

class MplayerDevel < Formula
  # a more rigorous attempt to produce a fully-featured mplayer similar to the
  # one in macports mplayer-devel. the official mplayer formula is simpler, but
  # woefully inaequate.

  homepage 'http://www.mplayerhq.hu/'
  conflicts_with 'mplayer', :because => 'Provides the same binaries.'
  version "36449"

  url "svn://svn.mplayerhq.hu/mplayer/trunk", :using => MPlayerDevelDownloadStrategy,
    :mplayer_rev => "#{version}",
    :libdvd_rev => "1257",
    :ffmpeg_ref => "09887096734eabaac5454b3fb5e4489457ac9434"

  # all the patches from various places (macports, inreplace stuff in other
  # formulas) rolled up and applied at once.
  patch :DATA

  # use similar options to macports variants, except make +osd/+extras on by default
  option 'without-osd', 'Disable on-screen display (menus, etc)'
  option 'without-encoders', 'Build without common encoders (x264, xvid, etc.)'
  option 'with-openjpeg', 'Enable OpenJPEG support (currently broken)'
  option 'with-debug', 'Compile with debugging symbols'
  option 'with-esd', 'Enable EsounD audio output'

  # XXX small speed bump for careless people to avoid building all the things. remove later.
  depends_on FormulaHamstringer

  depends_on 'git' => :build
  depends_on 'subversion' => :build
  depends_on 'pkg-config' => :build
  depends_on 'yasm' => :build

  # XXX totally untested, i don't have mavericks.
  depends_on "gcc" if MacOS.version >= :mountain_lion

  # XXX i'm not sure how these work. the zlib dep added a --with-zlib option,
  # but it still doesn't link against it if i specify. not sure i should care.
  depends_on 'libiconv' => :optional
  depends_on 'ncurses' => :optional
  depends_on 'zlib' => :optional

  depends_on 'lame'
  depends_on 'libass'
  depends_on 'libjpeg'
  depends_on 'libmad'
  depends_on 'libogg'
  depends_on 'liboil'
  depends_on 'libpng'
  depends_on 'libvorbis'
  depends_on 'lzo'
  depends_on 'opus'
  depends_on 'theora'

  # XXX this seems to not get linked
  if build.with? 'openjpeg'
    depends_on 'openjpeg'
  end

  if build.with? 'esd'
    depends_on 'esound'
  end

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

  fails_with :clang do
    build 211
    cause 'Inline asm errors during compile on 32bit Snow Leopard.'
  end unless MacOS.prefer_64_bit?

  def install
    args = ["--prefix=#{prefix}", "--cc=#{ENV.cc}", "--host-cc=#{ENV.cc}", "--enable-png", "--enable-jpeg",
            "--enable-liblzo", "--enable-theora", "--enable-libvorbis", "--enable-libopus", "--enable-mad",
            "--disable-smb", "--disable-live", "--disable-cdparanoia", "--disable-fribidi", "--disable-enca",
            "--disable-libcdio", "--disable-speex", "--disable-toolame", "--disable-xmms", "--disable-musepack",
            "--disable-sdl", "--disable-aa", "--disable-caca", "--disable-x11", "--disable-gl", "--disable-arts",
            "--disable-lirc", "--disable-mng", "--disable-libdirac-lavc",
            "--disable-libschroedinger-lavc", "--disable-liba52", "--disable-gif", "--disable-apple-remote"]

    if MacOS.prefer_64_bit?
      args << "--disable-qtx"
      arch = "x86_64"
    else
      args << "--enable-qtx"
      arch = "i386"
    end
    if build.with? 'osd'
      args << "--enable-menu"
    else
      args << "--disable-fontconfig" << "--disable-freetype"
    end

    args += ["--disable-xvid", "--disable-x264", "--disable-faac", "--disable-libdv", "--disable-twolame"] if build.without? 'encoders'
    args << '--enable-debug=gdb3' << '--disable-altivec' if build.with? 'debug'
    args << "--disable-esd" if build.without? 'esd'
    args << "--target=#{arch}-Darwin"

    system "./configure", *args

    ENV.O1 if ENV.compiler == :llvm
    ENV.append_to_cflags "-mdynamic-no-pic" if Hardware.is_32_bit? && Hardware::CPU.intel? && ENV.compiler == :clang
    system "make"

    # XXX remove this when finishing up.
    odie "aborting before insstall phase"
    system "make install"
  end
end

__END__
diff -rupN original/VERSION patched/VERSION
--- original/VERSION	1969-12-31 16:00:00.000000000 -0800
+++ patched/VERSION	2014-07-09 02:55:48.000000000 -0700
@@ -0,0 +1 @@
+36449
diff -rupN original/configure patched/configure
--- original/configure	2013-09-14 03:57:24.000000000 -0700
+++ patched/configure	2014-07-09 02:54:15.000000000 -0700
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
 
diff -rupN original/ffmpeg/configure patched/ffmpeg/configure
--- original/ffmpeg/configure	2014-07-08 14:56:26.000000000 -0700
+++ patched/ffmpeg/configure	2014-07-08 15:27:34.000000000 -0700
@@ -3915,7 +3915,7 @@ elif enabled ppc; then
         if ! enabled_any pic ppc64; then
             nogas=warn
         fi
-        check_cflags -maltivec -mabi=altivec &&
+        check_cflags -faltivec -maltivec -mabi=altivec &&
         { check_header altivec.h && inc_altivec_h="#include <altivec.h>" ; } ||
         check_cflags -faltivec
 
diff -rupN original/ffmpeg/libavutil/mem.h patched/ffmpeg/libavutil/mem.h
--- original/ffmpeg/libavutil/mem.h	2014-07-08 14:56:26.000000000 -0700
+++ patched/ffmpeg/libavutil/mem.h	2014-07-08 15:17:09.000000000 -0700
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
+++ patched/libvo/vo_corevideo.h	2014-07-08 15:10:26.000000000 -0700
@@ -26,6 +26,7 @@
 #import <Cocoa/Cocoa.h>
 #import <QuartzCore/QuartzCore.h>
 #import <Carbon/Carbon.h>
+#import <OpenGL/gl.h>
 #import "osx_objc_common.h"
 
 // MPlayer OS X VO Protocol
diff -rupN original/libvo/vo_corevideo.m patched/libvo/vo_corevideo.m
--- original/libvo/vo_corevideo.m	2013-07-15 18:33:46.000000000 -0700
+++ patched/libvo/vo_corevideo.m	2014-07-08 15:11:25.000000000 -0700
@@ -25,6 +25,7 @@
 #include <sys/mman.h>
 #include <unistd.h>
 #include <CoreServices/CoreServices.h>
+#include <OpenGL/gl.h>
 //special workaround for Apple bug #6267445
 //(OSServices Power API disabled in OSServices.h for 64bit systems)
 #ifndef __POWER__
