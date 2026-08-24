# Internal 2.0 modules

The code under this directory is package-internal and is not a public import
surface. Module responsibilities and allowed dependencies are defined in
`docs/architecture/KLINE_V2_MODULE_BOUNDARIES.md` and enforced by
`test/architecture/module_dependency_test.dart`.

Only `adapter` may import the legacy implementation outside `lib/src`.
