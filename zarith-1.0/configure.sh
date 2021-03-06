#! /bin/sh

# configuration script

# This file is part of the Zarith library 
# http://forge.ocamlcore.org/projects/zarith .
# It is distributed under LGPL 2 licensing, with static linking exception.
# See the LICENSE file included in the distribution.
#   
# Copyright (c) 2010-2011 Antoine Miné, Abstraction project.
# Abstraction is part of the LIENS (Laboratoire d'Informatique de l'ENS),
# a joint laboratory by:
# CNRS (Centre national de la recherche scientifique, France),
# ENS (École normale supérieure, Paris, France),
# INRIA Rocquencourt (Institut national de recherche en informatique, France).


# options
installdir='auto'
ocamllibdir='auto'
host='auto'
gmp='auto'
perf='no'

# should we make the following auto-detected or configurable?
if test -n "$CC"; then
  cc="$CC"
  ccopt="$CFLAGS"
else
  cc='gcc'
  ccopt="-O3 -Wall -Wextra $CFLAGS"
fi
ar='ar'
ocaml='ocaml'
ocamlc='ocamlc'
ocamlopt='ocamlopt'
ocamlmklib='ocamlmklib'
ocamldep='ocamldep'
ocamldoc='ocamldoc'
ccinc="$CPPFLAGS"
cclib="$LDFLAGS"
asopt=''
ccdef=''
mlflags="$OCAMLFLAGS"
mloptflags="$OCAMLOPTFLAGS"
mlinc="$OCAMLINC"

# sanitize
LC_ALL=C
export LC_ALL
unset IFS


# help
help()
{
    cat <<EOF
usage: configure [options]

where options include:
  -installdir dir      installation directory
  -ocamllibdir dir     ocaml library directory
  -host arch           host type, for platform-specific asm code
  -noasm               disable platform-specific asm code
  -gmp                 use GMP library (default if found)
  -mpir                use MPIR library instead of GMP
  -perf                enable performance statistics

Environment variables that affect configuration:
  CC                   C compiler to use (default: gcc)
  CFLAGS               extra flags to pass to the C compiler
  CPPFLAGS             extra includes, e.g. -I/path/to/gmp/include
  LDFLAGS              extra link flags, e.g. -L/path/to/gmp/lib
  OCAMLFLAGS           extra flags to pass to the ocamlc Caml compiler
  OCAMLOPTFLAGS        extra flags to pass to the ocamlopt Caml compiler
  OCAMLINC             extra includes to pass to the Caml compilers
EOF
    exit
}

# parse arguments
while : ; do
    case "$1" in
        "") 
            break;;
        -installdir|--installdir)
            installdir="$2"
            shift;;
        -ocamllibdir|---ocamllibdir)
            ocamllibdir="$2"
            shift;;
        -host|--host)
            host="$2"
            shift;;
        -noasm|--no-asm)
            host='none';;
        -help|--help)
            help;;
        -gmp|--gmp)
            gmp='gmp';;
        -mpir|--mpir)
            gmp='mpir';;
        -perf|--perf)
            perf='yes';;
        *)
            echo "unknown option $1, try -help"
            exit 2;;
    esac
    shift
done

if test "$perf" = "yes"; then ccdef="-DZ_PERF_COUNTER $ccdef"; fi

echo_n()
{
    echo "$1" | tr -d '\012'
}

# checking binaries in $PATH

searchbin()
{
    echo_n "binary $1: "
    IFS=':'
    for i in $PATH
    do
        if test -z "$i"; then i='.'; fi
        if test -x $i/$1; then echo "found in $i"; unset IFS; return 1; fi
    done
    echo "not found"
    unset IFS
    return 0
}

searchbinreq()
{
    searchbin $1
    if test $? -eq 0; then echo "required program $1 not found"; exit 2; fi
}


# checking includes and libraries

checkinc()
{
    echo_n "include $1: "
    rm -f tmp.c tmp.o
    echo "#include <$1>" > tmp.c
    echo "int main() { return 1; }" >> tmp.c
    r=1
    $cc $ccopt $ccinc -c tmp.c -o tmp.o >/dev/null 2>/dev/null || r=0
    if test ! -f tmp.o; then r=0; fi
    rm -f tmp.c tmp.o
    if test $r -eq 0; then echo "not found"; else echo "found"; fi
    return $r
}

checklib()
{
    echo_n "library $1: "
    rm -f tmp.c tmp.out
    echo "int main() { return 1; }" >> tmp.c
    r=1
    $cc $ccopt $cclib tmp.c -l$1 -o tmp.out >/dev/null 2>/dev/null || r=0
    if test ! -x tmp.out; then r=0; fi
    rm -f tmp.c tmp.o tmp.out
    if test $r -eq 0; then echo "not found"; else echo "found"; fi
    return $r
}

checkcc()
{
    echo_n "checking compilation with $cc $ccopt: "
    rm -f tmp.c tmp.out
    echo "int main() { return 1; }" >> tmp.c
    r=1
    $cc $ccopt tmp.c -o tmp.out >/dev/null 2>/dev/null || r=0
    if test ! -x tmp.out; then r=0; fi
    rm -f tmp.c tmp.o tmp.out
    if test $r -eq 0; then echo "not working"; else echo "working"; fi
    return $r
}


# check required programs

