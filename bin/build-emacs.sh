#!/usr/bin/env bash
#
# build-emacs.sh
#
# Build GNU Emacs 31.1 inside a throwaway podman container and install it
# under ~/.local/emacs on the host. The build container is automatically
# matched to the HOST distro (detected from /etc/os-release):
#
#   Fedora / RHEL / secureblue   -> registry.fedoraproject.org/fedora:<ver> + dnf
#   Ubuntu                       -> docker.io/library/ubuntu:<ver> + apt
#   Debian (and derivatives)     -> docker.io/library/debian:<ver> + apt
#
# This way the binary always links against the same library sonames the host
# has. On apt hosts, native compilation installs the libgccjit dev package
# matching the default gcc (Debian/Ubuntu keep libgccjit.so in gcc's private
# per-version dir, so compiler and libgccjit versions must match). Minimal
# Ubuntu/Debian images get xz-utils installed, since tar needs it to unpack
# the source tarball. Nothing is ever installed on the host; the container
# is discarded after.
#
# Builds a PGTK/Wayland GUI by default when a Wayland/X session is actually
# RUNNING (env vars, logind session types, or compositor processes). On
# machines with no running graphical session (headless servers) it
# automatically builds a terminal-only Emacs. Override with NOX=0 (force
# GUI) or NOX=1 (force nox).
#
# All long-running podman commands run through a cancellable wrapper, so
# Ctrl+C stops the script immediately and removes the build container.
#
# Options (environment variables):
#   EMACS_VER        Emacs version to build          (default: 31.1)
#   RELEASE          container tag override          (default: host VERSION_ID)
#   CONTAINER_IMAGE  base image override             (default: auto-matched)
#   PKG_MGR          dnf | apt override              (default: auto-matched)
#   NATIVE_COMP      yes | aot | no                  (default: yes)
#                    aot = fully ahead-of-time compiled (longer build)
#   XWIDGETS         1 = enable WebKit-based xwidgets (default: 0)
#   NOX              1 = terminal-only Emacs, 0 = GUI (default: inferred from
#                        whether a Wayland/X session is currently running)
#   GRAMMARS         space-separated tree-sitter grammar NAMES to bundle
#                    (default: bash c cpp css go javascript json python rust toml yaml)
#                    (set to "" to skip)
#   WORK             workspace dir                   (default: ~/.src/emacs-build)
#   JOBS             parallel make jobs              (default: nproc)
#   SKIP_INSTALL     1 = only build + tarball, do not touch ~/.local
#   FORCE_DESKTOP    1 = install desktop entry/icons even without a
#                        graphical session detected
#
# Examples:
#   ./build-emacs.sh
#   NOX=1 ./build-emacs.sh
#   NOX=0 ./build-emacs.sh          # force GUI build on a headless server
#   NATIVE_COMP=aot XWIDGETS=1 ./build-emacs.sh
#   GRAMMARS="bash python" ./build-emacs.sh
#   GRAMMARS="" SKIP_INSTALL=1 ./build-emacs.sh

set -euo pipefail

EMACS_VER="${EMACS_VER:-31.1}"
NATIVE_COMP="${NATIVE_COMP:-yes}"
XWIDGETS="${XWIDGETS:-0}"
GRAMMARS="${GRAMMARS:-bash c cpp css go javascript json python rust toml yaml}"
WORK="${WORK:-$HOME/.src/emacs-build}"
JOBS="${JOBS:-$(nproc)}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"

SRC="$WORK/src"
OUT="$WORK/out"
PREFIX="$HOME/.local/emacs"
STAGE_SUB="${PREFIX#/}"                      # path inside the staging tree, no leading /
SRC_TARBALL="emacs-${EMACS_VER}.tar.xz"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v podman >/dev/null 2>&1 || die "podman not found"
command -v curl  >/dev/null 2>&1 || die "curl not found"

# Run a (long) command in a way that Ctrl+C cancels it instantly. Bash
# postpones acting on SIGINT while it waits for a foreground child, and
# podman can take a long time to tear down - which made the script feel
# uncancellable. Backgrounding the child keeps it in our process group (it
# receives SIGINT too) and makes `wait` return as soon as it dies.
cancellable() {
  "$@" &
  local pid=$!
  local st=0
  wait "$pid" || st=$?
  return "$st"
}

# ----------------------------------------------------------------------------
# 0. NOX mode: explicit choice, or inferred from whether a graphical session
#    is CURRENTLY RUNNING. Installed-but-idle graphical libraries say nothing
#    about that (servers often have libgtk pulled in as a dependency), so we
#    never look at packages/libraries - only at live sessions and processes.
# ----------------------------------------------------------------------------
NOX_RAW="${NOX:-}"
case "${NOX_RAW,,}" in
  1|yes|true)  NOX=1 ;;
  0|no|false)  NOX=0 ;;
  "")          NOX="" ;;               # infer below
  *) die "NOX must be 0, 1, or unset (got: '$NOX_RAW')" ;;
