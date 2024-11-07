#!/bin/bash

# Set variables
CHROOT_DIR="kaynak"
ISO_WORK_DIR="isowork"
ISO_OUTPUT="bismih-amd64.iso"

# set up chroot environment
setup_chroot() {
    rm -rf "${CHROOT_DIR}" "${ISO_WORK_DIR}" "${ISO_OUTPUT}"
    mkdir "${CHROOT_DIR}"
    chown root "${CHROOT_DIR}"

    echo "İşlem başlıyor haydi bismillah..."

    sleep 5

    debootstrap --arch=amd64 yirmiuc-deb "${CHROOT_DIR}" http://depo.pardus.org.tr/pardus

    for i in dev dev/pts proc sys; do
        mount -o bind "/$i" "${CHROOT_DIR}/$i"
    done
}

# add repositories and keys
add_repositories() {
    echo "depo ekleniyor..."
    echo 'deb http://depo.pardus.org.tr/pardus yirmiuc-deb main contrib non-free non-free-firmware' >"${CHROOT_DIR}/etc/apt/sources.list"
    echo 'deb-src http://depo.pardus.org.tr/pardus yirmiuc-deb main contrib non-free non-free-firmware' >>"${CHROOT_DIR}/etc/apt/sources.list"
    echo 'deb http://depo.pardus.org.tr/guvenlik yirmiuc-deb main contrib non-free non-free-firmware' >>"${CHROOT_DIR}/etc/apt/sources.list"
    echo 'deb-src http://depo.pardus.org.tr/guvenlik yirmiuc-deb main contrib non-free non-free-firmware' >>"${CHROOT_DIR}/etc/apt/sources.list"
    echo 'deb http://depo.pardus.org.tr/pardus yirmiuc main contrib non-free non-free-firmware' >>"${CHROOT_DIR}/etc/apt/sources.list"
    echo 'deb-src http://depo.pardus.org.tr/pardus yirmiuc main contrib non-free non-free-firmware' >>"${CHROOT_DIR}/etc/apt/sources.list"

    echo "deb http://depo.pardus.org.tr/backports yirmiuc-backports main contrib non-free non-free-firmware" >>"${CHROOT_DIR}/etc/apt/sources.list.d/yirmiuc-backports.list"

    echo "deb [signed-by=/etc/apt/keyrings/bismih-pubkey.asc arch=$(dpkg --print-architecture)] https://bismih-org.github.io/repository/repo fethan main" >>"${CHROOT_DIR}/etc/apt/sources.list.d/bismih.list"
    # Add more repository entries as needed

    wget --quiet -O - https://bismih-org.github.io/repository/repo/bismih-pubkey.asc | tee "${CHROOT_DIR}/etc/apt/keyrings/bismih-pubkey.asc"
    wget -c https://depo.pardus.org.tr/pardus/pool/main/p/pardus-archive-keyring/pardus-archive-keyring_2021.1_all.deb -O "${CHROOT_DIR}/tmp/pardus-archive-keyring_2021.1_all.deb"
    chroot "${CHROOT_DIR}" dpkg -i /tmp/pardus-archive-keyring_2021.1_all.deb
    chroot kaynak apt update -y
    chroot kaynak apt install curl packagekit xcb ca-certificates -y
}

update_system() {
    echo "sisitem güncelleniyor..."
    chroot "${CHROOT_DIR}" apt update -y
    chroot "${CHROOT_DIR}" apt upgrade -y
    chroot "${CHROOT_DIR}" apt install --fix-missing -y
    chroot "${CHROOT_DIR}" apt install --fix-broken -y
}

