This test verify functionalities of `opam-wix`. We do this by using -k option
to keep every build artefact for Wix. For test purpose, we will use mock
version of package `foo`, `cygcheck` and dlls. Test depends on Wix toolset of
version 3.11.

=== Check system ===
  $ opam --version
  2.1.5
  $ ocaml -e 'Printf.printf "is cygwin? %b" Sys.cygwin;;'
  is cygwin? true
=== Opam setup ===
  $ export OPAMNOENVNOTICE=1
  $ export OPAMYES=1
  $ export OPAMROOT=$PWD/OPAMROOT
  $ export OPAMSTATUSLINE=never
  $ export OPAMVERBOSE=-1
  $ mkdir archive
  $ cat > archive/compile << EOF
  > #!/bin/sh
  > echo "I'm launching \$(basename \${0}) \$@!"
  > EOF
  $ chmod +x archive/compile
Repo setup
  $ mkdir -p REPO/packages/
  $ cat > REPO/repo << EOF
  > opam-version: "2.0"
  > EOF
Foo package.
  $ mkdir -p REPO/packages/foo/foo.0.1 REPO/packages/foo/foo.0.2
  $ cat > REPO/packages/foo/foo.0.1/opam << EOF
  > opam-version: "2.0"
  > name: "foo"
  > version: "0.1"
  > maintainer : [ "John Smith"]
  > synopsis: "Foo tool"
  > tags : ["tool" "dummy"]
  > build: [ "sh" "compile" name ]
  > install: [ "cp" "compile" "%{bin}%/%{name}%" ]
  > url { src: "file://./archive" }
  > EOF
  $ cat > REPO/packages/foo/foo.0.2/opam << EOF
  > opam-version: "2.0"
  > name: "foo"
  > version: "0.2"
  > maintainer : [ "John Smith"]
  > synopsis: "Foo tool"
  > tags : ["tool" "dummy"]
  > build: [ "sh" "compile" name ]
  > install: [
  >  [ "cp" "compile" "%{bin}%/%{name}%_1" ]
  >  [ "cp" "compile" "%{bin}%/%{name}%_2" ]
  > ]
  > url { src: "file://./archive" }
  > EOF
Opam setup
  $ mkdir $OPAMROOT
  $ opam init --bare ./REPO --no-setup --bypass-checks
  No configuration file found, using built-in defaults.
  
  <><> Fetching repository information ><><><><><><><><><><><><><><><><><><><><><>
  [default] Initialised
  $ opam option --global depext=false
  Set to 'false' the field depext in global configuration
  $ opam switch create one --empty

