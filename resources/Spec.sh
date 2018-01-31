
PACKAGE="simula"
VERSION="0.0.0"
REPO="https://github.com/SimulaVR/Simula.git"

installDebHelpers() {
  sudo apt install  \
    autoconf        \
    automake        \
    autotools-dev   \
    debmake         \
    dh-make         \
    devscripts      \
    fakeroot        \
    file            \
    gnupg           \
    lintian         \
    patch           \
    patchutils      \
    pbuilder        \
    quilt           \
    xutils-dev      \

    # probably included by default:
    build-essential \
    debhelper       \ # provides dh_* commands
    dh-make         \
    debmake
}

# installUbuntuPackingSoftware() {
#     sudo apt install gnupg pbuilder ubuntu-dev-tools apt-file
#     sudo apt-get install dh-make bzr-builddeb
# }

exportDebianEnvironmentVariables() {
  if [[ -z "${DEBEMAIL}" ]]; then
    echo 'DEBEMAIL="george.w.singer@gmail.com"' >> ~/.bashrc
    echo 'export DEBEMAIL'          >> ~/.bashrc
  fi

  if [[ -z "${DEBFULLNAME}" ]]; then
    echo 'DEBFULLNAME="George Singer"'          >> ~/.bashrc
    echo 'export DEBFULLNAME'                      >> ~/.bashrc
  fi

  . ~/.bashrc
}

generateFreshSource() {
    #stack clean --full # or use what ever you use to clean the project*
    git clone $REPO $PACKAGE-$VERSION

    cd $PACKAGE-$VERSION
    make init # i.e.: git submodule update --init --recursive
    cd ..
}

generateFreshUpstreamTar() {
    git clone $REPO tmp-$PACKAGE-$VERSION
    cd tmp-$PACKAGE-$VERSION
    make init
    make clean
    cd ..

    tar -cvzf $PACKAGE-$VERSION.tar.gz tmp-$PACKAGE-$VERSION --exclude-vcs
    sudo rm -r tmp-$PACKAGE-$VERSION
}

dhMake() {
    cd "$PACKAGE-$VERSION"
    make clean
   # dh_make --createorig -s -p "$PACKAGE"_"$VERSION" # weird; this seems to freeze but work if you C-c out of it; QWERTY
    dh_make -f ../$PACKAGE-$VERSION.tar.gz # I believe we want option `s`, a single binary package that will make one `openvr*.deb`
    cd ..
}

# dh_make_"$PACKAGE"_ubuntu() {
#     bzr dh-make "$PACKAGE" "$VERSION" "$PACKAGE"-"$VERSION".tar.gz # s
#                                                    # (i)  imports code into branch
#                                                    # (ii) adds debian/packaging directory

#     # VERIFY: (i)  ./"$PACKAGE"/debian/* exists
#     #         (ii) ./"$PACKAGE"_"$VERSION".orig.tar.gz exists

#     # TODO:
#     #cd "$PACKAGE"/debian
#     #rm *ex *EX
# }

modifyDebianRulesFile() {
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
  cp ./resources/rules ./"$PACKAGE"-"$VERSION"/debian/rules
}

modifyDebianControlFile() {
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
  cp ./resources/control ./"$PACKAGE"-"$VERSION"/debian/control
}

modifyDebianCopyrightFile() {
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
  cp ./resources/copyright ./"$PACKAGE"-"$VERSION"/debian/copyright
}

modifyDebianChangelogFile() {
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
  cp ./resources/changelog ./"$PACKAGE"-"$VERSION"/debian/changelog
}

modifyDebianInstallFile() {
  cp ./resources/install ./"$PACKAGE"-"$VERSION"/debian/install
}

deleteUnneededDebianFiles() {
  rm "$PACKAGE"-"$VERSION"/debian/README.Debian     # Not needed for now
  rm "$PACKAGE"-"$VERSION"/debian/README.source     # Not needed for now
  rm "$PACKAGE"-"$VERSION"/debian/"$PACKAGE"-docs.docs  # This references the above 2 files
}