esac

if [[ -z "$NOX" ]]; then
  graphical=0
  reason=""

  # a) Invoked from inside a live graphical session. Skip DISPLAY over SSH:
  #    with X11 forwarding it is localhost:N.N and proves nothing about a
  #    local session.
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    graphical=1; reason="WAYLAND_DISPLAY is set in this shell"
  elif [[ -n "${DISPLAY:-}" && -z "${SSH_CONNECTION:-}" ]]; then
    graphical=1; reason="DISPLAY is set in this shell"
  fi

  # b) logind reports any session of type x11 or wayland. This catches a
  #    graphical session on the console even when you run this script over
  #    SSH (where the env check above cannot fire).
  if [[ $graphical -eq 0 ]] && command -v loginctl >/dev/null 2>&1; then
    for sid in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
      stype="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)"
      if [[ "$stype" == "x11" || "$stype" == "wayland" ]]; then
        graphical=1; reason="logind session $sid has type '$stype'"
        break
      fi
    done
  fi

  # c) Fallback: a compositor or X server process is alive (covers hosts
  #    without loginctl or with a restricted session listing).
  if [[ $graphical -eq 0 ]] && command -v pgrep >/dev/null 2>&1; then
    for proc in Xorg Xwayland gnome-shell plasmashell kwin_wayland kwin_x11 \
                weston sway labwc Hyprland wayfire niri river; do
      if pgrep -ix "$proc" >/dev/null 2>&1; then
        graphical=1; reason="process '$proc' is running"
        break
      fi
    done
  fi

  if [[ $graphical -eq 1 ]]; then
    NOX=0
    echo "==> NOX: 0 (auto: graphical session running - $reason)"
  else
    NOX=1
    echo "==> NOX: 1 (auto: no Wayland/X session running - building terminal-only Emacs)"
  fi
fi

# ----------------------------------------------------------------------------
# 0b. Detect the host distro and pick a matching build container
# ----------------------------------------------------------------------------
OS_ID=""; OS_LIKE=""; OS_VER=""
if [[ -r /etc/os-release ]]; then
  OS_ID="$(. /etc/os-release && printf '%s' "${ID:-}")"
  OS_LIKE="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"
  OS_VER="$(. /etc/os-release && printf '%s' "${VERSION_ID:-}")"
fi
HAYSTACK="$(printf '%s %s' "$OS_ID" "$OS_LIKE" | tr '[:upper:]' '[:lower:]')"

if [[ "$OS_ID" == "fedora" ]] || [[ "$HAYSTACK" == *fedora* || "$HAYSTACK" == *rhel* || "$HAYSTACK" == *centos* ]]; then
  FAMILY="fedora"
elif [[ "$OS_ID" == "ubuntu" ]] || [[ "$HAYSTACK" == *ubuntu* ]]; then
  FAMILY="ubuntu"
elif [[ "$OS_ID" == "debian" ]] || [[ "$HAYSTACK" == *debian* ]]; then
  FAMILY="debian"
else
  FAMILY="fedora"
  echo "WARNING: could not identify host distro ('$OS_ID'); defaulting to a Fedora build container."
fi

PKG_MGR="${PKG_MGR:-}"
if [[ -z "$PKG_MGR" ]]; then
  case "$FAMILY" in
    fedora) PKG_MGR="dnf" ;;
    ubuntu|debian) PKG_MGR="apt" ;;
  esac
fi

REL="${RELEASE:-$OS_VER}"
[[ -z "$REL" ]] && REL="latest"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-}"
if [[ -z "$CONTAINER_IMAGE" ]]; then
  case "$FAMILY" in
    fedora) CONTAINER_IMAGE="registry.fedoraproject.org/fedora:${REL}" ;;
    ubuntu) CONTAINER_IMAGE="docker.io/library/ubuntu:${REL}" ;;
    debian) CONTAINER_IMAGE="docker.io/library/debian:${REL}" ;;
  esac
fi

case "$FAMILY" in
  fedora) DISTRO_TAG="fc${REL}" ;;
  ubuntu) DISTRO_TAG="u${REL//./}" ;;
  debian) DISTRO_TAG="d${REL//./}" ;;
esac

FLAVOR="pgtk"
[[ "$NOX" == 1 ]] && FLAVOR="nox"
OUT_TARBALL="emacs-${EMACS_VER}-${FLAVOR}-${DISTRO_TAG}.tar.gz"

echo "==> Host system : ${OS_ID:-unknown} ${OS_VER:-} (family: $FAMILY, pkg mgr: $PKG_MGR)"
echo "==> Build image : $CONTAINER_IMAGE"