Wix Toolset config.
  $ unzip -qq -d wix311 wix311.zip
  $ chmod 755 wix311/*
  $ WIX_PATH=$PWD/wix311
Cygcheck overriding and dlls.
  $ mkdir dlls bins
  $ cat > bins/cygcheck << EOF
  > #!/bin/sh
  > 
  > cygpath -wa \$1
  > cygpath -wa $PWD/dlls/dll1.fakedll
  > cygpath -wa $PWD/dlls/dll2.fakedll
  > 
  > EOF
  $ chmod +x bins/cygcheck
  $ touch dlls/dll1.fakedll dlls/dll2.fakedll 
  $ export PATH=$PWD/bins:$PATH
================== Test 1 ====================
Try to install package with just one binary.
  $ opam install foo.0.1
  The following actions will be performed:
    - install foo 0.1
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  -> retrieved foo.0.1  (file://./archive)
  -> installed foo.0.1
  Done.
  $ opam-wix --keep-wxs --wix-path=$WIX_PATH foo
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.1 found with binaries:
    - foo
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.

  $ cat foo.wxs | sed -e 's/Id="[^"]*"//g' -e 's/UpgradeCode="[^"]*"//g' -e 's/Guid="[^"]*"//g'
  <?xml version="1.0" encoding="windows-1252"?><Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
   <Product Name="foo.foo"   Language="1033" Codepage="1252" Version="0.1" Manufacturer="John Smith">
    <Package  Keywords="tool dummy" Description="Foo tool" Manufacturer="John Smith" InstallerVersion="100" Languages="1033" Compressed="yes" SummaryCodepage="1252"/>
    <Media  Cabinet="Sample.cab" EmbedCab="yes"/>
    <Directory  Name="SourceDir">
     <Directory  Name="PFiles">
      <Directory  Name="foo.0.1-foo">
       <Component  >
        <File  Name="logo.ico" Disk Source="foo.0.1/logo.ico"/>
        <File  Name="foo.exe" Disk Source="foo.0.1/foo.exe" KeyPath="yes"/>
       </Component>
       <Component  >
        <CreateFolder/>
       </Component>
       <Component  >
        <CreateFolder/>
        <Condition>
         ADDTOPATH
        </Condition>
        <Environment  Name="PATH" Value="[INSTALLDIR]" Permanent="no" Part="last" Action="set" System="yes"/>
       </Component>
       <Component  >
        <File  Name="dll1.fakedll" Disk Source="foo.0.1/dll1.fakedll"/>
        <File  Name="dll2.fakedll" Disk Source="foo.0.1/dll2.fakedll"/>
       </Component>
      </Directory>
     </Directory>
     <Directory  Name="Programs">
      <Directory  Name="foo.0.1-foo">
       <Component  >
        <RemoveFolder  On="uninstall"/>
        <RegistryValue Root="HKCU" Key="Software\[Manufacturer]\[ProductName]" Type="string" Value="" KeyPath="yes"/>
       </Component>
      </Directory>
     </Directory>
     <Directory  Name="Desktop">
      <Component  >
       <Condition>
        INSTALLSHORTCUTDESKTOP
       </Condition>
       <Shortcut  Name="foo" WorkingDirectory="INSTALLDIR" Icon="logo.ico" Target="[INSTALLDIR]foo.exe"/>
       <RemoveFolder  On="uninstall"/>
       <RegistryValue Root="HKCU" Key="Software\[Manufacturer]\[ProductName]" Name="installed" Type="integer" Value="1" KeyPath="yes"/>
      </Component>
     </Directory>
     <Directory >
      <Component  >
       <Condition>
        INSTALLSHORTCUTSTARTMENU
       </Condition>
       <Shortcut  Name="foo" WorkingDirectory="INSTALLDIR" Icon="logo.ico" Target="[INSTALLDIR]foo.exe"/>
       <RemoveFolder  On="uninstall"/>
       <RegistryValue Root="HKCU" Key="Software\[Manufacturer]\[ProductName]" Name="installed" Type="integer" Value="1" KeyPath="yes"/>
      </Component>
     </Directory>
     <Directory />
    </Directory>
    <SetDirectory  Value="[SystemFolder]"/>
    <Feature  Title="foo.0.1-foo" Description="foo.foo complete install." Level="1">
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
    </Feature>
    <Property  Value="1"/>
    <Property  Value="1"/>
    <Property  Value="0"/>
    <Icon  SourceFile="foo.0.1/logo.ico"/>
    <Property  Value="logo.ico"/>
    <Property  Value="INSTALLDIR"/>
    <WixVariable  Value="foo.0.1/bannrbmp.bmp"/>
    <WixVariable  Value="foo.0.1/dlgbmp.bmp"/>
    <UIRef />
   </Product>
  </Wix>

================== Test 2 ====================
Try to install package by specifying explicitly binary name.
  $ opam install foo.0.2
  The following actions will be performed:
    - upgrade foo 0.1 to 0.2
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  -> retrieved foo.0.2  (file://./archive)
  -> removed   foo.0.1
  -> installed foo.0.2
  Done.
  $ opam-wix --keep-wxs --wix-path=$WIX_PATH foo -b foo_1
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.2 found with binaries:
    - foo_1
    - foo_2
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo_1
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.

================== Test 3 ====================
Try to install package by specifying explicitly binary path.
  $ opam-wix --wix-path=$WIX_PATH foo --bp OPAMROOT/one/bin/foo_2
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.2 found with binaries:
    - foo_1
    - foo_2
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo_2
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.

================== Test 4 ====================
Testing config file that embeds directory and file and set environment variables.
  $ touch file && mkdir dir && touch dir/file
  $ mkdir -p dir1/dir2/dir3 && touch dir1/dir2/dir3/file
  $ cat > conf << EOF
  > opamwix-version: "0.1"
  > embedded : [
  >   ["file" "file_bis"]
  >   ["dir" "dir_bis"]
  >   ["dir1/dir2"]
  >   ["dir1/dir2/dir3/file"]
  >   ["dir/file"]
  >   ["%{foo:bin}%/foo_2"]
  > ]
  > envvar : [
  >   ["VAR1" "val1"]
  >   ["VAR2" "val2"]
  > ]
  > EOF
  $ opam-wix --keep-wxs --conf conf --wix-path=$WIX_PATH foo -b foo_2
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.2 found with binaries:
    - foo_1
    - foo_2
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo_2
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  [WARNING] Specified in config path file is relative. Searching in current directory...
  [WARNING] Specified in config path dir is relative. Searching in current directory...
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.

  $ cat foo_2.wxs | sed -e 's/Id="[^"]*"//g' -e 's/UpgradeCode="[^"]*"//g' -e 's/Guid="[^"]*"//g'
  <?xml version="1.0" encoding="windows-1252"?><Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
   <Product Name="foo.foo_2"   Language="1033" Codepage="1252" Version="0.2" Manufacturer="John Smith">
    <Package  Keywords="tool dummy" Description="Foo tool" Manufacturer="John Smith" InstallerVersion="100" Languages="1033" Compressed="yes" SummaryCodepage="1252"/>
    <Media  Cabinet="Sample.cab" EmbedCab="yes"/>
    <Directory  Name="SourceDir">
     <Directory  Name="PFiles">
      <Directory  Name="foo.0.2-foo_2">
       <Component  >
        <File  Name="logo.ico" Disk Source="foo.0.2/logo.ico"/>
        <File  Name="foo_2.exe" Disk Source="foo.0.2/foo_2.exe" KeyPath="yes"/>
       </Component>
       <Component  >
        <CreateFolder/>
        <Environment  Name="VAR1" Value="val1" Permanent="no" Part="last" Action="set" System="yes"/>
        <Environment  Name="VAR2" Value="val2" Permanent="no" Part="last" Action="set" System="yes"/>
       </Component>
       <Component  >
        <CreateFolder/>
        <Condition>
         ADDTOPATH
        </Condition>
        <Environment  Name="PATH" Value="[INSTALLDIR]" Permanent="no" Part="last" Action="set" System="yes"/>
       </Component>
       <Component  >
        <File  Name="dll1.fakedll" Disk Source="foo.0.2/dll1.fakedll"/>
        <File  Name="dll2.fakedll" Disk Source="foo.0.2/dll2.fakedll"/>
       </Component>
       <Component  >
        <File  Name="file_bis" Disk Source="foo.0.2/file_bis"/>
       </Component>
       <Directory  Name="dir_bis"/>
       <Directory  Name="opam"/>
       <Directory  Name="external"/>
      </Directory>
     </Directory>
     <Directory  Name="Programs">
      <Directory  Name="foo.0.2-foo_2">
       <Component  >
        <RemoveFolder  On="uninstall"/>
        <RegistryValue Root="HKCU" Key="Software\[Manufacturer]\[ProductName]" Type="string" Value="" KeyPath="yes"/>
       </Component>
      </Directory>
     </Directory>
     <Directory  Name="Desktop">
      <Component  >
       <Condition>
        INSTALLSHORTCUTDESKTOP
       </Condition>
       <Shortcut  Name="foo_2" WorkingDirectory="INSTALLDIR" Icon="logo.ico" Target="[INSTALLDIR]foo_2.exe"/>
       <RemoveFolder  On="uninstall"/>
       <RegistryValue Root="HKCU" Key="Software\[Manufacturer]\[ProductName]" Name="installed" Type="integer" Value="1" KeyPath="yes"/>
      </Component>
     </Directory>
     <Directory >
      <Component  >
       <Condition>
        INSTALLSHORTCUTSTARTMENU
       </Condition>
       <Shortcut  Name="foo_2" WorkingDirectory="INSTALLDIR" Icon="logo.ico" Target="[INSTALLDIR]foo_2.exe"/>
       <RemoveFolder  On="uninstall"/>
       <RegistryValue Root="HKCU" Key="Software\[Manufacturer]\[ProductName]" Name="installed" Type="integer" Value="1" KeyPath="yes"/>
      </Component>
     </Directory>
     <Directory />
    </Directory>
    <SetDirectory  Value="[SystemFolder]"/>
    <Feature  Title="foo.0.2-foo_2" Description="foo.foo_2 complete install." Level="1">
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentGroupRef />
     <ComponentGroupRef />
     <ComponentGroupRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
     <ComponentRef />
    </Feature>
    <Property  Value="1"/>
    <Property  Value="1"/>
    <Property  Value="0"/>
    <Icon  SourceFile="foo.0.2/logo.ico"/>
    <Property  Value="logo.ico"/>
    <Property  Value="INSTALLDIR"/>
    <WixVariable  Value="foo.0.2/bannrbmp.bmp"/>
    <WixVariable  Value="foo.0.2/dlgbmp.bmp"/>
    <UIRef />
   </Product>
  </Wix>

================== Test 4.1 ====================
Testing config file that specifies wrong paths to files to embed (absolute, explicit and inexistant paths).

  $ mkdir -p dir1/dir2
  $ cat > conf_absolute << EOF
  > opamwix-version: "0.1"
  > embedded : [
  >   ["/var/www"]
  > ]
  > EOF

  $ cat > conf_explicit << EOF
  > opamwix-version: "0.1"
  > embedded : [
  >   ["./dir1/dir2"]
  > ]
  > EOF

  $ cat > conf_wrong << EOF
  > opamwix-version: "0.1"
  > embedded : [
  >   ["dir1/dir3"]
  > ]
  > EOF

  $ opam-wix --conf conf_absolute --wix-path=$WIX_PATH foo -b foo_1
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.2 found with binaries:
    - foo_1
    - foo_2
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo_1
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  [WARNING] Path /var/www is absolute or starts with ".." or ".". You should specify alias with absolute path. Skipping...
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.
  $ opam-wix --conf conf_explicit --wix-path=$WIX_PATH foo -b foo_1
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.2 found with binaries:
    - foo_1
    - foo_2
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo_1
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  [WARNING] Path ./dir1/dir2 is absolute or starts with ".." or ".". You should specify alias with absolute path. Skipping...
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.
  $ opam-wix --conf conf_wrong --wix-path=$WIX_PATH foo -b foo_1
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.2 found with binaries:
    - foo_1
    - foo_2
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo_1
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  [ERROR] Couldn't find relative path to embed: dir1/dir3.
  [5]


================== Test 5 ====================
Version testing
  $ mkdir bar
  $ cp archive/compile bar/compile
  $ cat > bar/bar-with-plus.opam << EOF
  > opam-version: "2.0"
  > version: "0.1+23"
  > name: "bar-with-plus"
  > maintainer : [ "John Smith"]
  > synopsis: "Foo tool"
  > tags : ["tool" "dummy"]
  > install: [ "cp" "compile" "%{bin}%/%{name}%" ]
  > EOF
  $ cat > bar/bar-beg-alpha.opam << EOF
  > opam-version: "2.0"
  > version: "v012"
  > name: "bar-with-plus"
  > maintainer : [ "John Smith"]
  > synopsis: "Foo tool"
  > tags : ["tool" "dummy"]
  > install: [ "cp" "compile" "%{bin}%/%{name}%" ]
  > EOF
  $ cat > bar/bar-only-alpha.opam << EOF
  > opam-version: "2.0"
  > version: "aversion"
  > name: "bar-with-plus"
  > maintainer : [ "John Smith"]
  > synopsis: "Foo tool"
  > tags : ["tool" "dummy"]
  > install: [ "cp" "compile" "%{bin}%/%{name}%" ]
  > EOF
  $ opam pin ./bar -y | sed 's/file:\/\/[^ ]*/$FILE_PATH/g'
  This will pin the following packages: bar-beg-alpha, bar-only-alpha, bar-with-plus. Continue? [Y/n] y
  Package bar-beg-alpha does not exist, create as a NEW package? [Y/n] y
  bar-beg-alpha is now pinned to $FILE_PATH (version v012)
  Package bar-only-alpha does not exist, create as a NEW package? [Y/n] y
  bar-only-alpha is now pinned to $FILE_PATH (version aversion)
  Package bar-with-plus does not exist, create as a NEW package? [Y/n] y
  bar-with-plus is now pinned to $FILE_PATH (version 0.1+23)
  
  The following actions will be performed:
    - install bar-only-alpha aversion*
    - install bar-with-plus  0.1+23*
    - install bar-beg-alpha  v012*
  ===== 3 to install =====
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  -> installed bar-beg-alpha.v012
  -> installed bar-only-alpha.aversion
  -> installed bar-with-plus.0.1+23
  Done.
  $ opam-wix --wix-path=$WIX_PATH bar-with-plus
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  [WARNING] Package version 0.1+23 contains characters not accepted by MSI.
  It must be only dot separated numbers. You can use config file to set it or option --with-version.
  Do you want to use simplified version 0.1? [Y/n] n
  [10]
  $ opam-wix --wix-path=$WIX_PATH bar-with-plus -y
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  [WARNING] Package version 0.1+23 contains characters not accepted by MSI.
  It must be only dot separated numbers. You can use config file to set it or option --with-version.
  Do you want to use simplified version 0.1? [Y/n] y
  Package bar-with-plus.0.1+23 found with binaries:
    - bar-with-plus
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/bar-with-plus
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.
  $ opam-wix --wix-path=$WIX_PATH bar-beg-alpha
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  [WARNING] Package version v012 contains characters not accepted by MSI.
  [ERROR] No version can be retrieved from 'v012', use config file to set it or option --with-version.
  [5]
  $ opam-wix --wix-path=$WIX_PATH bar-only-alpha
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  [WARNING] Package version aversion contains characters not accepted by MSI.
  [ERROR] No version can be retrieved from 'aversion', use config file to set it or option --with-version.
  [5]
  $ opam-wix --wix-path=$WIX_PATH bar-only-alpha --with-version 4.2
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package bar-only-alpha.aversion found with binaries:
    - bar-only-alpha
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/bar-only-alpha
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.
  $ cat > conf << EOF
  > opamwix-version: "0.2"
  > wix-version: "3.2+3"
  > EOF
  $ opam-wix --wix-path=$WIX_PATH --conf conf bar-only-alpha
  Fatal error:
  At $TESTCASE_ROOT/conf:2:0-2:20::
  while expecting wix_version: Invalid character '+' in WIX version "3.2+3"
  [99]
  $ cat > conf << EOF
  > opamwix-version: "0.2"
  > wix-version: "3.2"
  > EOF
  $ opam-wix --wix-path=$WIX_PATH --conf conf bar-only-alpha
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package bar-only-alpha.aversion found with binaries:
    - bar-only-alpha
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/bar-only-alpha
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
    - $TESTCASE_ROOT/dlls/dll1.fakedll
    - $TESTCASE_ROOT/dlls/dll2.fakedll
  Bundle created.
  <><> WiX setup ><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Compiling WiX components...
  Producing final msi...
  Done.

