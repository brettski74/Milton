# Coding Style

The modules in this repository following the following general guidelines:

- Indents are 2 spaces, except when continuing lines where it may be visually helpful to align elements with those on the preceding line.
- Indents are always spaces, never tabs.
- Class and package names use CamelCase with an uppercase first letter.
- Method names use camelCase with a lowercase first letter.
- Variable names use underscores to distinguish separate_words.
- Element names in hashes should use dashes to distinguish separate-words.
- POD documentation for methods and subroutines should immediately precede the method or subroutine that it describes.
- Perl modules should generally always use strict and use warnings qw(all -uninitialized).
- Boolean false return values should use a bare return wherever possible to ensure they are false in both scalar and list contexts.

