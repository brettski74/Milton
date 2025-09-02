# Milton Configuration Templates

Files here comprise either example configuration that you can use or templates that the system uses during setup to provide an initial working configuration for a new installation. Directories that are relevant to Milton configuration (in order of priority) are:

|Path|Notes|
|---|---|
|--library options|The psc command may receive --library options on the command line which apply in the order they are found ahead of all other locations. You can use this to ensure a particular directory is always the first place from which to load configuration files.|
|$MILTON_CONFIG_PATH|This environment variable may contain user-specified directories to be searched for configuration files. Like PATH and many other environment variables on unix-like systems, this is a colon (:) separated list of directories and will be searched in the order specified.|
|.|The current working directory is always searched for configuration files, so where you run the command can impact what configuration you load. For commands run by the web UI, this will be the working directory of the web server process.|
|$HOME/.config/milton|Preferred location to install your customized configuration files.|
|$HOME/.local/share/milton|Location where release files are installed for a non-root-user installation. Don't use this for customized files as they may be overwritten by future release installs if you ever upgrade.|
|/usr/local/share/milton|Location where release files should be installed for a non-managed root-user installation for use by all users on a system. Don't use this for customized files as they may be overwritten by future release installs if you ever upgrade.|
|/usr/share/milton|Location where release files should be written when installed by a package manager. Don't use this for customized files as they may be overwritten by future release installs if you ever upgrade.|

The installation process should install these files into one of the latter 3 directories listed above, depending on the type of installation. Then any customized files generated from the templates during the installation and setup process should be written into the $HOME/.config/milton directory and it's subdirectories.