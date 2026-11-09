## [Unreleased]

## [1.3.1] - 2025-08-11

### Changed

- `authorize` can be defined more than once for the same action. The last definition replaces the earlier one instead of raising `SnFoil::Context::Error`.

## [1.3.0] - 2025-07-01

### Changed

- An action defined without a primary method (`with:`) or block no longer raises. Its primary step is treated as a success (`true`), so its setup, before, `after_<action>_success` and `after_<action>` hooks run.

## [1.2.2] - 2025-04-23

### Changed

- Require Ruby 3.0 or newer (previously 2.6).
- Development now runs in a Docker dev container on Ruby 3.4, with updated tooling (RuboCop 1.75, bundler-audit 0.9, `debug` in place of `pry-byebug`).

## [0.1.0] - 2021-09-26

- Initial release
