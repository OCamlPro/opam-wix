This test verify functionalities of `opam-wix`. We do this by using -k option to keep every build artefact for Wix. For test purpose, we will use mock version of package `foo`, `cygcheck` and dlls. Test depends on Wix toolset of version 3.11.

=== Opam setup ===
  $ export OPAMNOENVNOTICE=1
  $ export OPAMYES=1
  $ export OPAMROOT=$PWD/OPAMROOT
  $ export OPAMSTATUSLINE=never
  $ export OPAMVERBOSE=-1
  $ cat > compile << EOF
  > #!/bin/sh
  > echo "I'm launching \$(basename \${0}) \$@!"
  > EOF
  $ chmod +x compile
  $ tar czf compile.tar.gz compile
  $ SHA=`openssl sha256 compile.tar.gz | cut -d ' ' -f 2`
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
  > install: [
  >  [ "cp" "compile" "%{bin}%/%{name}%" ]
  > ]
  > url {
  >  src: "file://./compile.tar.gz"
  >  checksum: "sha256=$SHA"
  > }
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
  > url {
  >  src: "file://./compile.tar.gz"
  >  checksum: "sha256=$SHA"
  > }
  > EOF
Opam setup
  $ mkdir $OPAMROOT
  $ opam init --bare ./REPO --no-setup --bypass-checks
  No configuration file found, using built-in defaults.
  
  <><> Fetching repository information ><><><><><><><><><><><><><><><><><><><><><>
  [default] Initialised
  $ opam switch create one --empty

Wix Toolset config.
  $ unzip -qq -d wix311 wix311.zip
  $ chmod 755 wix311/*
  $ WIX_PATH=$PWD/wix311
Cygcheck overriding and dlls.
  $ mkdir dlls bins
  $ touch dlls/dll1.fakedll dlls/dll2.fakedll
 
  $ chmod +x bins/cygcheck
  chmod: cannot access 'bins/cygcheck': No such file or directory
  [1]
  $ export PATH=$PWD/bins:$PATH
================== Test 1 ====================
Try to install package with just one binary.
  $ opam install foo.0.1
  [NOTE] External dependency handling not supported for OS family 'windows'.
         You can disable this check using 'opam option --global depext=false'
  The following actions will be performed:
    - install foo 0.1
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  -> retrieved foo.0.1  (file://./compile.tar.gz)
  -> installed foo.0.1
  Done.
  $ cat > bins/cygcheck << EOF
  > #!/bin/sh
  > 
  > echo "$(cygpath -wa $PWD/OPAMROOT/one/bin/foo)"
  > echo "$(cygpath -wa $PWD/dlls/dll1.fakedll)"
  > echo "$(cygpath -wa $PWD/dlls/dll2.fakedll)"
  > 
  > EOF
  $ opam-wix --keep-wxs --wix-path=$WIX_PATH foo
  
  <><> Initialising opam ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  Package foo.0.1 found with binaries:
    - foo
  Path to the selected binary file : $TESTCASE_ROOT/OPAMROOT/one/bin/foo
  <><> Creating installation bundle <><><><><><><><><><><><><><><><><><><><><><><>
  Getting dlls:
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
Try to install package by specifing explicitely binary name.
  $ opam install foo.0.2
  [NOTE] External dependency handling not supported for OS family 'windows'.
         You can disable this check using 'opam option --global depext=false'
  The following actions will be performed:
    - upgrade foo 0.1 to 0.2
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  -> retrieved foo.0.2  (cached)
  -> removed   foo.0.1
  -> installed foo.0.2
  Done.
  $ cat > bins/cygcheck << EOF
  > #!/bin/sh
  > 
  > echo "$(cygpath -wa $PWD/OPAMROOT/one/bin/foo_1)"
  > echo "$(cygpath -wa $PWD/dlls/dll1.fakedll)"
  > echo "$(cygpath -wa $PWD/dlls/dll2.fakedll)"
  > 
  > EOF
  $ chmod +x bins/cygcheck
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
Try to install package by specifing explicitely binary path.
  $ cat > bins/cygcheck << EOF
  > #!/bin/sh
  > 
  > echo "$(cygpath -wa $PWD/OPAMROOT/one/bin/foo_2)"
  > echo "$(cygpath -wa $PWD/dlls/dll1.fakedll)"
  > echo "$(cygpath -wa $PWD/dlls/dll2.fakedll)"
  > 
  > EOF
  $ chmod +x bins/cygcheck
  $ opam-wix --keep-wxs --wix-path=$WIX_PATH foo --bp OPAMROOT/one/bin/foo_2
  
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
Try to install package by specifing explicitely binary path.
  $ cat > bins/cygcheck << EOF
  > #!/bin/sh
  > 
  > echo "$(cygpath -wa $PWD/OPAMROOT/one/bin/foo_2)"
  > echo "$(cygpath -wa $PWD/dlls/dll1.fakedll)"
  > echo "$(cygpath -wa $PWD/dlls/dll2.fakedll)"
  > 
  > EOF
  $ chmod +x bins/cygcheck
  $ opam-wix --keep-wxs --wix-path=$WIX_PATH foo --bp OPAMROOT/one/bin/foo_2
  
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

================== Test 5 ====================
Testing config file that embeds directory and file and set environment variables.
  $ touch file && mkdir dir && touch dir/file
  $ cat > conf << EOF
  > opamwix-version: "0.1"
  > embedded : [
  >   ["file_bis" "file"]
  >   ["dir_bis" "dir"]
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
  [WARNING] Specified in config path dir is relative. Searching in current directory...
  [WARNING] Specified in config path file is relative. Searching in current directory...
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
