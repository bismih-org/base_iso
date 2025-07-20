#!/bin/bash

# Set variables
CHROOT_DIR="kaynak"
ISO_WORK_DIR="isowork"
VERSION="69-backports-nvidia"
ISO_OUTPUT="bismih-$VERSION-amd64.iso"

p_system() {
    chroot "${CHROOT_DIR}" "$@"
}

p_system_n_a() {
    chroot "${CHROOT_DIR}" /usr/bin/env DEBIAN_FRONTEND=noninteractive "$@"
}


enter_system(){
    echo "sisteme giriliyor..."
    rm -rf "${ISO_WORK_DIR}" "${ISO_OUTPUT}"
    for i in dev dev/pts proc sys; do
        mount -o bind "/$i" "${CHROOT_DIR}/$i"
    done
}

# set up chroot environment
setup_chroot() {
    rm -rf "${CHROOT_DIR}"
    mkdir "${CHROOT_DIR}"
    chown root "${CHROOT_DIR}"

    echo "İşlem başlıyor haydi Bismillah..."

    sleep 5

    debootstrap --arch=amd64 yirmiuc-deb "${CHROOT_DIR}" http://depo.pardus.org.tr/pardus

    enter_system
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
    p_system dpkg -i /tmp/pardus-archive-keyring_2021.1_all.deb
    chroot kaynak apt update -y
    chroot kaynak apt install curl packagekit xcb ca-certificates -y
}

update_system() {
    echo "sisitem güncelleniyor..."
    p_system apt update -y
    p_system apt upgrade -y
    p_system apt install --fix-missing -y
    p_system apt install --fix-broken -y
}

install_kernel() {
    echo "çekirdek yükleniyor..."
    kernel_stablity=$1
    if [ "$kernel_stablity" == "stable" ]; then
        p_system_n_a apt install linux-image-amd64 linux-headers-amd64 -y
    elif [ "$kernel_stablity" == "backports" ]; then
        p_system_n_a apt install -t yirmiuc-backports linux-image-amd64 linux-headers-amd64 -y
    elif [ "$kernel_stablity" == "rolling" ]; then
        wget --quiet -O - https://liquorix.net/liquorix-keyring.gpg | tee "${CHROOT_DIR}/etc/apt/keyrings/liquorix-keyring.gpg"
        echo "deb [signed-by=/etc/apt/keyrings/liquorix-keyring.gpg arch=$(dpkg --print-architecture)] https://liquorix.net/debian bookworm main" >>"${CHROOT_DIR}/etc/apt/sources.list.d/liquorix.list"
        p_system apt update -y
        p_system apt install linux-image-liquorix-amd64 linux-headers-liquorix-amd64 -y
    else
        echo "Invalid kernel stability! Usage: install_kernel {stable|backports|rolling}"
        return 1
    fi
    
    # initramfs'i güncelle
    p_system update-initramfs -u -k all
    echo "Kernel ve initramfs başarıyla yüklendi"
}

set_system_locale() {
    echo "dil ayarlanıyor..."
    p_system apt install -y locales
    p_system locale-gen en_US.UTF-8
    p_system locale-gen tr_TR.UTF-8
    p_system update-locale LANG=tr_TR.UTF-8
}

install_grub() {
    echo "grub yükleniyor..."
    #bunu dil için bi test yapılabilir
    p_system_n_a apt install grub-pc-bin grub-efi-ia32-bin grub-efi -y
    p_system_n_a apt install live-config live-boot -y
}

