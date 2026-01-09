package Milton::t::TestUtils;

use strict;
use warnings qw(all -uninitialized);

use Milton::Config::Path;
use Milton::Config;
use Path::Tiny qw(path);
use Carp qw(croak);

sub forceSourceConfig {
  my $srcPath = path(__FILE__)->realpath->parent->parent;

  croak "Cannot locate src directory in the perl module include path\n" if $srcPath->basename ne 'src';

  my $configPath = $srcPath->parent->child('config');

  croak "config sources do not appear in the expected location\n" if !$configPath->exists;

  croak $configPath->stringify ." is not a directory\n" if !$configPath->is_dir;

  Milton::Config::Path::clear_search_path;
  Milton::Config::Path::add_search_dir($configPath->stringify);
  Milton::Config::Path::standard_search_path;
}

1;