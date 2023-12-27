#!/usr/bin/sh
## Copyright (C) 2023, csdvrx, MIT licensed
# Basic compilation script, with fixes for bintfmt

# >>>>>>>>>>>>>>>>> DO NOT EDIT THIS PART  >>>>>>>>>>>>>>>>> 

## Path declaration and cosmocc+cosmos check
export COSMOCC=/opt/cosmocc
export COSMOS=/opt/cosmos
# Was "https://cosmo.zip/pub/cosmocc/cosmocc.zip"
COSMOCCZIP="https://cosmo.zip/pub/cosmos/zip/cosmocc.zip"
COSMOSZIP="https://cosmo.zip/pub/cosmos/zip/cosmos.zip"
[ -d ${COSMOCC} ] \
 && [ -d ${COSMOS} ] \
 && echo "Using cosmocc from ${COSMOCC} and cosmos from ${COSMOS}" \
 || echo "Download then install into /opt these 2 zip: ${COSMOCCZIP} ${COSMOSZIP}"
[ -d ${COSMOCC}/bin ] \
 || exit 1
# TODO: could wget and unzip that under sudo

## Intelligently avoid WSL and Ubuntu "going apeshit" over binfmt:
# just add if the entries are missing, since it uses the most recent entries
BINFMTMISC="/proc/sys/fs/binfmt_misc/"
[ -d ${BINFMTMISC} ] \
 || echo "No binfmt_misc support to tweak"
[ -z "${MACHINE}" ] \
 && [ -x /usr/bin/uname ] \
 && export MACHINE=$( /usr/bin/uname -a )
[ -z "${APE}" ] \
 && [ -f "${COSMOCC}/bin/ape-${APE}.elf" ] \
 && APE="${COSMOCC}/bin/ape-${APE}.elf"
[ -f "${APE}" ] \
 && [ -f ${BINFMTMISC}/register ] \
 && [ "$(ls ${BINFMTMISC}/APE*| wc -l)" -le 1 ] \
 && DOBINFMT=1
[ -n "${DOBINFMT}" ] \
 && id | sed -e 's/gid.*//g' | grep "id=0" \
 && echo "# Doing:\n echo ':APE:M::MZqFpD::$APE:' > ${BINFMTMISC}/register" \
 && echo ":APE:M::MZqFpD::$APE:" > ${BINFMTMISC}/register \
 && echo "# Doing:\n echo ':APE-jart:M::jartsr::$APE:' > ${BINFMTMISC}/register" \
 && echo ":APE-jart:M::jartsr::$APE:" > ${BINFMTMISC}/register

## Using cosmocc directly in the stub below for a 1 step process instead of:
# 1. compile with x86_64-unknown-cosmo-cc and save the elf binary output
# 2. recompile with aarch64-unknown-cosmo-cc and save the elf binary output
# 3. link both outputs with apelink multi-platform assembler like
# apelink -o binary.com -l $COSMOCC/bin/ape-x86_64.elf -l $COSMOCC/bin/ape-aarch64.elf -M $COSMOCC/bin/ape-m1.c binary.aarch64.elf binary.x86-64.elf
# This is easier and nicer:
export PATH=$PATH:${COSMOCC}/bin:${COSMOCC}/libexec/gcc/
export CC="cosmocc -I${COSMOS}/include -L${COSMOS}/lib"
export CXX="cosmoc++ -I{$COSMOS}/include -L${COSMOS}/lib"
export PKG_CONFIG="pkg-config --with-path=/opt/cosmos/lib/pkgconfig"
export INSTALL="cosmoinstall"
export AR="cosmoar"

# <<<<<<<<<<<<<<<<< DO NOT EDIT THIS PART  <<<<<<<<<<<<<<<<< 
#
# But please edit anything below as needed

[ -x ./configure ] \
 && ./configure --prefix=${COSMOS}/x86_64

[ -f ./Makefile ] \
 && make -j 2