install_firmware() {
    echo "firmware yükleniyor..."
    echo "firmware-ipw2x00 firmware-ipw2x00/license/accepted select true" | p_system debconf-set-selections
    echo "firmware-ivtv firmware-ivtv/license/accepted boolean true" | p_system debconf-set-selections

    p_system_n_a apt install bluez-firmware \
        firmware-amd-graphics firmware-atheros firmware-b43-installer firmware-b43legacy-installer \
        firmware-bnx2 firmware-bnx2x firmware-brcm80211 firmware-cavium firmware-intel-sound firmware-ipw2x00 \
        firmware-ivtv firmware-iwlwifi firmware-libertas firmware-linux firmware-linux-free firmware-linux-nonfree \
        firmware-misc-nonfree firmware-myricom firmware-netxen firmware-qlogic firmware-realtek firmware-samsung \
        firmware-siano firmware-ti-connectivity firmware-zd1211 firmware-sof-signed zd1211-firmware -y
    p_system update-initramfs -u
}

install_nvidia_drivers() {
    echo "NVIDIA sürücüleri yükleniyor..."
    
    # NVIDIA deposunu ekleme
    wget -c https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb -O "${CHROOT_DIR}/tmp/cuda-keyring.deb"
    p_system_n_a dpkg -i /tmp/cuda-keyring.deb
    update_system

    # Noveau sürücüsünü kaldırmak için
    p_system_n_a apt purge nvidia-* -y
    p_system_n_a apt purge xserver-xorg-video-nouveau -y

    # NVIDIA sürücülerini yükle
    p_system_n_a apt install nvidia-driver nvidia-settings nvidia-kernel-dkms -y
    
    # CUDA desteği
    # p_system_n_a apt install nvidia-cuda-toolkit -y
    
    # Vulkan desteği
    p_system_n_a apt install nvidia-vulkan-icd vulkan-tools -y
    
    # NVIDIA ayarları için gerekli
    p_system_n_a apt install mesa-utils -y

        cat >> "${CHROOT_DIR}/etc/modprobe.d/blacklist-nvidia.conf" << EOF
# Disable Nouveau driver
blacklist nouveau
options nouveau modeset=0
EOF
    
    # initramfs'i güncelle
    p_system update-initramfs -u -k all
}

install_pipewire(){
    #libspa-0.2-bluetooth blutouth varsa gerekli
    p_system apt purge pulseaudio pulseaudio-module-bluetooth -y
    p_system apt install pipewire wireplumber pipewire-pulse libspa-0.2-bluetooth -y
}

install_desktop_environment() {
    echo "masaüstü ortamı yükleniyor..."
    de=$1
    if [ "$de" == "kde" ]; then
        p_system_n_a apt install libappstreamqt2 appstream packagekit kde-standard -y
        p_system_n_a apt purge dragonplayer juk kmail* konqueror kwrite kde-spectacle zutty -y
        add_close_service
    elif [ "$de" == "gnome" ]; then
        p_system_n_a apt install gnome -y
    elif [ "$de" == "xfce" ]; then
        p_system_n_a apt install xfce -y
    elif [ "$de" == "lxde" ]; then
        p_system_n_a apt install lxde -y
    elif [ "$de" == "lxqt" ]; then
        p_system_n_a apt install lxqt -y
    elif [ "$de" == "mate" ]; then
        p_system_n_a apt install mate -y
    elif [ "$de" == "cinnamon" ]; then
        p_system_n_a apt install cinnamon -y
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
    p_system systemctl enable kill_kwin.service
    p_system systemctl start kill_kwin.service
}

bip_sound_problem() {
    echo "blacklist pcspkr" | tee "$CHROOT_DIR/etc/modprobe.d/nobeep.conf"
}

intall_pardus_packages() {
    echo "pardus paketleri yükleniyor..."
    p_system_n_a apt install pardus-about \
        pardus-backgrounds pardus-boot-repair pardus-font-manager pardus-image-writer pardus-installer pardus-java-installer \
        pardus-locales  pardus-menus pardus-mycomputer pardus-night-light pardus-package-installer pardus-software \
        pardus-update pardus-usb-formatter -y
}