mkdir -p "$SRC" "$OUT"

# ----------------------------------------------------------------------------
# 0c. Repair workspace ownership if a previous container run left it owned by
#     an unmapped UID (rootless podman maps container UIDs != 0 to subordinate
#     host UIDs, locking your account out). Container root maps to your host
#     user, so chowning from inside a container fixes it.
# ----------------------------------------------------------------------------
if [[ -d "$WORK" ]] && ! [[ -O "$WORK" ]]; then
  echo "==> Repairing workspace ownership via container"
  cancellable podman run --rm --pull=missing -v "$WORK:/mnt:Z" "$CONTAINER_IMAGE" chown -R 0:0 /mnt
fi

# ----------------------------------------------------------------------------
# 1. Download the Emacs source tarball (host side)
# ----------------------------------------------------------------------------
# Reuse a tarball from the previous build layout, if one exists
OLD_SRC="$HOME/emacs-build-${EMACS_VER}/src/$SRC_TARBALL"
if [[ ! -s "$SRC/$SRC_TARBALL" && -s "$OLD_SRC" ]]; then
  echo "==> Reusing previously downloaded $SRC_TARBALL from $OLD_SRC"
  mv "$OLD_SRC" "$SRC/$SRC_TARBALL"
fi

if [[ ! -s "$SRC/$SRC_TARBALL" ]]; then
  echo "==> Downloading $SRC_TARBALL"
  curl -fL --retry 3 -o "$SRC/$SRC_TARBALL" "https://ftp.gnu.org/gnu/emacs/$SRC_TARBALL"
fi
# Optional: verify the PGP signature
#   curl -fL -o "$SRC/$SRC_TARBALL.sig" "https://ftp.gnu.org/gnu/emacs/$SRC_TARBALL.sig"
#   gpg --verify "$SRC/$SRC_TARBALL.sig" "$SRC/$SRC_TARBALL"

# ----------------------------------------------------------------------------
# 2. The build script that runs INSIDE the container
# ----------------------------------------------------------------------------
rm -f "$WORK/container-build.sh"
cat > "$WORK/container-build.sh" <<'CONTAINER_SCRIPT'
set -euo pipefail
: "${EMACS_VER:?} ${PREFIX:?} ${STAGE_SUB:?} ${JOBS:?} ${NATIVE_COMP:?} ${XWIDGETS:?} ${NOX:?} ${GRAMMARS:?} ${PKG_MGR:?} ${OUT_TARBALL:?}"

STAGE="/work/out/stage"
LIBSTAGE="$STAGE/$STAGE_SUB/lib"
mkdir -p "$LIBSTAGE"

# Normalize workspace ownership: container root maps to the host user, so
# everything left on the mount ends up owned by you on the host.
chown -R 0:0 /work 2>/dev/null || true

# ---------------------------------------------------------------- helpers
pkg_has() {
  case "$PKG_MGR" in
    dnf) rpm -q "$1" >/dev/null 2>&1 ;;
    apt) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -qx 'install ok installed' ;;
  esac
}
# dnf resolves names at install time; apt needs explicit availability checks
# (a wrong name aborts the whole transaction).
pkg_avail() {
  case "$PKG_MGR" in
    dnf) return 0 ;;
    apt) apt-cache show "$1" >/dev/null 2>&1 ;;
  esac
}
pkg_install() {
  case "$PKG_MGR" in
    dnf) dnf -y --setopt=install_weak_deps=False install "$@" ;;
    apt) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" ;;
  esac
}

echo "==> [container] Installing build dependencies ($PKG_MGR)"
if [[ "$PKG_MGR" == "apt" ]]; then
  apt-get update -qq
fi

CONFIG_FEATURES=""
TREE_SITTER=no
SQLITE=no
XW_OK=no

