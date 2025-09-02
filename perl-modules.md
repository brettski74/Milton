# Required Perl Modules

## External Dependencies (Need Installation)

The following perl modules are required and need to be installed separately:

|Package|Version|Arch Package|Debian Package|Centos Package|Notes|
|---|---|---|---|---|---|
|AnyEvent|70.17|perl-anyevent|libanyevent-perl||Event loop framework|
|Clone|0.46|perl-clone|libclone-perl||Deep copying of data structures|
|Device::Modbus::RTU::Client|||||CPAN only - Modbus RTU client|
|Device::SerialPort|1.04|perl-device-serialport|libdevice-serialport-perl||Serial port communication|
|EV|4.34|perl-ev|libev-perl||Event loop implementation|
|Hash::Merge|0.302|perl-hash-merge|libhash-merge-perl||Hash merging utilities|
|Math::Round|0.07|perl-math-round|libmath-round-perl||Rounding functions|
|Mojolicious::Lite|||||CPAN only - Web framework|
|Mojo::IOLoop::ReadWriteFork|||||CPAN only - Mojo I/O loop with fork|
|Path::Tiny|0.148|perl-path-tiny|libpath-tiny-perl||File path utilities|
|Readonly|2.05|perl-readonly|libreadonly-perl||Read-only variables|
|Term::ReadKey|2.38|perl-term-readkey|libterm-readkey-perl||Terminal input handling|
|YAML::PP|0.39|perl-yaml-pp|libyaml-pp-perl||YAML parser|
|YAML::PP::Schema::Include|||||CPAN only - YAML include schema|
|YAML::PP::Schema::Env|||||CPAN only - YAML environment schema|

## Core Perl Modules (Included with Perl)

The following modules are part of the Perl core and do not need separate installation:

|Package|Notes|
|---|---|
|File::Basename|File path operations|
|File::Copy|File copying operations|
|File::Path|Directory creation and removal|
|Getopt::Long|Command line option parsing|
|IO::Dir|Directory operations|
|IO::File|File I/O operations|
|IO::Pipe|Pipe I/O operations|
|IO::Select|I/O multiplexing|
|List::Util|List utility functions|
|POSIX|POSIX functions|
|Scalar::Util|Scalar utility functions|
|Term::ReadLine|Terminal readline functionality|
|Text::Template|Template processing|
|Time::HiRes|High resolution time functions|

## Testing Dependencies

The following modules are required for running tests:

|Package|Version|Arch Package|Debian Package|Centos Package|Notes|
|---|---|---|---|---|---|
|Test2::V0|1.32|perl-test2-suite|libtest2-suite-perl||Testing framework|

## Installation Notes

### Package Manager Installation

#### Arch Linux
```bash
# Install all available packages
sudo pacman -S perl-anyevent perl-clone perl-device-serialport perl-ev perl-hash-merge perl-math-round perl-path-tiny perl-readonly perl-term-readkey perl-yaml-pp perl-test2-suite
```

#### Debian/Ubuntu
```bash
# Install all available packages
sudo apt install libanyevent-perl libclone-perl libdevice-serialport-perl libev-perl libhash-merge-perl libmath-round-perl libpath-tiny-perl libreadonly-perl libterm-readkey-perl libyaml-pp-perl libtest2-suite-perl
```

### CPAN Installation
Modules not available in package managers must be installed via CPAN:

```bash
# Install CPAN modules
cpan Device::Modbus::RTU::Client Mojolicious::Lite Mojo::IOLoop::ReadWriteFork YAML::PP::Schema::Include YAML::PP::Schema::Env
```

### Alternative: cpanm Installation
Using `cpanm` (App::cpanminus) for easier installation:

```bash
# Install cpanm if not available
sudo cpan App::cpanminus

# Install CPAN modules
cpanm Device::Modbus::RTU::Client Mojolicious::Lite Mojo::IOLoop::ReadWriteFork YAML::PP::Schema::Include YAML::PP::Schema::Env
```

Note that the version numbers specified above are not necessarily the minimum version that will work, but are the minimum version number that has been tested and known to work.

