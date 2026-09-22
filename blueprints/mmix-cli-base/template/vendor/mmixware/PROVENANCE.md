# Vendored MMIXware

This directory contains unmodified C output generated from Donald E. Knuth's
official MMIXware CWEB sources. It is vendored so generated projects can build
their MMIX tools without downloading MMIXware or installing CWEB.

## Source

- Archive URL: <https://cs.stanford.edu/~knuth/programs/mmix.tar.gz>
- Retrieved: 2026-09-22
- Archive SHA-256:
  `b28b46b2ff44eafb4029b449262b145e538b2703f1d5b336cd429163408fafd9`
- Upstream release context: the official MMIXware page identifies MMIX Version
  1.0 and links its maintained working source archive. See
  <https://cs.stanford.edu/~knuth/mmixware.html> and
  <https://cs.stanford.edu/~knuth/mmix-news.html>.
- Generator: CTANGLE 4.12.2, with no change file, on the archive's
  `mmixal.w`, `mmix-arith.w`, `mmix-sim.w`, `mmix-io.w`, `mmotype.w`, and
  `abstime.w` inputs.

The generated source files were copied byte-for-byte from CTANGLE output;
their source-map `#line` directives deliberately retain the upstream `.w`
filenames. `boilerplate.w` is the unmodified upstream license notice.

`generated/abstime.h` records the `ABSTIME` value produced during the pinned
import run. Committing and hashing this generated metadata keeps MMIXware's
`rN` compilation-time value deterministic and avoids requiring CWEB or the
timestamp generator when a generated project rebuilds its host utilities.

## Integrity

```
f8b600b52a71455af40f6a21ff561bfe520741560fab50b1a3d30623483e1655  abstime.c
c03241013e698f4630cc378429537ef85294ccd4426a18c27872a6dd6ebb1fde  mmix-arith.c
2bc58f437df1bed8fe71aa83390715d06d65ea28f6766ca23822b9f92f98bd7a  mmix-io.c
316cedaeb40aa7bacddf0b0127bd874451d933a7e6d893729e92a5b2c4607161  mmix-sim.c
2ae14116602a2eff41a86dcfbae0ab7e9916460f2e219f2d1a2c51c1aa01f98c  mmixal.c
1f73fc61624ae1c01ad38c2cb471006a7e8909bf8a5995eef6b316d3355606fc  mmotype.c
fdc2d30c74872868a888a9d0c707103ce841668aef63fe5f13541c34a47be815  boilerplate.w
```

## Build inputs

MMIXware's C uses K&R definitions and does not compile under C99-or-later
strict modes. Use a compiler mode that accepts C89/K&R source (for example,
`-std=gnu89` with GCC or Clang), without `-Werror`. The simulator also needs
a generated, build-directory-local `abstime.h`:

```text
cc -std=gnu89 -O2 -o build/abstime vendor/mmixware/abstime.c
build/abstime > build/abstime.h
cc -std=gnu89 -O2 -Ibuild -o build/mmixal \
  vendor/mmixware/mmixal.c vendor/mmixware/mmix-arith.c
cc -std=gnu89 -O2 -Ibuild -o build/mmix \
  vendor/mmixware/mmix-sim.c vendor/mmixware/mmix-arith.c \
  vendor/mmixware/mmix-io.c
cc -std=gnu89 -O2 -o build/mmotype vendor/mmixware/mmotype.c
```

`abstime.h` sets the simulator's rN compilation-time value. It is a generated
build artifact and must not be committed.

## License

Copyright 1999 Donald E. Knuth. The upstream MMIXware license allows copying
and distribution only when the MMIXware files are unchanged; modifications
must receive a new name and be clearly identified as outside MMIXware. The
complete controlling notice is preserved unchanged in `boilerplate.w`.

This `PROVENANCE.md` file is repository metadata, not an MMIXware source file.