if [[ "$PKG_MGR" == "dnf" ]]; then
  PKGS=(
    gcc make texinfo autoconf findutils diffutils xz
    glib2-devel dbus-devel gnutls-devel libxml2-devel ncurses-devel zlib-devel libacl-devel
    libselinux-devel systemd-devel
    libgccjit-devel libtree-sitter-devel sqlite-devel
  )
  if [[ "$NOX" == 0 ]]; then
    PKGS+=(
      gtk3-devel cairo-devel harfbuzz-devel fontconfig-devel freetype-devel
      alsa-lib-devel
      libpng-devel libjpeg-turbo-devel giflib-devel libtiff-devel libwebp-devel
      librsvg2-devel libotf-devel m17n-lib-devel
    )
    if [[ "$XWIDGETS" == 1 ]]; then PKGS+=(webkit2gtk4.1-devel); fi
  fi

  missing=()
  for p in "${PKGS[@]}"; do
    if ! pkg_has "$p"; then missing+=("$p"); fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "  all build dependencies already present"
  else
    pkg_install "${missing[@]}"
  fi

  TREE_SITTER=yes; SQLITE=yes
  if [[ "$NOX" == 0 ]]; then
    CONFIG_FEATURES="--with-pgtk --with-cairo --with-dbus --with-gif --with-gpm=no --with-harfbuzz --with-jpeg --with-png --with-rsvg --with-tiff --with-webp"
    if [[ "$XWIDGETS" == 1 ]]; then CONFIG_FEATURES+=" --with-xwidgets"; XW_OK=yes; fi
  else
    CONFIG_FEATURES="--without-x --without-xft --without-pgtk --without-cairo --without-rsvg --without-xwidgets --without-toolkit-scroll-bars --with-gif=no --with-jpeg=no --with-png=no --with-tiff=no --with-webp=no"
  fi
  CONFIG_FEATURES+=" --with-tree-sitter --with-sqlite3"
