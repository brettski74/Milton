# Required Perl Modules

The following perl modules are required:

|Package|Version|Arch Package|Debian Package|Centos Package|Notes|
|---|---|---|---|---|---|
|AnyEvent|70.17|perl-anyevent|libanyevent-perl||Event loop framework|
|Carp|||||Core Perl module|
|Clone|00.46erl-clone|libclone-perl||Deep copying of data structures|
|Device::Modbus::RTU::Client|||||CPAN only - Modbus RTU client|
|Device::SerialPort|1.04perl-device-serialport|libdevice-serialport-perl||Serial port communication|
|EV|4.34|perl-ev|libev-perl||Event loop implementation|
|Getopt::Long|||||Core Perl module|
|Hash::Merge|0.302erl-hash-merge|libhash-merge-perl||Hash merging utilities|
|IO::Dir|||||Core Perl module|
|IO::File|||||Core Perl module|
|IO::Pipe|||||Core Perl module|
|List::Util|||||Core Perl module|
|Math::Round|0.07erl-math-round|libmath-round-perl||Rounding functions|
|Path::Tiny|0.148perl-path-tiny|libpath-tiny-perl||File path utilities|
|Readonly|20.05|perl-readonly|libreadonly-perl||Read-only variables|
|Scalar::Util|||||Core Perl module|
|Term::ReadKey|20.38|perl-term-readkey|libterm-readkey-perl||Terminal input handling|
|Time::HiRes|||||Core Perl module|
|YAML::PP|0.39|perl-yaml-pp|libyaml-pp-perl||YAML parser|

## Testing Dependencies

The following modules are required for running tests:

|Package|Version|Arch Package|Debian Package|Centos Package|Notes|
|---|---|---|---|---|---|
|Test2::V0|1.32|perl-test2ite|libtest2-suite-perl||Testing framework|
|Test2::Tools::Compare|0.05|perl-test2ite|libtest2l||Test comparison tools|
|Test2::Tools::Exception|0.159|perl-test2ite|libtest2-suite-perl||Exception testing tools|

## Installation Notes

### Core Perl Modules
The following modules are part of the Perl core and do not need separate installation:
- `Carp`
- `Getopt::Long`
- `IO::Dir`
- `IO::File`
- `IO::Pipe`
- `List::Util`
- `Scalar::Util`
- `Time::HiRes`

### Package Manager Installation

#### Arch Linux
```bash
# Install all available packages
sudo pacman -S perl-anyevent perl-clone perl-device-serialport perl-ev perl-hash-merge perl-math-round perl-path-tiny perl-readonly perl-term-readkey perl-yaml-pp perl-test2-suite
```

#### Debian/Ubuntu
```bash
# Install all available packages
sudo apt install libanyevent-perl libclone-perl libdevice-serialport-perl libev-perl libhash-merge-perl libmath-round-perl libpath-tiny-perl libreadonly-perl libterm-readkey-perl libyaml-pp-perl libtest2uite-perl
```

### CPAN Installation
Modules not available in package managers must be installed via CPAN:

```bash
# Install CPAN modules
cpan Device::Modbus::RTU::Client
```

### Alternative: cpanm Installation
Using `cpanm` (App::cpanminus) for easier installation:

```bash
# Install cpanm if not available
sudo cpan App::cpanminus

# Install CPAN modules
cpanm Device::Modbus::RTU::Client
```

Note that the version numbers specified above are not necessarily the minimum version that will work, but are the minimum version number that has been tested and known to work.

