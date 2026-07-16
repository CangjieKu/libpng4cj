# Tests

`consumer/` is a standalone Cangjie project that consumes libpng4cj through a
path dependency, links the external system zlib at the executable boundary,
and proves the public `import libpng4cj.*` package root.

Library unit tests remain under `src/tests/`, matching the current `cjpm test`
package-discovery model.