buildPackage() {
  # PREREQUISITES:
  # sudo apt-get install build-depends \ 
  #                      < Build-Depends entries > 
  #                      < Build-Depends-indep entries > 

  cd "$PACKAGE"-"$VERSION"
  # dpkg-buildpackage -us -uc
  debuild -S

  # This will:
  # 1. Clean the source tree (debian/rules clean)
  # 2. Build the source package (dpkg-source -b)
  # 3. Build the program (debian/rules build)
  # 4. Build binary packages (fakeroot debian/rules binary)
  # 5. TODO: Make the .dsc file (Verify)
  # 6. TODO: Make the .changes file, using dpkg-genchanges (Verify)

  debsign # Must be ran within "$PACKAGE"-"$VERSION" since it accesses ./debian/changelog.
          # If you receive trouble with debsign, try putting
          # DEBSIGN_KEYID=Your_GPG_keyID 
          # in ~/.devscripts

  # To verify the source package was generated, run `cd ~/"$PACKAGE"-deb` and verify the following exist:
  # 1. "$PACKAGE"_"$VERSION".orig.tar.gz
  # 2. "$PACKAGE"_"$VERSION"-1.dsc: Generated from debian/control; used by dpkg-source; needs debsigned
  # 3. "$PACKAGE"_"$VERSION"-1.debian.tar.gz: Contains debian/* with patches in debian/patches
  # 4. "$PACKAGE"_"$VERSION"-1_amd64.deb
  # 5. "$PACKAGE"_"$VERSION"-1_amd64.changes: Needs debsigned.
  # With (1)-(3), you can run `dpkg-source -x gentoo_0.9.12-1.dsc` to completely recreate the package from scratch.

  # FOOTNOTE 1: 
  # Alternative to `dpkg-buildpackage -us -uc`:
  # First place the following in ~/.devscripts:
  # ```
  # DEBUILD_DPKG_BUILDPACKAGE_OPTS="-us -uc -I -i"
  # DEBUILD_LINTIAN_OPTS="-i -I --show-overrides"
  # ```
  # Then you can run `debuild` (as well as `debuild clean`), which wraps `dpkg-buildpackage -us -uc`.
  # 
  # From a different tutorial:
  # brand new package with no existing version in Ubuntu's repositories (will be uploaded with the .orig.tar.gz file): debuild -S -sa
  # Note: If you get the error clearsign failed: secret key not available when signing the changes file, use an additional option -k[key_id] when calling debuild. Use gpg --list-secret-keys to get the key ID. Look for a line like "sec 12345/12ABCDEF"; the part after the slash is the key ID.

  cd ..
}

verifyPackageInstallation() {
  cd "$PACKAGE"-"$VERSION"/debian
  ls -tlra | grep change-                # verify this is empty; if it's not, it means "files were changed by accident or the build script modified the upstream source"

  cd ../..
  sudo debi "$PACKAGE"_"$VERSION"-1_amd64.changes # tests whether your package installs w/o problems

  # lintian only required if you build mannually w/dpkg-buildpackage as opposed to debuild (which wraps lintian); lintian codes:
  #   E: Error
  #   W: Warning
  #   I: Info
  #   N: Note
  #   O: Overriden (you can set overrides via `lintian-overrides` file
  lintian -i -I --show-overrides "$PACKAGE"_"$VERSION"-1_amd64.changes

  # TRIAGED since we're not using "maintainer scripts"
  # 
  # sudo dpkg -r "$PACKAGE"
  # sudo dpkg -P "$PACKAGE"
  # sudo dpkg -i "$PACKAGE"_"$VERSION"-revision_amd64.deb

  # TRIAGED: version conflicts
  # "If this is your first package, you should create dummy packages with different versions to test your package in advance to prevent future problems."

  # TRIAGED: upgrades
  # "Bear in mind that if your package has previously been released in Debian, people will often be upgrading to your package from the version that was in the last Debian release. Remember to test upgrades from that version too."

  # TRIAGED: downgrades
  # "Although downgrading is not officially supported, supporting it is a friendly gesture."
}

cleanRoot() {
    sudo rm "$PACKAGE"*build
    sudo rm "$PACKAGE"*buildinfo
    sudo rm "$PACKAGE"*changes
    sudo rm "$PACKAGE"*deb
    sudo rm "$PACKAGE"*xz
    sudo rm "$PACKAGE"*dsc
    sudo rm "$PACKAGE"*gz
    sudo rm "$PACKAGE"*gz
    sudo rm "$PACKAGE"*xz
    sudo rm "$PACKAGE"*gz
    sudo rm -r "$PACKAGE"-"$VERSION"
}