install_other_packages() {
    echo "diğer paketler yükleniyor..."
    p_system_n_a apt install \
        printer-driver-all system-config-printer simple-scan blueman speech-dispatcher libatspi2.0-0 espeak \
        git system-monitoring-center bash-completion birdtray thunderbird thunderbird-l10n-tr \
        touchegg flameshot xsel xdotool unrar webapp-manager appimagelauncher pkg-config zen-browser \
        nala vlc audacious zsh aria2 zoxide onlyoffice-desktopeditors scrcpy lsb-release ark \
        bleachbit htop timeshift python3-pip -y
}

install_libreoffice() {
    echo "libreoffice yükleniyor..."
    p_system_n_a apt install libreoffice libreoffice-kf5 libreoffice-l10n-tr libreoffice-style-yaru -y
}

install_flatpack_and_packages() {
    echo "flatpack ve paketleri yükleniyor..."
    p_system_n_a apt install flatpak plasma-discover-backend-flatpak -y
    p_system flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    p_system flatpak install flathub com.github.wwmm.easyeffects -y
}

config_shell() {
    chsh -s $(which zsh)
    sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' $CHROOT_DIR/etc/default/useradd
    cp .bashrc $CHROOT_DIR/etc/skel/.bashrc
}

add_localpackage() {
    echo "local paket ekleniyor..."

    stt="$CHROOT_DIR/etc/skel/Applications"
    mkdir -p "$stt"
    git clone https://github.com/halak0013/sellected_text_translation.git "$stt/sellected_text_translation"
    rm -rf "$stt/.git"
    wget -c https://github.com/dynobo/normcap/releases/download/v0.5.9/NormCap-0.5.9-x86_64.AppImage -O "$stt/NormCap.AppImage"
}

set_configs(){
    echo "ayarlar yapılıyor..."
    add_localpackage
    # p_system_n_a apt install kde-bismih-config -y
    p_system_n_a pip install PyAutoGUI --break-system
    p_system_n_a apt install bismih-welcome quick-shortcut-panel -y
    p_system_n_a apt install bismih-theme bismih-gun-batimi-grub-theme -y
    config_shell
}

fix_hardware_compatibility() {
    echo "Donanım uyumluluğu iyileştirmeleri yapılıyor..."
    
    local grub_file="${CHROOT_DIR}/etc/default/grub"
    local current_cmdline=$(grep "GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_file" | cut -d '"' -f2)
    
    # NVIDIA için özel parametreler
    local nvidia_params="nvidia-drm.modeset=1 nouveau.modeset=0"
    local acpi_params="acpi=force acpi_osi=Linux"
    local usb_params="usbcore.autosuspend=-1"
    
    local new_cmdline="$current_cmdline $nvidia_params $acpi_params $usb_params"
    
    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"/" "$grub_file"
    
    # Nouveau'yu blacklist'e ekle
    cat >> "${CHROOT_DIR}/etc/modprobe.d/blacklist-nvidia.conf" << EOF
# Nouveau sürücüsünü devre dışı bırak
blacklist nouveau
options nouveau modeset=0
EOF

    echo "Donanım uyumluluğu iyileştirmeleri tamamlandı."
}

fix_bluetooth() {
    echo "Bluetooth askıya alma sorunu düzeltiliyor..."
    
    # GRUB yapılandırma dosyasını düzenle
    if grep -q "usbcore.autosuspend=-1" "${CHROOT_DIR}/etc/default/grub"; then
        echo "USB askıya alma zaten devre dışı bırakılmış."
    else
        # Mevcut GRUB_CMDLINE_LINUX_DEFAULT değerini al
        local grub_cmdline=$(grep "GRUB_CMDLINE_LINUX_DEFAULT=" "${CHROOT_DIR}/etc/default/grub" | cut -d '"' -f2)
        
        # Parametreyi ekle
        local new_grub_cmdline="$grub_cmdline usbcore.autosuspend=-1"
        
        # Dosyayı güncelle
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"$grub_cmdline\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_grub_cmdline\"/" "${CHROOT_DIR}/etc/default/grub"
    fi
    echo "Bluetooth askıya alma sorunu düzeltildi."
}