searchbinreq $ocaml
searchbinreq $ocamlc
searchbinreq $ocamlopt
searchbinreq $ocamldep
searchbinreq $ocamlmklib
searchbinreq $ocamldoc
searchbinreq $cc
searchbinreq $ar
searchbinreq perl


# check C compiler

checkcc
if test $? -eq 0; then
    # try again with no options
    ccopt=''
    checkcc
    if test $? -eq 0; then echo "cannot compile and link program"; exit 2; fi
fi


# directories

if test "$ocamllibdir" = "auto"; then ocamllibdir=`ocamlc -where`; fi

# fails on Cygwin:
# if test ! -f "$ocamllibdir/caml/mlvalues.h"
# then echo "cannot find OCaml libraries in $ocamllibdir"; exit 2; fi
ccinc="-I$ocamllibdir $ccinc"
checkinc "caml/mlvalues.h"
if test $? -eq 0; then echo "cannot include caml/mlvalues.h"; exit 2; fi


# installation method

searchbin ocamlfind
if test $? -eq 1; then 
    instmeth='findlib'
    if test "$installdir" = "auto"
    then installdir=`ocamlfind printconf destdir`; fi
else
    searchbin install
    if test $? -eq 1; then instmeth='install'
    else echo "no installation method found"; exit 2; fi
    if test "$installdir" = "auto"; then installdir="$ocamllibdir"; fi
fi


# detect OCaml's word-size

echo "print_int (Sys.word_size);;" > tmp.ml
wordsize=`ocaml tmp.ml`
echo "OCaml's word size is $wordsize"
rm -f tmp.ml


# auto-detect host

if test "x$host" = 'xauto'; then 
    searchbin uname
    if test $? -eq 0; then host='none'
    else host=`. ./config.guess`
    fi
fi


# set arch from host

arch='none'
case $host in
    x86_64-*linux-gnu)
        ccdef="-DZ_ELF $ccdef"
        arch='x86_64';;
    i686-*linux-gnu)
        ccdef="-DZ_ELF $ccdef"
        arch='i686';;
    i686-*cygwin)
        if test "x$wordsize" = "x64"; then
            ccdef="-DZ_COFF $ccdef"
            arch='x86_64_mingw64'
        else
            ccdef="-DZ_UNDERSCORE_PREFIX -DZ_COFF $ccdef"
            arch='i686'
        fi
	;;
    i686-*darwin* | x86_64-*darwin*)
        ccdef="-DZ_UNDERSCORE_PREFIX -DZ_MACOS $ccdef"
        if test "x$wordsize" = "x64"; then
            ccopt="-arch x86_64 $ccopt"
            asopt="-arch x86_64 $asopt"
            arch='x86_64'
            checkcc
        else
            ccopt="-arch i386 $ccopt"
            asopt="-arch i386 $asopt"
            arch='i686'
            checkcc
        fi
        ;;
    none)
        ;;
    *) 
        echo "unknown host $host";;
esac

if test "$arch" != 'none'; then
    if test ! -f "caml_z_${arch}.S"; then arch='none'; fi
fi


# check GMP, MPRI

if test "$gmp" = 'gmp' -o "$gmp" = 'auto'; then
    checkinc gmp.h
    if test $? -eq 1; then
        checklib gmp
        if test $? -eq 1; then 
            gmp='OK'
            cclib="$cclib -lgmp"
            ccdef="-DHAS_GMP $ccdef"
        fi
    fi
fi
if test "$gmp" = 'mpir' -o "$gmp" = 'auto'; then
    checkinc mpir.h
    if test $? -eq 1; then
        checklib mpir
        if test $? -eq 1; then 
            gmp='OK'
            cclib="$cclib -lmpir"
            ccdef="-DHAS_MPIR $ccdef"
        fi
    fi
fi
if test "$gmp" != 'OK'; then echo "cannot find GMP nor MPIR"; exit 2; fi


# OCaml version

case `ocamlc -version` in
    3.10* | 3.11* | 3.12.0*)
        ;;
    3.12.* | 3.1*)
        echo "extended comparison found!"
        ccdef="-DZ_OCAML_COMPARE_EXT $ccdef"
        ;;
    *)
        ;;
esac



# dump Makefile

cat > Makefile.orig <<EOF
# generated by ./configure

CC=$cc
OCAMLC=$ocamlc
OCAMLOPT=$ocamlopt
OCAMLDEP=$ocamldep
OCAMLMKLIB=$ocamlmklib
OCAMLDOC=$ocamldoc
OCAMLFLAGS=$mlflags
OCAMLOPTFLAGS=$mloptflags
OCAMLINC=$mlinc
CFLAGS=$ccinc $ccdef $ccopt
ASFLAGS=$ccdef $asopt
LIBS=$cclib
ARCH=$arch
INSTALLDIR=$installdir
AR=$ar
INSTALL=install
OCAMLFIND=ocamlfind
INSTMETH=$instmeth

include project.mak
EOF


# dump summary

cat <<EOF

detected configuration:

  asm path:             $arch
  defines:              $ccdef
  libraries:            $cclib
  C options:            $ccopt
  asm options           $asopt
  installation path:    $installdir
  installation method   $instmeth

configuration successful!
now type "make" to build
then type "make install" or "sudo make install" to install
EOF

