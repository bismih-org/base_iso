#!/bin/bash

### gerekli paketler
apt install debootstrap xorriso squashfs-tools mtools grub-pc-bin grub-efi-amd64 -y


### Chroot oluşturmak için
mkdir kaynak
chown root kaynak


### Ana hiyerarşi oluşturmak için
debootstrap --arch=amd64 yirmiuc-deb kaynak http://depo.pardus.org.tr/pardus


### bind bağı için
for i in dev dev/pts proc sys; do mount -o bind /$i kaynak/$i; done


sleep 5

echo 'depo ekleniyor...'



### Depo eklemek için
echo 'deb http://depo.pardus.org.tr/pardus yirmiuc-deb main contrib non-free non-free-firmware' > kaynak/etc/apt/sources.list
echo 'deb-src http://depo.pardus.org.tr/pardus yirmiuc-deb main contrib non-free non-free-firmware' >> kaynak/etc/apt/sources.list
echo 'deb http://depo.pardus.org.tr/guvenlik yirmiuc-deb main contrib non-free non-free-firmware' >> kaynak/etc/apt/sources.list
echo 'deb-src http://depo.pardus.org.tr/guvenlik yirmiuc-deb main contrib non-free non-free-firmware' >> kaynak/etc/apt/sources.list
echo 'deb http://depo.pardus.org.tr/pardus yirmiuc main contrib non-free non-free-firmware' >> kaynak/etc/apt/sources.list
echo 'deb-src http://depo.pardus.org.tr/pardus yirmiuc main contrib non-free non-free-firmware' >> kaynak/etc/apt/sources.list

echo "deb http://depo.pardus.org.tr/backports yirmiuc-backports main contrib non-free non-free-firmware" >> kaynak/etc/apt/sources.list.d/yirmiuc-backports.list

echo "deb [signed-by=/etc/apt/keyrings/bismih-pubkey.asc arch=$( dpkg --print-architecture )] https://bismih-org.github.io/repository/repo fethan main" >> kaynak/etc/apt/sources.list.d/bismih.list

### Anahtar eklemek için
wget --quiet -O - https://bismih-org.github.io/repository/repo/bismih-pubkey.asc | tee kaynak/etc/apt/keyrings/bismih-pubkey.asc
wget -c https://depo.pardus.org.tr/pardus/pool/main/p/pardus-archive-keyring/pardus-archive-keyring_2021.1_all.deb -O kaynak/tmp/pardus-archive-keyring_2021.1_all.deb

### Anahtar yükleme
chroot kaynak dpkg -i /tmp/pardus-archive-keyring_2021.1_all.deb

### ssl olarak githubdaki depo ile bağlantı kurmak için
chroot kaynak apt install ca-certificate -y

chroot kaynak apt install --fix-missing -y
chroot kaynak apt install --fix-broken -y

chroot kaynak apt update -y
chroot kaynak apt upgrade -y

chroot kaynak apt install -t yirmiuc-backports linux-image-amd64 -y

### grub paketleri için
chroot kaynak apt install grub-pc-bin grub-efi-ia32-bin grub-efi -y

### live paketleri için -> dili otomatik seçtir
chroot kaynak apt install live-config live-boot -y 

### firmware paketleri -> driverlede gen sorulara otomatik kabul ettir
chroot kaynak apt install bluez-firmware firmware-amd-graphics firmware-atheros firmware-b43-installer firmware-b43legacy-installer firmware-bnx2 firmware-bnx2x firmware-brcm80211 firmware-cavium firmware-intel-sound  firmware-ipw2x00 firmware-ivtv firmware-iwlwifi firmware-libertas firmware-linux firmware-linux-free firmware-linux-nonfree firmware-misc-nonfree firmware-myricom firmware-netxen firmware-qlogic  firmware-realtek firmware-samsung firmware-siano firmware-ti-connectivity firmware-zd1211 firmware-sof-signed zd1211-firmware -y

# sudo DEBIAN_FRONTEND=noninteractive apt install -y firmware-intel-sound dene

### kde paketleri
chroot kaynak apt install kde-standard -y