clean_system() {
    echo "sistem temizleniyor..."
    p_system apt upgrade -y
    p_system apt autoremove -y
    p_system apt clean -y
    rm -rf "${CHROOT_DIR}/tmp/."*
    rm -rf "${CHROOT_DIR}/tmp/*"
    rm -f "${CHROOT_DIR}/root/.bash_history"
    rm -rf "${CHROOT_DIR}/var/lib/apt/lists/*"
    find "${CHROOT_DIR}/var/log/" -type f | xargs rm -f
}

generate_iso() {
    echo "iso oluşturuluyor..."
    clean_system
    
    # Chroot mount'ları temizle
    for i in sys proc dev/pts dev; do
        umount -lf "${CHROOT_DIR}/$i" 2>/dev/null || true
    done

    rm -rf "${ISO_WORK_DIR}"
    rm -f filesystem.squashfs

    # Kernel dosyalarını kontrol et
    echo "Mevcut kernel dosyaları:"
    ls -la "${CHROOT_DIR}/boot/"
    
    # En yeni kernel dosyalarını bul
    NEWEST_VMLINUZ=$(find "${CHROOT_DIR}/boot/" -name "vmlinuz-*" -type f | sort -V | tail -n 1)
    NEWEST_INITRD=$(find "${CHROOT_DIR}/boot/" -name "initrd.img-*" -type f | sort -V | tail -n 1)
    
    echo "Seçilen vmlinuz: $NEWEST_VMLINUZ"
    echo "Seçilen initrd: $NEWEST_INITRD"
    
    if [ ! -f "$NEWEST_VMLINUZ" ] || [ ! -f "$NEWEST_INITRD" ]; then
        echo "HATA: Kernel dosyaları bulunamadı!"
        return 1
    fi

    # Gerekli dizinleri oluştur
    mkdir -p "${ISO_WORK_DIR}/live"
    mkdir -p "${ISO_WORK_DIR}/boot"

    # Squashfs oluştur
    mksquashfs "${CHROOT_DIR}" "${ISO_WORK_DIR}/live/filesystem.squashfs" -comp gzip -wildcards
    # mksquashfs "${CHROOT_DIR}" "${ISO_WORK_DIR}/live/filesystem.squashfs" -comp xz -wildcards

    # Kernel dosyalarını kopyala
    cp -pf "$NEWEST_VMLINUZ" "${ISO_WORK_DIR}/live/vmlinuz"
    cp -pf "$NEWEST_INITRD" "${ISO_WORK_DIR}/live/initrd.img"
    
    echo "Vmlinuz kopyalandı: $(basename $NEWEST_VMLINUZ)"
    echo "Initrd kopyalandı: $(basename $NEWEST_INITRD)"

    # GRUB yapılandırması
    if [ ! -d "grub" ]; then
        git clone https://github.com/bismih-org/grub.git
        rm -rf grub/.git
    fi
    cp -r grub/ "${ISO_WORK_DIR}/boot/"

    # ISO oluştur
    grub-mkrescue --iso-level 3 "${ISO_WORK_DIR}" -o "${ISO_OUTPUT}"
    
    echo "ISO başarıyla oluşturuldu: ${ISO_OUTPUT}"
}

main() {
    setup_chroot
    add_repositories
    update_system
    install_kernel "backports"
    set_system_locale
    install_grub
    install_firmware
    install_nvidia_drivers
    install_pipewire
    install_desktop_environment "kde"
    bip_sound_problem
    intall_pardus_packages
    install_other_packages
    install_flatpack_and_packages
    set_configs
    fix_hardware_compatibility
    fix_bluetooth
    generate_iso
}

custom(){
    enter_system
    install_nvidia_drivers
    fix_hardware_compatibility
    generate_iso
}

# main
custom
# generate_iso
