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
  end
end

class MplayerDevel < Formula

  desc "simpler mplayer build"
  homepage "http://www.mplayerhq.hu/"
  version "37559"
  revision 6
  url "svn://svn.mplayerhq.hu/mplayer/trunk", :using => MPlayerDevelDownloadStrategy

  depends_on "pkg-config" => :build
  depends_on "yasm" => :build
  depends_on "freetype"
  depends_on "mad"

  patch :DATA

  def arch
    if MacOS.prefer_64_bit?
      Hardware::CPU.arch_64_bit
    else
      Hardware::CPU.arch_32_bit
    end
  end

  def playername
    "mplayer"
  end

  def conf
    etc/playername
  end

  def docs
    share/"doc"/playername
  end

  def install
    system "./configure", "--disable-debug",
                          "--prefix=#{prefix}",
                          "--bindir=#{bin}",
                          "--datadir=#{docs}",
                          "--mandir=#{man}",
                          "--confdir=#{conf}",
                          "--libdir=#{lib}",
                          "--codecsdir=#{lib}/codecs",
                          "--language=en",
                          "--disable-aa",
                          "--disable-altivec",
                          "--disable-apple-ir",
                          "--disable-apple-remote",
                          "--disable-arts",
                          "--disable-caca",
                          "--disable-cdparanoia",
                          "--disable-enca",
                          "--disable-esd",
                          "--disable-faac",
                          "--disable-fontconfig",
                          "--disable-fribidi",
                          "--disable-gif",
                          "--disable-gl",
                          "--disable-jpeg",
                          "--disable-liba52",
                          "--disable-libcdio",
                          "--disable-libdca",
                          "--disable-libdirac-lavc",
                          "--disable-libdv",
                          "--disable-liblzo",
                          "--disable-libopus",
                          "--disable-libschroedinger-lavc",
                          "--disable-libvorbis",
                          "--disable-lirc",
                          "--disable-live",
                          "--disable-mng",
                          "--disable-musepack",
                          "--disable-png",
                          "--disable-qtx",
                          "--disable-sdl",
                          "--disable-smb",
                          "--disable-speex",
                          "--disable-theora",
                          "--disable-toolame",
                          "--disable-twolame",
                          "--disable-x11",
                          "--disable-x264",
                          "--disable-xmms",
                          "--disable-xvid",
                          "--enable-corevideo",
                          "--enable-coreaudio",
                          "--enable-freetype",
                          "--enable-mad",
                          "--enable-menu"

    system "make", "-j#{ENV.make_jobs}", "mplayer", "V=1"
    bin.install "mplayer" => playername
    man1.install "DOCS/man/en/mplayer.1" => "#{playername}.1"
    docs.install "DOCS/tech", "AUTHORS", "LICENSE", "README", "Changelog", "Copyright"
    mv "etc/example.conf", "etc/#{playername}.conf"
    Pathname.glob("etc/*.conf").each do |src|
      dst = conf/src.basename
      if dst.exist?
        bak = dst.dirname/(dst.basename.to_s + ".bak")
        rm bak if bak.exist?
        cp dst, bak
      end
    end
    conf.install Dir.glob("etc/*.conf")
  end

  test do
    system "true"
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
 
