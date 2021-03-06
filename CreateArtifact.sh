#!/bin/bash

WIFI_SSID="$1" # CHANGE: your WiFi name
WIFI_PASS="$2" # CHANGE: your WiFi password

# Get password if needed
sudo echo ""

# Image from https://docs.mender.io/downloads
export IMAGE=2021-01-11-raspios-buster-armhf-lite-raspberrypi4-mender-convert-2.6.0

rm -rf $IMAGE.img $IMAGE.p2.ext4 testartifact.mender
# download and unzip if needed
if [ ! -f $IMAGE.img ]; then
	if [ ! -f $IMAGE.img.xz ]; then
		wget https://d4o6e0uccgv40.cloudfront.net/2021-01-11-raspios-buster-armhf-lite/arm/$IMAGE.img.xz
	fi
	xz --decompress -k $IMAGE.img.xz
fi

# loopback disk image
export LOOPBACK=`sudo losetup --find --show --partscan $IMAGE.img`

# Mount single partition
mkdir -p /tmp/rootfs
sudo umount /tmp/rootfs/data /tmp/rootfs/boot /tmp/rootfs > /dev/null 2>&1
sudo mount -o rw -t ext4 ${LOOPBACK}p2 /tmp/rootfs
sudo mount -o rw -t vfat ${LOOPBACK}p1 /tmp/rootfs/boot
sudo mount -o rw -t ext4 ${LOOPBACK}p4 /tmp/rootfs/data


COUNTRY='US' # CHANGE: two-letter country code, see https://en.wikipedia.org/wiki/ISO_3166-1

cat << EOF > /tmp/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY

network={
         ssid="$WIFI_SSID"
         psk="$WIFI_PASS"
}
EOF
sudo mv /tmp/wpa_supplicant.conf /tmp/rootfs/data/wpa_supplicant.conf 2>&1 | grep -v "failed to preserve ownership"
pushd /tmp/rootfs/etc/wpa_supplicant
sudo rm -rf wpa_supplicant.conf
sudo ln -s /data/wpa_supplicant.conf wpa_supplicant.conf
popd

############################################################################
## Create a armv7 docker With this rootfs to do some stuff in.
##
## THIS DOCKER DOESNT WORK UNLESS YOU DO THE FOLLOWING:
##   sudo add-apt-repository universe
##   sudo apt-get install qemu binfmt-support qemu-user-static docker
##   sudo systemctl start docker
##   sudo systemctl enable docker
##   sudo groupadd docker
##   sudo usermod -aG docker ${USER}
## Must re login for last setting to take effect
##   docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
## After that the output of
##   docker run --rm --platform linux/arm/v7 -t arm32v7/ubuntu uname -m
## Response should be "armv7l"
##
docker stop MenderRootFs > /dev/null 2>&1
docker run --cap-add=sys_admin --platform linux/arm/v7 -v /tmp/rootfs:/rootfs --name=MenderRootFs --rm -ti -d arm32v7/debian:buster
docker exec MenderRootFs chroot /rootfs systemctl enable ssh
# Install Mender deb packages
docker exec MenderRootFs chroot /rootfs bash -c 'wget -q -O- https://get.mender.io | bash -s -- '
docker stop MenderRootFs

## Done with adding things using a armv7 docker
############################################################################

# Clean up mount
sudo umount /tmp/rootfs/data /tmp/rootfs/boot /tmp/rootfs

# Extract partition and clone it to the fallpack partition as well.
sudo dd if=${LOOPBACK}p2 of=$IMAGE.p2.ext4 status=progress
sudo dd if=${LOOPBACK}p2 of=${LOOPBACK}p3 status=progress
sudo losetup -d $LOOPBACK

# Write a version file so you have something to check if the artifact updated properly
sudo mount -o rw -t ext4 $IMAGE.p2.ext4 /tmp/rootfs
sudo su -c 'echo "Test version built on `date`" > /tmp/rootfs/etc/version'
sudo umount /tmp/rootfs

# use "Artifact" executable https://docs.mender.io/downloads
if [ ! -f mender-artifact ]; then
	wget https://downloads.mender.io/mender-artifact/3.6.1/linux/mender-artifact
fi
sudo chmod +x mender-artifact

./mender-artifact write rootfs-image \
   -t raspberrypi4 \
   -n release-1 \
   --software-version rootfs-v1 \
   -f $IMAGE.p2.ext4 \
   -o testartifact.mender