else
  # ---------------------------------------------------------------- apt core
  PKGS=(
    gcc g++ make texinfo autoconf pkg-config findutils diffutils
    xz-utils gzip curl ca-certificates
    libc6-dev
    libgnutls28-dev libxml2-dev libncurses-dev libtinfo-dev zlib1g-dev libacl1-dev
    libsystemd-dev libdbus-1-dev libsqlite3-dev
  )
  if [[ "$NOX" == 0 ]]; then
    PKGS+=(
      libgtk-3-dev libcairo2-dev libharfbuzz-dev
      libfontconfig-dev libfontconfig1-dev libfreetype-dev libfreetype6-dev
      libasound2-dev libasound-dev
      libpng-dev libjpeg-dev libgif-dev libtiff-dev libwebp-dev librsvg2-dev
      libotf-dev libm17n-dev
    )
    if [[ "$XWIDGETS" == 1 ]]; then PKGS+=(libwebkit2gtk-4.1-dev); fi
  fi

  if pkg_avail libtree-sitter-dev; then PKGS+=(libtree-sitter-dev); TREE_SITTER=yes; fi
  if pkg_avail libsqlite3-dev; then SQLITE=yes; fi
  if [[ "$XWIDGETS" == 1 ]] && pkg_avail libwebkit2gtk-4.1-dev; then XW_OK=yes; fi

  to_install=()
  for p in "${PKGS[@]}"; do
    if pkg_has "$p"; then continue; fi
    if pkg_avail "$p"; then
      to_install+=("$p")
    else
      echo "  !! $p not available - skipped"
    fi
  done
  if [[ ${#to_install[@]} -eq 0 ]]; then
    echo "  core build dependencies already present"
  else
    pkg_install "${to_install[@]}"
  fi

  # ------------------------------------------- native compilation (apt hosts)
  # On Debian/Ubuntu libgccjit.so is NOT on the default linker path: it is
  # installed in gcc's per-version private dir (/usr/lib/gcc/<target>/<ver>/),
  # which only a matching-version gcc exposes to the linker. So install the
  # dev package matching the DEFAULT gcc; if none matches, fall back to the
  # newest one plus its matching gcc-N and switch CC accordingly.
  if [[ "$NATIVE_COMP" != "no" ]]; then
    DEFAULT_GCCV="$(gcc -dumpversion 2>/dev/null || true)"
    [[ "$DEFAULT_GCCV" == *.* ]] && DEFAULT_GCCV="${DEFAULT_GCCV%%.*}"
    CANDS="$(apt-cache search --names-only '^libgccjit-[0-9]+-dev$' 2>/dev/null | awk '{print $1}' | sort -V)"
    LIBGCCJIT_DEV=""
    if [[ -n "$DEFAULT_GCCV" && -n "$CANDS" ]]; then
      LIBGCCJIT_DEV="$(printf '%s\n' "$CANDS" | grep -E "^libgccjit-${DEFAULT_GCCV}-dev$" | head -n1 || true)"
    fi
    if [[ -z "$LIBGCCJIT_DEV" && -n "$CANDS" ]]; then
      LIBGCCJIT_DEV="$(printf '%s\n' "$CANDS" | tail -n1)"
    fi
    if [[ -z "$LIBGCCJIT_DEV" ]]; then
      echo "  !! no libgccjit dev package found - building without native compilation"
      NATIVE_COMP=no
    else
      JIT_VER="${LIBGCCJIT_DEV#libgccjit-}"; JIT_VER="${JIT_VER%%-*}"
      extra=("$LIBGCCJIT_DEV")
      if ! pkg_has "gcc-$JIT_VER" && pkg_avail "gcc-$JIT_VER"; then
        extra+=("gcc-$JIT_VER")
      fi
      pkg_install "${extra[@]}"
    fi
  fi

  # Verify the (matching) compiler can actually see libgccjit.so; if not,
  # locate it and align CC / LDFLAGS before configure runs.
  if [[ "$NATIVE_COMP" != "no" ]]; then
    JIT_SO="$(gcc -print-file-name=libgccjit.so 2>/dev/null || true)"
    if [[ "$JIT_SO" == "libgccjit.so" || ! -e "$JIT_SO" ]]; then
      JIT_SO="$(find -L /usr/lib/gcc -name libgccjit.so 2>/dev/null | head -n1 || true)"
      if [[ -n "$JIT_SO" ]]; then
        JIT_DIR="$(dirname "$JIT_SO")"
        JIT_DIRV="${JIT_DIR##*/}"
        if [[ -x "/usr/bin/gcc-$JIT_DIRV" ]]; then
          export CC="/usr/bin/gcc-$JIT_DIRV"
          echo "  default gcc does not match libgccjit ($JIT_DIRV) - building with $CC instead"
        fi
        export LDFLAGS="${LDFLAGS:+$LDFLAGS }-L$JIT_DIR"
        JIT_SO="$("${CC:-gcc}" -print-file-name=libgccjit.so 2>/dev/null || true)"
      fi
    fi
    if [[ -z "$JIT_SO" || "$JIT_SO" == "libgccjit.so" || ! -e "$JIT_SO" ]]; then
      echo "  !! libgccjit.so not usable - building without native compilation"
      NATIVE_COMP=no
    else
      echo "  native compilation: libgccjit from $(dirname "$JIT_SO")"
    fi
  fi

  if [[ "$NOX" == 0 ]]; then
    # GTK and the image libraries are auto-detected by configure; only pin
    # what must not silently differ.
    CONFIG_FEATURES="--with-pgtk --with-gpm=no"
    if [[ "$XW_OK" == yes ]]; then CONFIG_FEATURES+=" --with-xwidgets"; fi
  else
    CONFIG_FEATURES="--without-x --without-xft --without-pgtk --without-cairo --without-rsvg --without-xwidgets --without-toolkit-scroll-bars --with-gif=no --with-jpeg=no --with-png=no --with-tiff=no --with-webp=no"
  fi
  if [[ "$TREE_SITTER" == yes ]]; then CONFIG_FEATURES+=" --with-tree-sitter"; fi
  if [[ "$SQLITE" == yes ]]; then CONFIG_FEATURES+=" --with-sqlite3"; fi
fi

# Preflight: fail early and clearly if an unpack tool is somehow missing
# (tar shells out to external decompressors for .xz).
for tool in tar xz gzip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "!! required tool '$tool' missing in container"; exit 1; }
done

echo "==> [container] Unpacking source"
cd /work/src
rm -rf "emacs-${EMACS_VER}"
tar -xf "emacs-${EMACS_VER}.tar.xz"
cd "emacs-${EMACS_VER}"

echo "==> [container] Configuring"
mkdir -p build && cd build
../configure \
  --prefix="$PREFIX" \
  --with-modules \
  --with-native-compilation="$NATIVE_COMP" \
  $CONFIG_FEATURES \
  > /work/configure.log 2>&1 \
  || { tail -100 /work/configure.log; exit 1; }
grep -E 'Does Emacs use|Configured for' /work/configure.log || true

echo "==> [container] Building with $JOBS jobs (this is the long part)"
make -j"$JOBS"

echo "==> [container] Installing into staging tree"
make install DESTDIR="$STAGE"

# ---------------------------------------------------------------- bundling
echo "==> [container] Bundling runtime-only libraries into prefix/lib"
bundle_glob() {
  local pat=$1 f
  while IFS= read -r f; do
    cp -a "$f" "$LIBSTAGE"/ 2>/dev/null || true
  done < <(find -L /usr/lib64 /usr/lib /lib64 /lib -name "$pat" 2>/dev/null | sort -u)
}

bundle_glob 'libgccjit.so*'
bundle_glob 'libtree-sitter.so.0*'
# libxml2 soname churn across distros (libxml2.so.2 <-> libxml2.so.16):
# always ship the exact copy the binary was linked against.
bundle_glob 'libxml2.so*'
if [[ "$NOX" == 0 ]]; then
  bundle_glob 'libotf.so*'
  bundle_glob 'libm17n*.so*'
fi

# ---------------------------------------------------------------- grammars
if [[ -n "$GRAMMARS" ]]; then
  echo "==> [container] Tree-sitter grammars"
  if [[ "$PKG_MGR" == "dnf" ]]; then
    gmissing=()
    for g in $GRAMMARS; do
      if ! pkg_has "libtree-sitter-$g"; then gmissing+=("libtree-sitter-$g"); fi
    done
    if [[ ${#gmissing[@]} -gt 0 ]]; then
      if ! pkg_install "${gmissing[@]}"; then
        echo "!! batch install failed - retrying grammars individually"
        for gp in "${gmissing[@]}"; do
          pkg_install "$gp" || echo "!! grammar $gp unavailable - skipped"
        done
      fi
    fi
    bundle_glob 'libtree-sitter-*.so*'
    while IFS= read -r f; do
      cp -a "$f" "$LIBSTAGE"/ 2>/dev/null || true
    done < <(find -L /usr/lib64 /usr/lib -path '*/tree-sitter/*.so*' 2>/dev/null | sort -u)
  else
    # apt hosts: distro -src packages where available, upstream tarballs as
    # fallback, compiled inside this container.
    build_grammar() {
      local g=$1 tmp srcdir url tag c
      tmp="$(mktemp -d)"
      srcdir=""
      if pkg_avail "tree-sitter-$g-src" && ! pkg_has "tree-sitter-$g-src"; then
        pkg_install "tree-sitter-$g-src" || true
      fi
      if pkg_has "tree-sitter-$g-src"; then
        srcdir="$(find /usr/src/tree-sitter -type f -name parser.c -path "*/$g/*" 2>/dev/null | head -n1 || true)"
        srcdir="${srcdir%/parser.c}"
      fi
      if [[ -z "$srcdir" ]]; then
        echo "  $g: fetching source from GitHub"
        tag="$(curl -fsSL --retry 2 "https://api.github.com/repos/tree-sitter/tree-sitter-$g/releases/latest" 2>/dev/null \
               | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1 || true)"
        if [[ -n "$tag" ]]; then
          url="https://github.com/tree-sitter/tree-sitter-$g/archive/refs/tags/$tag.tar.gz"
        else
          url="https://github.com/tree-sitter/tree-sitter-$g/archive/refs/heads/master.tar.gz"
        fi
        curl -fsSL --retry 2 -o "$tmp/src.tgz" "$url" \
          || curl -fsSL --retry 2 -o "$tmp/src.tgz" "https://github.com/tree-sitter/tree-sitter-$g/archive/refs/heads/main.tar.gz"
        tar -xzf "$tmp/src.tgz" -C "$tmp" --strip-components=1
        srcdir="$tmp/src"
      fi
      local objs=() o
      shopt -s nullglob
      for c in "$srcdir"/*.c; do
        o="$tmp/$(basename "${c%.c}").o"
        cc -O2 -fPIC -I "$srcdir" -c "$c" -o "$o"
        objs+=("$o")
      done
      for c in "$srcdir"/*.cc; do
        o="$tmp/$(basename "${c%.cc}").o"
        c++ -O2 -fPIC -I "$srcdir" -c "$c" -o "$o"
        objs+=("$o")
      done
      shopt -u nullglob
      cc -shared -o "$LIBSTAGE/libtree-sitter-$g.so" "${objs[@]}"
    }
    for g in $GRAMMARS; do
      if build_grammar "$g"; then
        echo "  built: libtree-sitter-$g.so"
      else
        echo "!! grammar $g failed - skipped"
      fi
    done
  fi
fi

# Make sure an app icon exists for the desktop entry (GUI only)
if [[ "$NOX" == 0 ]]; then
  ICONSTAGE="$STAGE/$STAGE_SUB/share/icons/hicolor"
  if [[ ! -d "$ICONSTAGE" ]]; then
    mkdir -p "$ICONSTAGE"
    cp -a ../etc/icons/hicolor/scalable "$ICONSTAGE"/ 2>/dev/null || true
  fi
fi

echo "==> [container] Packing $OUT_TARBALL"
cd "$STAGE"
# Pack into the container's own filesystem; the host pulls this out with
# `podman cp`, which writes it as a normal file owned by the host user.
tar -czf /root/emacs-artifact.tar.gz "$STAGE_SUB"
# Best-effort debug copy on the shared mount + free the ~1-2 GB staging tree.
cp /root/emacs-artifact.tar.gz "/work/out/$OUT_TARBALL"
rm -rf "$STAGE"

echo "==> [container] Done"
CONTAINER_SCRIPT

# ----------------------------------------------------------------------------
# 3. Run the container build, then pull the artifact out with podman cp
# ----------------------------------------------------------------------------
NAME="emacs-build-${EMACS_VER}-$$"
podman rm -f "$NAME" >/dev/null 2>&1 || true

cleanup_build() {
  local rc=$?
  trap - INT TERM EXIT
  set +e
  if [[ "$rc" -ne 0 ]]; then
    echo
    echo "==> Build interrupted or failed (rc=$rc) - removing build container"
  fi
  timeout 60 podman rm -f "$NAME" >/dev/null 2>&1
  exit "$rc"
}
trap cleanup_build EXIT
trap 'exit 130' INT TERM

echo "==> Building in container: $CONTAINER_IMAGE   (Ctrl+C cancels and cleans up)"
BUILD_RC=0
cancellable podman run --pull=missing \
  --name "$NAME" \
  -v "$WORK:/work:Z" \
  -e EMACS_VER="$EMACS_VER" -e PREFIX="$PREFIX" -e STAGE_SUB="$STAGE_SUB" \
  -e JOBS="$JOBS" -e NATIVE_COMP="$NATIVE_COMP" -e XWIDGETS="$XWIDGETS" \
  -e NOX="$NOX" -e GRAMMARS="$GRAMMARS" -e PKG_MGR="$PKG_MGR" \
  -e OUT_TARBALL="$OUT_TARBALL" \
  "$CONTAINER_IMAGE" \
  bash /work/container-build.sh || BUILD_RC=$?

if [[ "$BUILD_RC" -ne 0 ]]; then
  echo "!! container build failed (rc=$BUILD_RC)"
  exit "$BUILD_RC"
fi

echo "==> Copying artifact out of the container"
rm -f "$OUT/$OUT_TARBALL"
cancellable podman cp "$NAME:/root/emacs-artifact.tar.gz" "$OUT/$OUT_TARBALL"

podman rm -f "$NAME" >/dev/null 2>&1 || true
trap - INT TERM EXIT
echo "==> Tarball ready: $OUT/$OUT_TARBALL"

# ----------------------------------------------------------------------------
# 4. Install onto the host (only under ~/.local and ~/.config)
# ----------------------------------------------------------------------------
if [[ "$SKIP_INSTALL" == 1 ]]; then
  echo "SKIP_INSTALL=1 - stopping here. Tarball is in $OUT"
  exit 0
fi

echo "==> Installing into $PREFIX"
[[ -s "$OUT/$OUT_TARBALL" ]] || die "output tarball missing"
PARENT="$(dirname "$PREFIX")"
mkdir -p "$PARENT"
STRIP=$(( $(printf '%s' "$STAGE_SUB" | tr -cd '/' | wc -c) ))
tar -xzf "$OUT/$OUT_TARBALL" -C "$PARENT" --strip-components="$STRIP"
[[ -x "$PREFIX/bin/emacs" ]] || die "install failed: $PREFIX/bin/emacs not found"

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons"

# Wrapper binary (provides the bundled libraries via LD_LIBRARY_PATH)
cat > "$HOME/.local/bin/emacs" <<EOF
#!/bin/sh
# GNU Emacs $EMACS_VER ($FLAVOR, $DISTRO_TAG) - built in a podman container
export LD_LIBRARY_PATH="$PREFIX/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$PREFIX/bin/emacs" "\$@"
EOF
chmod 755 "$HOME/.local/bin/emacs"
ln -sf "$PREFIX/bin/emacsclient" "$HOME/.local/bin/emacsclient"

# Desktop entry and icons only when a graphical session is live in the
# installing shell
GRAPHICAL=0
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then GRAPHICAL=1; fi
if [[ "${FORCE_DESKTOP:-0}" == 1 ]]; then GRAPHICAL=1; fi

if [[ "$NOX" == 0 && "$GRAPHICAL" == 1 ]]; then
  [[ -d "$PREFIX/share/icons/hicolor" ]] && \
    cp -a "$PREFIX/share/icons/hicolor/." "$HOME/.local/share/icons/hicolor/"

  cat > "$HOME/.local/share/applications/emacs-${EMACS_VER}.desktop" <<EOF
[Desktop Entry]
Name=Emacs ${EMACS_VER} (PGTK)
GenericName=Text Editor
Comment=GNU Emacs ${EMACS_VER} - pure GTK (Wayland) build
Exec=$HOME/.local/bin/emacs %F
TryExec=$HOME/.local/bin/emacs
Icon=emacs
Terminal=false
Type=Application
Categories=Development;TextEditor;
StartupWMClass=Emacs
MimeType=text/plain;
Keywords=Text;Editor;
EOF
elif [[ "$NOX" == 0 ]]; then
  echo "  No graphical session detected - skipping desktop entry/icons (FORCE_DESKTOP=1 to override)"
fi

# Systemd user service fix: the unit shipped by Emacs points directly at the
# real binary, bypassing our LD_LIBRARY_PATH wrapper. Add a drop-in that gives
# the service the bundled library path so `systemctl --user start emacs` works.
if [[ -d "$PREFIX/lib/systemd/user" ]]; then
  echo "==> Installing systemd user drop-in for emacs.service"
  DROPIN="$HOME/.config/systemd/user/emacs.service.d"
  mkdir -p "$DROPIN"
  cat > "$DROPIN/ld-library-path.conf" <<EOF
[Service]
Environment="LD_LIBRARY_PATH=$PREFIX/lib"
EOF
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    echo "  Reloaded systemd user daemon."
    if systemctl --user is-active --quiet emacs 2>/dev/null; then
      echo "  Restarting emacs.service"
      systemctl --user restart emacs || true
    fi
  fi
fi

# ----------------------------------------------------------------------------
# 5. Sanity check + cross-distro library fixup
# ----------------------------------------------------------------------------
# The binary was linked inside the build container. If the host still lacks a
# soname for any reason, bundle it straight from a fresh container until `ldd`
# comes back clean.
echo "==> Checking dynamic libraries (with bundled libs on LD_LIBRARY_PATH)"
FIXUP_PASSES=0
MISSING=$(LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ldd "$PREFIX/bin/emacs" 2>/dev/null | awk '/not found/{print $1}' | sort -u)
while [[ -n "$MISSING" && "$FIXUP_PASSES" -lt 5 ]]; do
  FIXUP_PASSES=$((FIXUP_PASSES + 1))
  echo "  Host is missing: $(printf '%s ' $MISSING)"
  echo "  Bundling them from a fresh container (pass $FIXUP_PASSES)"
  cancellable podman run --rm --pull=missing -v "$PREFIX/lib:/mnt:Z" \
    -e MISSING_LIBS="$MISSING" -e PKG_MGR="$PKG_MGR" "$CONTAINER_IMAGE" \
    bash -c '
      set -uo pipefail
      for lib in $MISSING_LIBS; do
        f=""
        for base in /usr/lib64 /usr/lib /lib64 /lib; do
          hit="$(find -L "$base" -name "$lib" 2>/dev/null | head -n1)"
          if [[ -n "$hit" ]]; then f="$hit"; break; fi
        done
        if [[ -z "$f" && "$PKG_MGR" == "dnf" ]]; then
          dnf -yq --setopt=install_weak_deps=False install "/usr/lib64/$lib" >/dev/null 2>&1 || true
          f="$(find -L /usr/lib64 /usr/lib -name "$lib" 2>/dev/null | head -n1)"
        fi
        if [[ -n "$f" ]]; then
          cp -L "$f" /mnt/ && echo "  bundled: $lib" || echo "  !! could not copy $lib"
        else
          echo "  !! $lib not found in container - still missing"
        fi
      done'
  MISSING=$(LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ldd "$PREFIX/bin/emacs" 2>/dev/null | awk '/not found/{print $1}' | sort -u)
done

if [[ -z "$MISSING" ]]; then
  echo "  All shared libraries resolve - binary is ready to run."
else
  echo "WARNING: these libraries are still missing after 5 fixup passes:"
  echo "$MISSING" | sed 's/^/  - /'
fi

echo
echo "Done."
echo "  Built for       : $FAMILY ${REL} via $CONTAINER_IMAGE ($PKG_MGR)"
echo "  Flavor          : $FLAVOR"
echo "  Run it          : $HOME/.local/bin/emacs   (this wrapper sets LD_LIBRARY_PATH)"
echo "  Direct binary   : $PREFIX/bin/emacs   (requires LD_LIBRARY_PATH=$PREFIX/lib)"
echo "  Systemd service : systemctl --user enable --now emacs"
if [[ "$NOX" == 0 && "$GRAPHICAL" == 1 ]]; then
  echo "  App grid entry  : 'Emacs ${EMACS_VER} (PGTK)' (may require re-login to appear)"
fi
echo "  Daemon + client : emacs --daemon  /  emacsclient -c"
if [[ "$PKG_MGR" == "apt" && "$NATIVE_COMP" != "no" ]]; then
  echo
  echo "  NOTE (native-comp): runtime .eln compilation uses the gcc toolchain the"
  echo "  binary was built with. If the host lacks it, Emacs still runs fine but"
  echo "  silently falls back to bytecode - install a matching compiler for full"
  echo "  native compilation at runtime:"
  echo "    sudo apt install gcc"
fi
echo
echo "  Tree-sitter grammars were bundled into $PREFIX/lib - add to your init.el:"
echo "    (add-to-list 'treesit-extra-load-path (expand-file-name \"~/.local/emacs/lib\"))"
echo
echo "  Uninstall:"
echo "    rm -rf $PREFIX $HOME/.local/bin/emacs $HOME/.local/bin/emacsclient \\"
if [[ "$NOX" == 0 ]]; then
  echo "      $HOME/.local/share/applications/emacs-${EMACS_VER}.desktop \\"
fi
echo "      $HOME/.config/systemd/user/emacs.service.d"
echo "  Free build cache: rm -rf $WORK   (plus the old ~/emacs-build-${EMACS_VER} if present)"

