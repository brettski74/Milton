# Coding Style

The modules in this repository following the following general guidelines:

- Indents are 2 spaces, except when continuing lines where it may be visually helpful to align elements with those on the preceding line.
- Indents are always spaces, never tabs.
- Class and package names use CamelCase with an uppercase first letter.
- Method  and subroutine names use camelCase with a lowercase first letter.
- Variable names use underscores to distinguish separate_words.
- Element names in hashes should use dashes to distinguish separate-words.
- POD documentation for methods and subroutines should immediately precede the method or subroutine that it describes.
- Perl modules should generally always use strict and use warnings qw(all -uninitialized).
- Boolean false return values should use a bare return wherever possible to ensure they are false in both scalar and list contexts.
- Use Readonly for constants. Do not use "use constant".
- When overflowing a comma-separated list onto multiple lines, prefer prefixed commas.
- When calling methods with no arguments, prefer omitting the parentheses.
- Prefer single quotes for string except in cases where escape sequence, variable substitution or other considerations require double quotes.
- Use Test2::V0 for unit tests.
- Prefer is tests with constructs such as float($value, tolerance => $eps), T(), F(), D(), U(), etc to check for expected results. 