###geç kapanma sorunu düzeltme servisi
echo '#!/bin/sh' > kaynak/usr/lib/systemd/system-shutdown/kill_kwin.shutdown
echo '# Kill KWin immediately to prevent stalled shutdowns/reboots' >> kaynak/usr/lib/systemd/system-shutdown/kill_kwin.shutdown
echo 'pkill -KILL kwin_x11' >> kaynak/usr/lib/systemd/system-shutdown/kill_kwin.shutdown
chmod +x kaynak/usr/lib/systemd/system-shutdown/kill_kwin.shutdown

echo '[Unit]' > kaynak/etc/systemd/system/kill_kwin.service
echo 'Description=Kill KWin at shutdown/reboot' >> kaynak/etc/systemd/system/kill_kwin.service
echo '' >> kaynak/etc/systemd/system/kill_kwin.service
echo '[Service]' >> kaynak/etc/systemd/system/kill_kwin.service
echo 'Type=oneshot' >> kaynak/etc/systemd/system/kill_kwin.service
echo 'ExecStart=/bin/true' >> kaynak/etc/systemd/system/kill_kwin.service
echo 'ExecStop=/bin/sh /usr/lib/systemd/system-shutdown/kill_kwin.shutdown' >> kaynak/etc/systemd/system/kill_kwin.service
echo 'RemainAfterExit=true' >> kaynak/etc/systemd/system/kill_kwin.service
echo '' >> kaynak/etc/systemd/system/kill_kwin.service
echo '[Install]' >> kaynak/etc/systemd/system/kill_kwin.service
echo 'WantedBy=multi-user.target' >> kaynak/etc/systemd/system/kill_kwin.service

chmod +x kaynak/etc/systemd/system/kill_kwin.service
chroot kaynak systemctl enable kill_kwin.service
chroot kaynak systemctl start kill_kwin.service


chroot kaynak apt purge juk kmail* konqueror kwrite kde-spectacle zutty

### Yazıcı tarayıcı ve bluetooth paketlerini kuralım (isteğe bağlı)
chroot kaynak apt install printer-driver-all system-config-printer simple-scan blueman -y


### Pardus paketlerini kurma
chroot kaynak apt install pardus-about pardus-ayyildiz-grub-theme pardus-backgrounds pardus-font-manager pardus-image-writer pardus-installer pardus-java-installer pardus-locales pardus-menus pardus-mycomputer pardus-night-light pardus-package-installer pardus-software pardus-update pardus-usb-formatter pardus-wallpaper-23-0 git system-monitoring-center -y


chroot kaynak apt install bash-completion libreoffice libreoffice-kf5 libreoffice-l10n-tr libreoffice-style-yaru birdtray thunderbird thunderbird-l10n-tr zen-browser touchegg flameshot elisa xsel xdotool unrar webapp-manager appimagelauncher pkg-config -y

### config ayarları




### temizlik işlemleri
chroot kaynak apt upgrade -y

chroot kaynak apt autoremove -y
chroot kaynak apt clean -y
rm -rf kaynak/tmp/.*
rm -rf kaynak/tmp/*
rm -f kaynak/root/.bash_history
rm -rf kaynak/var/lib/apt/lists/*
find kaynak/var/log/ -type f | xargs rm -f


### bind bağını kaldırmak için
umount -lf -R kaynak/* 2>/dev/null


### isowork filesystem.squashfs oluşturmak için
mkdir isowork
mksquashfs kaynak filesystem.squashfs -comp gzip -wildcards
#mksquashfs kaynak filesystem.squashfs -comp xz -wildcards # daha iyi sıkıştırma için

mkdir -p isowork/live
mv filesystem.squashfs isowork/live/filesystem.squashfs

cp -pf kaynak/boot/initrd.img* isowork/live/initrd.img
cp -pf kaynak/boot/vmlinuz* isowork/live/vmlinuz

### grub işlemleri 
mkdir -p isowork/boot
cp -r grub/ isowork/boot/


grub-mkrescue isowork -o bismih-amd64.iso