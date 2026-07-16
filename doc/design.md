# Design

libpng4cj keeps the frozen libpng `1.6.58` ownership boundaries recognizable
while implementing PNG behavior in Cangjie.

```text
src/          Cangjie library root package and cjpm-discovered unit tests
test/         standalone consumer and acceptance projects
doc/          API, design, porting, coverage, and frozen inventory documents
vendor/       exact upstream translation and oracle reference
tools/        reproducible inventory and baseline generators
```

The native package surface is `libpng4cj.*`. A future C compatibility layer is
kept separate from the native package identity.
