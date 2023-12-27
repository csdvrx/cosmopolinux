#!/bin/sh
export COSMOCC=/opt/cosmocc
export PATH=$PATH:$COSMOCC/bin:$COSMOCC/libexec/gcc/
# compile x86-64
export CC=x86_64-unknown-cosmo-cc
export CXX=x86_64-unknown-cosmo-c++
# usually ./configure --prefix=/opt/cosmos/x86_64
make -j
cp fzy fzy.x86-64.elf
# compile aarch64
export CC=aarch64-unknown-cosmo-cc
export CXX=aarch64-unknown-cosmo-c++
make -j
cp fzy fzy.aarch64.elf
# multi-platform assembler
apelink -o fzy.com -l $COSMOCC/bin/ape-x86_64.elf -l $COSMOCC/bin/ape-aarch64.elf -M $COSMOCC/bin/ape-m1.c fzy.aarch64.elf fzy.x86-64.elf
# we're no longer using .com
cp fzy.com fzy
# usually make install