install_kernel() {
    echo "çekirdek yükleniyor..."
    kernel_stablity=$1
    if [ "$kernel_stablity" == "stable" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install linux-image-amd64 -y
    elif [ "$kernel_stablity" == "backports" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install -t yirmiuc-backports linux-image-amd64 -y
    elif [ "$kernel_stablity" == "rolling" ]; then
        wget --quiet -O - https://liquorix.net/liquorix-keyring.gpg | tee "${CHROOT_DIR}/etc/apt/keyrings/liquorix-keyring.gpg"
        echo "deb [signed-by=/etc/apt/keyrings/liquorix-keyring.gpg arch=$(dpkg --print-architecture)] https://liquorix.net/debian bookworm main" >>"${CHROOT_DIR}/etc/apt/sources.list.d/liquorix.list"
        chroot "${CHROOT_DIR}" apt update -y
        chroot "${CHROOT_DIR}" apt install linux-image-liquorix-amd64 linux-headers-liquorix-amd64
    else
        echo "Invalid kernel stability! Usage: install_kernel {stable|backports|rolling}"
    fi
    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install -t yirmiuc-backports linux-image-amd64 -y
}

set_system_locale() {
    echo "dil ayarlanıyor..."
    chroot "${CHROOT_DIR}" apt install -y locales
    chroot "${CHROOT_DIR}" locale-gen en_US.UTF-8
    chroot "${CHROOT_DIR}" locale-gen tr_TR.UTF-8
    chroot "${CHROOT_DIR}" update-locale LANG=tr_TR.UTF-8
}

install_grub() {
    echo "grub yükleniyor..."
    #bunu dil için bi test yapılabilir
    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install grub-pc-bin grub-efi-ia32-bin grub-efi -y
    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install live-config live-boot -y
}

install_firmware() {
    echo "firmware yükleniyor..."
    echo "firmware-ipw2x00 firmware-ipw2x00/license/accepted select true" | chroot "${CHROOT_DIR}" debconf-set-selections
    echo "firmware-ivtv firmware-ivtv/license/accepted boolean true" | chroot "${CHROOT_DIR}" debconf-set-selections

    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install bluez-firmware \
        firmware-amd-graphics firmware-atheros firmware-b43-installer firmware-b43legacy-installer \
        firmware-bnx2 firmware-bnx2x firmware-brcm80211 firmware-cavium firmware-intel-sound firmware-ipw2x00 \
        firmware-ivtv firmware-iwlwifi firmware-libertas firmware-linux firmware-linux-free firmware-linux-nonfree \
        firmware-misc-nonfree firmware-myricom firmware-netxen firmware-qlogic firmware-realtek firmware-samsung \
        firmware-siano firmware-ti-connectivity firmware-zd1211 firmware-sof-signed zd1211-firmware -y
    chroot "${CHROOT_DIR}" update-initramfs -u
}

install_desktop_environment() {
    echo "masaüstü ortamı yükleniyor..."
    de=$1
    if [ "$de" == "kde" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install libappstreamqt2 appstream packagekit kde-standard -y
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt purge juk kmail* konqueror kwrite kde-spectacle zutty -y
        add_close_service
    elif [ "$de" == "gnome" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install gnome -y
    elif [ "$de" == "xfce" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install xfce -y
    elif [ "$de" == "lxde" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install lxde -y
    elif [ "$de" == "lxqt" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install lxqt -y
    elif [ "$de" == "mate" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install mate -y
    elif [ "$de" == "cinnamon" ]; then
        chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install cinnamon -y
    else
        echo "Invalid desktop environment! Usage: install_desktop_environment {kde|gnome|xfce}"
    fi
}

add_close_service() {
    echo "geç kapanma sorunu düzeltme servisi ekleniyor..."
    echo '#!/bin/sh' >"${CHROOT_DIR}/usr/lib/systemd/system-shutdown/kill_kwin.shutdown"
    echo '# Kill KWin immediately to prevent stalled shutdowns/reboots' >>"${CHROOT_DIR}/usr/lib/systemd/system-shutdown/kill_kwin.shutdown"
    echo 'pkill -KILL kwin_x11' >>"${CHROOT_DIR}/usr/lib/systemd/system-shutdown/kill_kwin.shutdown"
    chmod +x "${CHROOT_DIR}/usr/lib/systemd/system-shutdown/kill_kwin.shutdown"

    cat >"${CHROOT_DIR}/etc/systemd/system/kill_kwin.service" <<EOF
[Unit]
Description=Kill KWin at shutdown/reboot

[Service]
Type=oneshot
ExecStart=/bin/true
ExecStop=/bin/sh /usr/lib/systemd/system-shutdown/kill_kwin.shutdown
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    chmod +x "${CHROOT_DIR}/etc/systemd/system/kill_kwin.service"
    chroot "${CHROOT_DIR}" systemctl enable kill_kwin.service
    chroot "${CHROOT_DIR}" systemctl start kill_kwin.service
}

intall_pardus_packages() {
    echo "pardus paketleri yükleniyor..."
    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install pardus-about pardus-ayyildiz-grub-theme \
        pardus-backgrounds pardus-font-manager pardus-image-writer pardus-installer pardus-java-installer pardus-locales \
        pardus-menus pardus-mycomputer pardus-night-light pardus-package-installer pardus-software pardus-update \
        pardus-usb-formatter pardus-wallpaper-23-0 -y
}

install_other_packages() {
    echo "diğer paketler yükleniyor..."
    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install \
        printer-driver-all system-config-printer simple-scan blueman \
        git system-monitoring-center bash-completion libreoffice libreoffice-kf5 \
        libreoffice-l10n-tr libreoffice-style-yaru birdtray thunderbird thunderbird-l10n-tr \
        touchegg flameshot elisa xsel xdotool unrar webapp-manager appimagelauncher pkg-config -y
}

install_flatpack_and_packages() {
    echo "flatpack ve paketleri yükleniyor..."
    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt install flatpak plasma-discover-backend-flatpak -y
    chroot "${CHROOT_DIR}" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

}

clean_system() {
    echo "sistem temizleniyor..."
    chroot "${CHROOT_DIR}" apt upgrade -y
    chroot "${CHROOT_DIR}" apt autoremove -y
    chroot "${CHROOT_DIR}" apt clean -y
    rm -rf "${CHROOT_DIR}/tmp/."*
    rm -rf "${CHROOT_DIR}/tmp/*"
    rm -f "${CHROOT_DIR}/root/.bash_history"
    rm -rf "${CHROOT_DIR}/var/lib/apt/lists/*"
    find "${CHROOT_DIR}/var/log/" -type f | xargs rm -f

}

generate_iso() {
    echo "iso oluşturuluyor..."
    umount -lf -R "${CHROOT_DIR}"/* 2>/dev/null

    rm -rf "${ISO_WORK_DIR}"
    mkdir -p "${ISO_WORK_DIR}"
    mksquashfs "${CHROOT_DIR}" filesystem.squashfs -comp gzip -wildcards
    #mksquashfs "${CHROOT_DIR}" "${ISO_WORK_DIR}/live/filesystem.squashfs" -comp xz -wildcards

    mkdir -p "${ISO_WORK_DIR}/live"
    mv filesystem.squashfs "${ISO_WORK_DIR}/live/filesystem.squashfs"

    cp -pf "${CHROOT_DIR}/boot/initrd.img"* "${ISO_WORK_DIR}/live/initrd.img"
    cp -pf "${CHROOT_DIR}/boot/vmlinuz"* "${ISO_WORK_DIR}/live/vmlinuz"

    mkdir -p "${ISO_WORK_DIR}/boot"
    cp -r grub/ "${ISO_WORK_DIR}/boot/"

    grub-mkrescue "${ISO_WORK_DIR}" -o "${ISO_OUTPUT}"

}

main() {
    setup_chroot
    add_repositories
    update_system
    install_kernel "backports"
    set_system_locale
    install_grub
    install_firmware
    install_desktop_environment "kde"
    intall_pardus_packages
    install_other_packages
    install_flatpack_and_packages
    clean_system
    generate_iso
}

main
