require 'formula'

class BashCompletion2Patched < Formula
  homepage 'http://bash-completion.alioth.debian.org/'
  url 'http://ftp.de.debian.org/debian/pool/main/b/bash-completion/bash-completion_2.1.orig.tar.bz2'
  sha256 '2b606804a7d5f823380a882e0f7b6c8a37b0e768e72c3d4107c51fbe8a46ae4f'
  revision 1

  conflicts_with 'bash-completion', 'bash-completion2',
    :because => 'there can be only one'

  # roll up all the patches, including still-pending fixes for bash-4.3
  # these only exist in debian and ubuntu, not upstream, currently.
  patch :DATA

  def compdir
    HOMEBREW_PREFIX/'share/bash-completion/completions'
  end

  def install
    system "./configure", "--prefix=#{prefix}", "--sysconfdir=#{etc}"
    ENV.deparallelize
    system "make install"

    unless (compdir/'brew').exist?
      compdir.install_symlink HOMEBREW_CONTRIB/'brew_bash_completion.sh' => 'brew'
    end
  end

  def caveats; <<-EOS.undent
    Add the following to your ~/.bash_profile:
      if [ -f $(brew --prefix)/share/bash-completion/bash_completion ]; then
        . $(brew --prefix)/share/bash-completion/bash_completion
      fi

      Homebrew's own bash completion script has been linked into
        #{compdir}
      bash-completion will automatically source it when you invoke `brew`.

      Any completion scripts in #{Formula["bash-completion"].compdir}
      will continue to be sourced as well.
    EOS
  end
end

