#!/bin/bash

export STAGE=/root/l4t-usbip/38.2.2/root

# build usbip modules
cd /root/l4t/Linux_for_Tegra/source/kernel/kernel-noble

# start with live kernel config
zcat /proc/config.gz > .config

./scripts/config --module CONFIG_USBIP_CORE \
                 --module CONFIG_USBIP_VHCI_HCD \
                 --module CONFIG_USBIP_HOST

./scripts/config --set-str CONFIG_LOCALVERSION "-tegra"
./scripts/config --disable CONFIG_LOCALVERSION_AUTO
make olddefconfig

make modules_prepare
make M=drivers/usb/usbip modules

# move usbip modules to staging

make M=drivers/usb/usbip INSTALL_MOD_PATH="${STAGE}" INSTALL_MOD_DIR=updates DEPMOD=true modules_install

# build usbip tools
cd /root/l4t/Linux_for_Tegra/source/kernel/kernel-noble/tools/usb/usbip

make && make install DESTDIR="${STAGE}"

# build deb
STAGE="${1:?stage root, e.g. /root/l4t-usbip/38.2.2/root}"
VER="${2:?version}"
KVER="${3:?kernel version, e.g. 6.8.12-tegra}"
PRUNE="${4:-}"
PKG="usbip-tegra"; ARCH="arm64"
BUILD="$(mktemp -d)"; ROOT="$BUILD/${PKG}_${VER}_${ARCH}"

# build deb
cd "${STAGE}"

mkdir -p DEBIAN

cat > "DEBIAN/control" <<'EOF'
Package: usbip-tegra
Version: 38.2.2-20250925153837-1
Architecture: arm64
Maintainer: Sage <support@sagecontinuum.org>
Section: kernel
Priority: optional
Depends: libc6, libudev1, nvidia-l4t-kernel (= 6.8.12-tegra-38.2.2-20250925153837)
Homepage: https://github.com/torvalds/linux/tree/master/tools/usb/usbip
Description: USB/IP tools and kernel modules for Jetson Linux 38.2.2
 Userspace usbip and usbipd plus libusbip, installed under /usr/local,
 built from the Jetson Linux 38.2.2 kernel source tree.
 .
 Also ships the usbip-core, vhci-hcd and usbip-host kernel modules built
 against kernel 6.8.12-tegra, installed to the updates/ directory so they
 take precedence over any stock modules of the same name.
 .
 The modules are vermagic-bound to the exact kernel build, so this package
 depends on that precise nvidia-l4t-kernel version and must be rebuilt
 whenever the pinned L4T release changes.
EOF

cat > "DEBIAN/triggers" <<'EOF'
activate-noawait ldconfig
EOF

cat > "DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
KVER="6.8.12-tegra"

case "$1" in
  configure)
    # ldconfig is handled by the activate-noawait ldconfig trigger.
    # No depmod trigger exists in Debian/Ubuntu, so it stays explicit.
    if [ -d "/lib/modules/$KVER" ]; then
      depmod -a "$KVER"
    fi
    ;;
esac
exit 0
EOF

cat > "DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

case "$1" in
  remove|deconfigure)
    modprobe -r usbip-host vhci-hcd usbip-core 2>/dev/null || true
    ;;
esac
exit 0
EOF

cat > "DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
KVER="6.8.12-tegra"

case "$1" in
  remove)
    # ldconfig again handled by the trigger; only depmod needed here
    if [ -d "/lib/modules/$KVER" ]; then
      depmod -a "$KVER" 2>/dev/null || true
    fi
    ;;
esac
exit 0
EOF

chmod 775 DEBIAN/postinst DEBIAN/prerm DEBIAN/postrm

dpkg-deb --root-owner-group --build "${STAGE}" "../usbip-tegra_38.2.2-20250925153837-1_arm64.deb"

# need to add postinst dep... -a / ldconfig
