function __emacs_build
    set -l EMACS_VERSION 29.4
    set -l BUILD_PARENT_DIR /root
    set -l BUILD_DIR $BUILD_PARENT_DIR/emacs-$EMACS_VERSION
    set -l CONTAINER_NAME box

    if exists nm-online
        nm-online || exit
    end

    set -l TAR_LOC (mktemp)
    wget http://ftp.acc.umu.se/mirror/gnu.org/gnu/emacs/emacs-29.4.tar.gz -O $TAR_LOC

    $CONTAINER_NAME sudo bash -c "\
        cd $BUILD_PARENT_DIR; \
        tar xvf $TAR_LOC; \
        cd $BUILD_DIR; \
        dnf install -y autoconf; \
        dnf builddep -y emacs; \
        ./autogen.sh; \
        ./configure --prefix=/usr --with-native-compilation \
            --with-tree-sitter --with-pgtk; \
        make -j$(nproc) install;"
end
