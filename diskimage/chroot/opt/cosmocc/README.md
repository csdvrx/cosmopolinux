# Cosmopolitan Fat Toolchain 

This directory contains prebuilt binaries of GCC and binutils. There's
two toolchains. The first toolchain targets x86_64 and the second one
targets AARCH64.

What makes this toolchain special is that it contains fat executables
that were linked statically. They'll work on both AMD64 and ARM64 hosts
running Linux / MacOS / Windows / FreeBSD / OpenBSD / NetBSD on x86_64,
and for AARCH64 hots they'll work on Linux and MacOS.

This won't work out of the box like a normal C/C++ compiler. These
binaries are intended to be run by the `cosmocc` and `fatcosmocc`
wrapper scripts which you can find in the Cosmopolitan monorepo at
<https://github.com/jart/cosmopolitan>.

This copy of GCC has been modified. We wrote a 2kLOC patch which gives
the C language the ability to `switch (errno) { case EINVAL: ... }` in
cases where constants like `EINVAL` are linkable symbols. Your code will
be rewritten in such cases to use a series of if statements instead, so
that Cosmopolitan Libc's system constants will work as expected. Our
modifications to GNU GCC are published under the ISC license at
<https://github.com/ahgamut/gcc/tree/portcosmo-11.2>. The binaries you
see here were first published at
<https://github.com/ahgamut/superconfigure/releases/tag/z0.0.16> which
is regularly updated.

Your Cosmopolitan toolchain is based off Free Software such as GNU GCC.
You have many freedoms to use and modify this software, as described by
the LICENSE files contained within this directory. The software you make
using this toolchain will not be encumbered by the GPL, because we don't
include any GPL licensed headers or runtime libraries. All Cosmopolitan
Libc runtime libraries are exclusively under permissive notice licenses,
e.g. ISC, MIT, BSD, etc. There are many copyright notices with the names
of people who've helped build your toolchain. You have an obligation to
distribute those notices along with your binaries. Cosmopolitan makes
that easy. Your C library is configured to use `.ident` directives to
ensure the relevant notices are automatically embedded within your
binaries. You can view them using tools like `less <bin/foo`.

## Contact

For further questions and inquiries regarding this toolchain, feel free
to contact Justine Tunney <jtunney@gmail.com>.