__END__
diff -rupN bash-completion-2.1.orig/bash_completion bash-completion-2.1/bash_completion
--- bash-completion-2.1.orig/bash_completion	2013-04-05 03:55:51.000000000 -0700
+++ bash-completion-2.1/bash_completion	2014-07-05 12:42:12.393163723 -0700
@@ -536,13 +536,24 @@ __ltrim_colon_completions()
 # @param $2  Name of variable to return result to
 _quote_readline_by_ref()
 {
-    if [[ $1 == \'* ]]; then
+    if [ -z "$1" ]; then
+        # avoid quoting if empty
+        printf -v $2 %s "$1"
+    elif [[ $1 == \'* ]]; then
         # Leave out first character
         printf -v $2 %s "${1:1}"
+    elif [[ $1 == ~* ]]; then
+        # avoid escaping first ~
+        printf -v $2 ~%q "${1:1}"
     else
         printf -v $2 %q "$1"
     fi
 
+    # Replace double escaping ( \\ ) by single ( \ )
+    # This happens always when argument is already escaped at cmdline,
+    # and passed to this function as e.g.: file\ with\ spaces
+    [[ ${!2} == *\\* ]] && printf -v $2 %s "${1//\\\\/\\}"
+
     # If result becomes quoted like this: $'string', re-evaluate in order to
     # drop the additional quoting.  See also: http://www.mail-archive.com/
     # bash-completion-devel@lists.alioth.debian.org/msg01942.html
@@ -707,7 +718,7 @@ _init_completion()
         fi
     done
 
-    [[ $cword -eq 0 ]] && return 1
+    [[ $cword -le 0 ]] && return 1
     prev=${words[cword-1]}
 
     [[ ${split-} ]] && _split_longopt && split=true
@@ -825,7 +836,8 @@ _mac_addresses()
     # - ifconfig on Linux: HWaddr or ether
     # - ifconfig on FreeBSD: ether
     # - ip link: link/ether
-    COMPREPLY+=( $( { ifconfig -a || ip link show; } 2>/dev/null | sed -ne \
+    COMPREPLY+=( $( \
+        { LC_ALL=C ifconfig -a || ip link show; } 2>/dev/null | sed -ne \
         "s/.*[[:space:]]HWaddr[[:space:]]\{1,\}\($re\)[[:space:]].*/\1/p" -ne \
         "s/.*[[:space:]]HWaddr[[:space:]]\{1,\}\($re\)[[:space:]]*$/\1/p" -ne \
         "s|.*[[:space:]]\(link/\)\{0,1\}ether[[:space:]]\{1,\}\($re\)[[:space:]].*|\2|p" -ne \
@@ -1284,7 +1296,7 @@ _realcommand()
         elif type -p greadlink > /dev/null; then
             greadlink -f "$(type -P "$1")"
         elif type -p readlink > /dev/null; then
-            readlink -f "$(type -P "$1")"
+            readlink "$(type -P "$1")"
         else
             type -P "$1"
         fi
@@ -1533,23 +1545,28 @@ _known_hosts_real()
 
     # append any available aliases from config files
     if [[ ${#config[@]} -gt 0 && -n "$aliases" ]]; then
-        local hosts=$( sed -ne 's/^[ \t]*[Hh][Oo][Ss][Tt]\([Nn][Aa][Mm][Ee]\)\{0,1\}['"$'\t '"']\{1,\}\([^#*?]*\)\(#.*\)\{0,1\}$/\2/p' "${config[@]}" )
+        local hosts=$( sed -ne 's/^['"$'\t '"']*[Hh][Oo][Ss][Tt]\([Nn][Aa][Mm][Ee]\)\{0,1\}['"$'\t '"']\{1,\}\([^#*?]*\)\(#.*\)\{0,1\}$/\2/p' "${config[@]}" )
         COMPREPLY+=( $( compgen -P "$prefix$user" \
             -S "$suffix" -W "$hosts" -- "$cur" ) )
     fi
 
+    # This feature is disabled because it does not scale to
+    #  larger networks. See:
+    # https://bugs.launchpad.net/ubuntu/+source/bash-completion/+bug/510591
+    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=574950
+
     # Add hosts reported by avahi-browse, if desired and it's available.
-    if [[ ${COMP_KNOWN_HOSTS_WITH_AVAHI:-} ]] && \
-        type avahi-browse &>/dev/null; then
+    #if [[ ${COMP_KNOWN_HOSTS_WITH_AVAHI:-} ]] && \
+        #type avahi-browse &>/dev/null; then
         # The original call to avahi-browse also had "-k", to avoid lookups
         # into avahi's services DB. We don't need the name of the service, and
         # if it contains ";", it may mistify the result. But on Gentoo (at
         # least), -k wasn't available (even if mentioned in the manpage) some
         # time ago, so...
-        COMPREPLY+=( $( compgen -P "$prefix$user" -S "$suffix" -W \
-            "$( avahi-browse -cpr _workstation._tcp 2>/dev/null | \
-                 awk -F';' '/^=/ { print $7 }' | sort -u )" -- "$cur" ) )
-    fi
+        #COMPREPLY+=( $( compgen -P "$prefix$user" -S "$suffix" -W \
+        #    "$( avahi-browse -cpr _workstation._tcp 2>/dev/null | \
+        #         awk -F';' '/^=/ { print $7 }' | sort -u )" -- "$cur" ) )
+    #fi
 
     # Add hosts reported by ruptime.
     COMPREPLY+=( $( compgen -W \
@@ -1867,7 +1884,8 @@ _install_xspec '!*.@(gif|jp?(e)g|tif?(f)
 _install_xspec '!*.@(@(?(e)ps|?(E)PS|pdf|PDF)?(.gz|.GZ|.bz2|.BZ2|.Z))' gv ggv kghostview
 _install_xspec '!*.@(dvi|DVI)?(.@(gz|Z|bz2))' xdvi kdvi
 _install_xspec '!*.dvi' dvips dviselect dvitype dvipdf advi dvipdfm dvipdfmx
-_install_xspec '!*.[pf]df' acroread gpdf xpdf
+_install_xspec '!*.[pf]df' acroread gpdf
+_install_xspec '!*.@(pdf|fdf)?(.@(gz|xz|Z|bz2))' xpdf
 _install_xspec '!*.@(?(e)ps|pdf)' kpdf
 _install_xspec '!*.@(okular|@(?(e|x)ps|?(E|X)PS|[pf]df|[PF]DF|dvi|DVI|cb[rz]|CB[RZ]|djv?(u)|DJV?(U)|dvi|DVI|gif|jp?(e)g|miff|tif?(f)|pn[gm]|p[bgp]m|bmp|xpm|ico|xwd|tga|pcx|GIF|JP?(E)G|MIFF|TIF?(F)|PN[GM]|P[BGP]M|BMP|XPM|ICO|XWD|TGA|PCX|epub|EPUB|odt|ODT|fb?(2)|FB?(2)|mobi|MOBI|g3|G3|chm|CHM)?(.?(gz|GZ|bz2|BZ2)))' okular
 _install_xspec '!*.pdf' epdfview
@@ -1876,13 +1894,13 @@ _install_xspec '!*.@(?(e)ps|pdf)' ps2pdf
 _install_xspec '!*.texi*' makeinfo texi2html
 _install_xspec '!*.@(?(la)tex|texi|dtx|ins|ltx|dbj)' tex latex slitex jadetex pdfjadetex pdftex pdflatex texi2dvi
 _install_xspec '!*.mp3' mpg123 mpg321 madplay
-_install_xspec '!*@(.@(mp?(e)g|MP?(E)G|wma|avi|AVI|asf|vob|VOB|bin|dat|divx|DIVX|vcd|ps|pes|fli|flv|FLV|fxm|FXM|viv|rm|ram|yuv|mov|MOV|qt|QT|wmv|mp[234]|MP[234]|m4[pv]|M4[PV]|mkv|MKV|og[gmv]|OG[GMV]|t[ps]|T[PS]|m2t?(s)|M2T?(S)|wav|WAV|flac|FLAC|asx|ASX|mng|MNG|srt|m[eo]d|M[EO]D|s[3t]m|S[3T]M|it|IT|xm|XM)|+([0-9]).@(vdr|VDR))?(.part)' xine aaxine fbxine
-_install_xspec '!*@(.@(mp?(e)g|MP?(E)G|wma|avi|AVI|asf|vob|VOB|bin|dat|divx|DIVX|vcd|ps|pes|fli|flv|FLV|fxm|FXM|viv|rm|ram|yuv|mov|MOV|qt|QT|wmv|mp[234]|MP[234]|m4[pv]|M4[PV]|mkv|MKV|og[gmv]|OG[GMV]|t[ps]|T[PS]|m2t?(s)|M2T?(S)|wav|WAV|flac|FLAC|asx|ASX|mng|MNG|srt|m[eo]d|M[EO]D|s[3t]m|S[3T]M|it|IT|xm|XM|iso|ISO)|+([0-9]).@(vdr|VDR))?(.part)' kaffeine dragon
+_install_xspec '!*@(.@(mp?(e)g|MP?(E)G|wma|avi|AVI|asf|vob|VOB|bin|dat|divx|DIVX|vcd|ps|pes|fli|flv|FLV|fxm|FXM|viv|rm|ram|yuv|mov|MOV|qt|QT|wmv|mp[234]|MP[234]|m4[pv]|M4[PV]|mkv|MKV|og[agmvx]|OG[AGMVX]|t[ps]|T[PS]|m2t?(s)|M2T?(S)|wav|WAV|flac|FLAC|asx|ASX|mng|MNG|srt|m[eo]d|M[EO]D|s[3t]m|S[3T]M|it|IT|xm|XM)|+([0-9]).@(vdr|VDR))?(.part)' xine aaxine fbxine
+_install_xspec '!*@(.@(mp?(e)g|MP?(E)G|wma|avi|AVI|asf|vob|VOB|bin|dat|divx|DIVX|vcd|ps|pes|fli|flv|FLV|fxm|FXM|viv|rm|ram|yuv|mov|MOV|qt|QT|wmv|mp[234]|MP[234]|m4[pv]|M4[PV]|mkv|MKV|og[agmvx]|OG[AGMVX]|t[ps]|T[PS]|m2t?(s)|M2T?(S)|wav|WAV|flac|FLAC|asx|ASX|mng|MNG|srt|m[eo]d|M[EO]D|s[3t]m|S[3T]M|it|IT|xm|XM|iso|ISO)|+([0-9]).@(vdr|VDR))?(.part)' kaffeine dragon
 _install_xspec '!*.@(avi|asf|wmv)' aviplay
 _install_xspec '!*.@(rm?(j)|ra?(m)|smi?(l))' realplay
 _install_xspec '!*.@(mpg|mpeg|avi|mov|qt)' xanim
-_install_xspec '!*.@(ogg|m3u|flac|spx)' ogg123
-_install_xspec '!*.@(mp3|ogg|pls|m3u)' gqmpeg freeamp
+_install_xspec '!*.@(og[ag]|m3u|flac|spx)' ogg123
+_install_xspec '!*.@(mp3|og[ag]|pls|m3u)' gqmpeg freeamp
 _install_xspec '!*.fig' xfig
 _install_xspec '!*.@(mid?(i)|cmf)' playmidi
 _install_xspec '!*.@(mid?(i)|rmi|rcp|[gr]36|g18|mod|xm|it|x3m|s[3t]m|kar)' timidity
diff -rupN bash-completion-2.1.orig/bash_completion.sh.in bash-completion-2.1/bash_completion.sh.in
--- bash-completion-2.1.orig/bash_completion.sh.in	2013-04-05 02:43:56.000000000 -0700
+++ bash-completion-2.1/bash_completion.sh.in	2014-07-05 12:37:11.000000000 -0700
@@ -1,5 +1,5 @@
 # Check for interactive bash and that we haven't already been sourced.
-[ -z "$BASH_VERSION" -o -z "$PS1" -o -n "$BASH_COMPLETION_COMPAT_DIR" ] && return
+if [ -n "$BASH_VERSION" -a -n "$PS1" -a -z "$BASH_COMPLETION_COMPAT_DIR" ]; then
 
 # Check for recent enough version of bash.
 bash=${BASH_VERSION%.*}; bmajor=${bash%.*}; bminor=${bash#*.}
@@ -12,3 +12,5 @@ if [ $bmajor -gt 4 ] || [ $bmajor -eq 4
     fi
 fi
 unset bash bmajor bminor
+
+fi
diff -rupN bash-completion-2.1.orig/completions/aptitude bash-completion-2.1/completions/aptitude
--- bash-completion-2.1.orig/completions/aptitude	2013-04-05 03:55:51.000000000 -0700
+++ bash-completion-2.1/completions/aptitude	2014-07-05 12:37:11.000000000 -0700
@@ -26,7 +26,7 @@ _aptitude()
 
     local special i
     for (( i=0; i < ${#words[@]}-1; i++ )); do
-        if [[ ${words[i]} == @(@(|re)install|@(|un)hold|@(|un)markauto|@(dist|full)-upgrade|download|show|forbid-version|purge|remove|changelog|why@(|-not)|keep@(|-all)|build-dep|@(add|remove)-user-tag|versions) ]]; then
+        if [[ ${words[i]} == @(@(|re)install|@(|un)hold|@(|un)markauto|@(dist|full|safe)-upgrade|download|show|forbid-version|purge|remove|changelog|why@(|-not)|keep@(|-all)|build-dep|@(add|remove)-user-tag|versions) ]]; then
             special=${words[i]}
         fi
         #exclude some mutually exclusive options
@@ -38,7 +38,7 @@ _aptitude()
        case $special in
            install|hold|markauto|unmarkauto|dist-upgrade|full-upgrade| \
            download|show|changelog|why|why-not|build-dep|add-user-tag| \
-           remove-user-tag|versions)
+           remove-user-tag|versions|safe-upgrade)
                COMPREPLY=( $( apt-cache pkgnames $cur 2> /dev/null ) )
                return 0
                ;;
@@ -56,7 +56,7 @@ _aptitude()
 
     case $prev in
         # don't complete anything if these options are found
-        autoclean|clean|forget-new|search|safe-upgrade|upgrade|update|keep-all)
+        autoclean|clean|forget-new|search|upgrade|update|keep-all)
             return 0
             ;;
         -S)
diff -rupN bash-completion-2.1.orig/completions/dpkg bash-completion-2.1/completions/dpkg
--- bash-completion-2.1.orig/completions/dpkg	2013-04-05 03:55:51.000000000 -0700
+++ bash-completion-2.1/completions/dpkg	2014-07-05 12:37:11.000000000 -0700
@@ -32,7 +32,7 @@ _comp_dpkg_purgeable_packages()
 }
 }
 
-# Debian dpkg(8) completion
+# Debian dpkg(1) completion
 #
 _dpkg()
 {
@@ -52,17 +52,17 @@ _dpkg()
     fi
 
     case $prev in
-        -c|-i|-A|-I|-f|-e|-x|-X|-W|--install|--unpack|--record-avail| \
+        -c|-i|-A|-I|-f|-e|-x|-X|--install|--unpack|--record-avail| \
         --contents|--info|--fsys-tarfile|--field|--control|--extract| \
-        --show)
-            _filedir '?(u)deb'
+        --vextract)
+            _filedir '?(u|d)deb'
             return 0
             ;;
         -b|--build)
             _filedir -d
             return 0
             ;;
-        -s|-p|-l|--status|--print-avail|--list)
+        -s|-p|-l|-W|--status|--print-avail|--list|--show)
             COMPREPLY=( $( apt-cache pkgnames "$cur" 2>/dev/null ) )
             return 0
             ;;
@@ -85,7 +85,45 @@ _dpkg()
     COMPREPLY=( $( compgen -W '$( _parse_help "$1" )' -- "$cur" ) )
     [[ $COMPREPLY == *= ]] && compopt -o nospace
 } &&
-complete -F _dpkg dpkg dpkg-deb dpkg-query
+complete -F _dpkg dpkg dpkg-query
+
+# Debian dpkg-deb(1) completion
+#
+_dpkg_deb()
+{
+    local cur prev words cword split
+    _init_completion -s || return
+
+    _expand || return 0
+
+    local i=$cword
+
+    # find the last option flag
+    if [[ $cur != -* ]]; then
+        while [[ $prev != -* && $i -ne 1 ]]; do
+            i=$((i-1))
+            prev=${words[i-1]}
+        done
+    fi
+
+    case $prev in
+        -c|-I|-W|-f|-e|-x|-X|-R|--contents|--info|--show|--field|--control| \
+        --extract|--vextract|--raw-extract|--fsys-tarfile)
+            _filedir '?(u|d)deb'
+            return 0
+            ;;
+        -b|--build)
+            _filedir -d
+            return 0
+            ;;
+    esac
+
+    $split && return
+
+    COMPREPLY=( $( compgen -W '$( _parse_help "$1" )' -- "$cur" ) )
+    [[ $COMPREPLY == *= ]] && compopt -o nospace
+} &&
+complete -F _dpkg_deb dpkg-deb
 
 # Debian GNU dpkg-reconfigure(8) completion
 #
diff -rupN bash-completion-2.1.orig/completions/gcc bash-completion-2.1/completions/gcc
--- bash-completion-2.1.orig/completions/gcc	2013-04-05 02:43:56.000000000 -0700
+++ bash-completion-2.1/completions/gcc	2014-07-05 12:37:11.000000000 -0700
@@ -47,8 +47,8 @@ _gcc()
 } &&
 complete -F _gcc gcc g++ g77 gcj gpc &&
 {
-    cc  --version 2>/dev/null | grep -q GCC && complete -F _gcc cc  || :
-    c++ --version 2>/dev/null | grep -q GCC && complete -F _gcc c++ || :
+    cc  --version 2>/dev/null | grep -q 'GCC\|Debian' && complete -F _gcc cc  || :
+    c++ --version 2>/dev/null | grep -q 'GCC\|Debian' && complete -F _gcc c++ || :
 }
 
 # ex: ts=4 sw=4 et filetype=sh
diff -rupN bash-completion-2.1.orig/completions/make bash-completion-2.1/completions/make
--- bash-completion-2.1.orig/completions/make	2013-04-05 03:55:51.000000000 -0700
+++ bash-completion-2.1/completions/make	2014-07-05 12:38:55.521172003 -0700
@@ -20,9 +20,9 @@ function _make_target_extract_script()
     fi
 
     cat <<EOF
-    /^# Make data base/,/^# Files/d             # skip until files section
-    /^# Not a target/,/^$/        d             # skip not target blocks
-    /^${prefix_pat}/,/^$/!        d             # skip anything user dont want
+    /^# Make data base/,/^# Files/d;            # skip until files section
+    /^# Not a target/,/^$/        d;            # skip not target blocks
+    /^${prefix_pat}/,/^$/!        d;            # skip anything user dont want
 
     # The stuff above here describes lines that are not
     #  explicit targets or not targets other than special ones
@@ -30,41 +30,42 @@ function _make_target_extract_script()
     #  should be output.
 
     /^# File is an intermediate prerequisite/ {
-      s/^.*$//;x                                # unhold target
-      d                                         # delete line
+      s/^.*$//;x;                               # unhold target
+      d;                                        # delete line
     }
 
     /^$/ {                                      # end of target block
-      x                                         # unhold target
-      /^$/d                                     # dont print blanks
-      s,^(.{${dirname_len}})(.{${#basename}}[^:/]*/?)[^:]*:.*$,${output},p
-      d                                         # hide any bugs
+      x;                                        # unhold target
+      /^$/d;                                    # dont print blanks
+      s|^\(.\{${dirname_len}\}\)\(.\{${#basename}\}[^:/]*/\{0,1\}\)[^:]*:.*$|${output}|p;
+      d;                                        # hide any bugs
     }
 
-    /^[^#\t:%]+:/ {         # found target block
+    # This pattern includes a literal tab character as \t is not a portable
+    # representation and fails with BSD sed
+    /^[^#	:%]\{1,\}:/ {         # found target block
+      /^\.PHONY:/                 d;            # special target
+      /^\.SUFFIXES:/              d;            # special target
+      /^\.DEFAULT:/               d;            # special target
+      /^\.PRECIOUS:/              d;            # special target
+      /^\.INTERMEDIATE:/          d;            # special target
+      /^\.SECONDARY:/             d;            # special target
+      /^\.SECONDEXPANSION:/       d;            # special target
+      /^\.DELETE_ON_ERROR:/       d;            # special target
+      /^\.IGNORE:/                d;            # special target
+      /^\.LOW_RESOLUTION_TIME:/   d;            # special target
+      /^\.SILENT:/                d;            # special target
+      /^\.EXPORT_ALL_VARIABLES:/  d;            # special target
+      /^\.NOTPARALLEL:/           d;            # special target
+      /^\.ONESHELL:/              d;            # special target
+      /^\.POSIX:/                 d;            # special target
+      /^\.NOEXPORT:/              d;            # special target
+      /^\.MAKE:/                  d;            # special target
 
-      /^\.PHONY:/                 d             # special target
-      /^\.SUFFIXES:/              d             # special target
-      /^\.DEFAULT:/               d             # special target
-      /^\.PRECIOUS:/              d             # special target
-      /^\.INTERMEDIATE:/          d             # special target
-      /^\.SECONDARY:/             d             # special target
-      /^\.SECONDEXPANSION:/       d             # special target
-      /^\.DELETE_ON_ERROR:/       d             # special target
-      /^\.IGNORE:/                d             # special target
-      /^\.LOW_RESOLUTION_TIME:/   d             # special target
-      /^\.SILENT:/                d             # special target
-      /^\.EXPORT_ALL_VARIABLES:/  d             # special target
-      /^\.NOTPARALLEL:/           d             # special target
-      /^\.ONESHELL:/              d             # special target
-      /^\.POSIX:/                 d             # special target
-      /^\.NOEXPORT:/              d             # special target
-      /^\.MAKE:/                  d             # special target
+      /^[^a-zA-Z0-9]/             d;            # convention for hidden tgt
 
-      /^[^a-zA-Z0-9]/             d             # convention for hidden tgt
-
-      h                                         # hold target
-      d                                         # delete line
+      h;                                        # hold target
+      d;                                        # delete line
     }
 
 EOF
@@ -144,7 +145,7 @@ _make()
         local reset=$( set +o | grep -F posix ); set +o posix # for <(...)
         COMPREPLY=( $( LC_ALL=C \
             make -npq "${makef[@]}" "${makef_dir[@]}" .DEFAULT 2>/dev/null | \
-            sed -nrf <(_make_target_extract_script $mode "$cur") ) )
+            sed -nf <(_make_target_extract_script $mode "$cur") ) )
         $reset
 
         if [[ $mode != -d ]]; then
diff -rupN bash-completion-2.1.orig/completions/mplayer bash-completion-2.1/completions/mplayer
--- bash-completion-2.1.orig/completions/mplayer	2013-04-05 03:55:51.000000000 -0700
+++ bash-completion-2.1/completions/mplayer	2014-07-05 12:37:11.000000000 -0700
@@ -26,7 +26,7 @@ _mplayer()
             return 0
             ;;
         -audiofile)
-            _filedir '@(mp3|mpg|ogg|w?(a)v|mid|flac|mka|ape)'
+            _filedir '@(mp3|mpg|og[ag]|w?(a)v|mid|flac|mka|ape)'
             return 0
             ;;
         -font|-subfont)
diff -rupN bash-completion-2.1.orig/helpers/perl bash-completion-2.1/helpers/perl
--- bash-completion-2.1.orig/helpers/perl	2013-04-05 02:43:56.000000000 -0700
+++ bash-completion-2.1/helpers/perl	2014-07-05 12:37:11.000000000 -0700
@@ -23,8 +23,8 @@ sub print_modules_real {
     chdir($dir) or return;
 
     # print each file
-    foreach my $file (glob('*.pm')) {
-        $file =~ s/\.pm$//;
+    foreach my $file (glob('*.{pm,pod}')) {
+        $file =~ s/\.(?:pm|pod)$//;
         my $module = $base . $file;
         next if $module !~ /^\Q$word/;
         next if $seen{$module}++;
