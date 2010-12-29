#!/bin/bash

srcdir=`dirname $0`

mkdir -p includes vapi

mkdir -p m4
autoreconf -v --install || exit 1

$srcdir/configure $@
