#!/bin/sh

msg() { echo $@ >&2 ; }
die() { exit 1 ; }

if ! test -n "$TGT" -a -d "$TGT"; then
  msg "Target directory does not exist" ; die
fi

if ! test -f "$FILE" ; then
  msg "FILE not found" ; die
fi

MIME=`cat $FILE | sed -n 's/.*MIME:\([a-zA-Z0-9/-_]\+\)[^a-zA-Z0-9/_-]*.*/\1/gp'`
if test -z "$MIME" ; then
  F=`which file`
  if test -x "$F" ; then
    MIME=`$F --mime-type $FILE | awk '{print $2}'`
  fi
fi
if test -z "$MIME" ; then
  MIME="application/data"
fi

test -z "$LD" && LD=`which ld`
test -z "$CC" && CC=`which gcc`

TMP=`mktemp -d`
msg "Creating temp dir $TMP"

ff=$FILE

if test -z "$URE_MODULE_NAME" ; then
  msg "URE_MODULE_NAME \(PATTERN\) is not defined" ; die
fi
f=$URE_MODULE_NAME

(
cp $ff $TMP/${f} && cd $TMP && $LD -r -b binary -o $TMP/${f}.bin.o $f
)

cat >$TMP/${f}.c <<EOF
// Thanks, http://stupefydeveloper.blogspot.ru/2008/08/cc-embed-binary-data-into-elf.html
#include <urweb.h>
#include <stdio.h>
extern int _binary_${f}_start;
extern int _binary_${f}_size;
uw_Basis_blob  uw_${f}_c_binary (uw_context ctx, uw_unit unit)
{
  uw_Basis_blob blob;
  blob.data = (char*)&_binary_${f}_start;
  blob.size = (size_t)&_binary_${f}_size;
  return blob;
}
EOF

cat >$TMP/${f}.h <<EOF
#include <urweb.h>
uw_Basis_blob uw_${f}_c_binary (uw_context ctx, uw_unit unit);
EOF

if ! test -d "$UR_INCLUDE" ; then
  msg "UR_INCLUDE \($UR_INCLUDE\) is not a directory" ; die
fi

$CC -c -I $UR_INCLUDE -o $TMP/${f}.o $TMP/${f}.c

cat >$TMP/${f}_c.urs <<EOF
val binary : unit -> transaction blob
EOF

cat >$TMP/${f}.urs <<EOF
val binary : unit -> transaction blob
${URE_JS_DECLS}
val blobpage : unit -> transaction page
EOF

JSNAMES=`IFS= ; echo $URE_JS_DECLS | awk '{print $2}'`
cat >$TMP/${f}.ur <<EOF
val binary = ${f}_c.binary
`for fun in ${JSNAMES} ; do echo "val $fun = ${f}_js.$fun" ; done`
`if test -n "$MIME" ; then 
    echo "fun blobpage {} =" ;
    echo "  b <- binary ();" ;
    echo "  returnBlob b (blessMime \"$MIME\")" ;
fi`
EOF

cat >$TMP/${f}_js.urs <<EOF
${URE_JS_DECLS}
EOF

cat >$TMP/${f}.urp <<EOF
ffi ${f}_c
ffi ${f}_js
include ${f}.h
link ${f}.o
link ${f}.bin.o
`for n in $JSNAMES ; do echo "jsFunc ${f}_js.${n} = ${n}"; done`

${f}
EOF

mv -ft $TGT $TMP/*
rm -r "$TMP"

echo $TGT/${f}.urp

