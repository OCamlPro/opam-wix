# OCaml Universal Installer

OCaml Universal Installer or oui, is a tool that produces standalone installers
for your OCaml applications, be it for Linux, Windows or macOS.


## Installation layout

oui aims at producing the most consistent installs across platforms but each
as its own specifities.

The following sections describes how an application is installed on the three
main platform it supports.

### Linux

Executing a `.run` produced by oui will install the application in
`/opt/<appname>`:

```
/opt/<appname>/
├── bin
│   ├── <binary1>
│   └── <binary2>
└── uninstall.sh
```

the `bin/` subfolder will contain all executables for the application.
A symlink to those will also be written to `/usr/local/bin/`.

An `uninstall.sh` script is also installed alongside the application
that can be run to cleanly remove it from the system.
