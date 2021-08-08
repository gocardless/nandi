# 0.11.1 (2021-09-09)

- Add ruby 3 support

# 0.11.0 (2021-05-19)

## BREAKING
- Drop support for Ruby 2.4.

## MINOR
- Randomise the order of entries in the lockfile. This reduces the incidence of merge conflicts when two PRs both have migrations.

# 0.9.0 2020-03-16

## BREAKING
- bugfix: Remove add_reference and remove_reference which were not safe due to non-cocurrent index creation.

# 0.8.0 2020-03-04

- First public release.