generateDebianPackage() {
  #installDebHelpers
  #exportDebianEnvironmentVariables

  generateFreshSource
  generateFreshUpstreamTar

  dhMake

  modifyDebianRulesFile
  modifyDebianControlFile
  modifyDebianCopyrightFile
  modifyDebianChangelogFile
  modifyDebianInstallFile
  deleteUnneededDebianFiles

  buildPackage

  #verifyPackageInstallation
}

generateNewGPGKey() {
  gpg --gen-key # RSA/2048/0/George Singer/george.w.singer@gmail.com/football
                # Needs "random bits" so move mouse around, etc.
}

printGPGFingerPrint() {
  gpg --fingerprint george.w.singer@gmail.com

  # EXAMPLE:
  # pub   4096R/43CDE61D 2010-12-06
  #       Key fingerprint = 5C28 0144 FB08 91C0 2CF3  37AC 6F0B F90F 43CD E61D
  # uid                  Daniel Holbach <dh@mailempfang.de>
  # sub   4096R/51FBE68C 2010-12-06

  # Key ID = 43CDE61D
  # Key fingerprint = 5C28 0144 FB08 91C0 2CF3  37AC 6F0B F90F 43CD E61D

}

uploadPublicGPGKey() {
  gpg --send-keys --keyserver keyserver.ubuntu.com "$1" # takes <KEY ID>, or 43CDE61D from the example above

  # THEN:
  # 1. Head to https://launchpad.net/~/+editpgpkeys and copy the “Key fingerprint” into the text box. In the case above this would be 5C28 0144 FB08 91C0 2CF3  37AC 6F0B F90F 43CD E61D. Now click on “Import Key”.
  # 2. Check email & copy contents to <clipboard>.
  # 3. Run `gpg; <clipboard>` (type in your passphrase in the GUI popup).
  # 4. Click the link from the output.
  # 5. Back on the Launchpad website, use the Confirm button and Launchpad will complete the import of your OpenPGP key.
}

uploadSSHKey() {
  cat ~/.ssh/id_rsa.pub
  firefox  https://launchpad.net/~/+editsshkeys 
  # Copy the contents of the file and paste them into the text box on the web page that says “Add an SSH key”. 
  # Now click “Import Public Key”.
}

# Here we assume we're on `bionic` development branch
# setUpPbuilder() {
#   pbuilder-dist bionic create # takes a while
# }

uploadPackage() {
    # http://packaging.ubuntu.com/html/getting-set-up.html
    # http://packaging.ubuntu.com/html/packaging-new-software.html
    # https://www.debian.org/doc/manuals/maint-guide/upload.en.html
    dput ppa:georgewsinger/simula "$PACKAGE"_"$VERSION"-0ubuntu1_source.changes # TODO: Make sure this naming is correct
}

addSimulaRepositoryPPA() {
    sudo add-apt-repository "ppa:georgewsinger/simula"
    sudo apt-get update
    #sudo apt-get dist-upgrade

    #sudo apt-get install "$PACKAGE"
}

# Questions
#  1. How to strip binaries to reduce package size?
#  2. Does `CMakeLists.txt` need to be modified (in a similar way that all `Makefiles` need to be modified, as below)?

# Resources #
# 1. #debian-mentors on IRC
# 2. How to use Quilt:
#     - https://www.debian.org/doc/manuals/maint-guide/modify.en.html#quiltrc
#     - example:
#       $ dquilt new foo2.patch
#       $ dquilt add Makefile
#       $ sed -i -e 's/-lfoo/-lfoo2/g' Makefile
#       $ dquilt refresh
#       $ dquilt header -e
#       ... describe patch
# 3. How to sanitize a project's Makefile for Debian:
#     - remove all `local` references to follow the FHS
#     - use $(DESTDIR), which is equal to `<package-src>/debian/package/`
#        - EX: Change all, i.e., `/usr/local/bin` to `$(DESTDIR)/usr/bin`
#     - also insert `install -d <dirname>` to ensure directories are created in $(DESTDIR)