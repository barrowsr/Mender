#!/bin/bash

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
sudo umount /tmp/rootfs/etc
sudo umount /tmp/rootfs/data
sudo umount /tmp/rootfs
sudo mount -o rw -t ext4 ${LOOPBACK}p2 /tmp/rootfs
mkdir -p /tmp/rootfs/data
sudo mount -o rw -t ext4 ${LOOPBACK}p4 /tmp/rootfs/data
sudo mkdir -p /tmp/rootfs/data/etc-overlay{,-working}

#################################
## Do somthing interesting here

# get mender installer
#curl -fLsS https://get.mender.io -o /tmp/rootfs/home/pi/get-mender.sh
sudo su -c 'echo "overlay /etc overlay defaults,x-systemd.requires-mounts-for=/data,lowerdir=/etc,upperdir=/data/etc-overlay,workdir=/data/etc-overlay-working 0 0" >> /tmp/rootfs/etc/fstab'

# Create docker With this rootfs to do some stuff in.
docker run --cap-add=sys_admin --platform linux/arm/v7 -v /tmp/rootfs:/rootfs --name=MenderRootFs --rm -ti -d arm32v7/debian:buster
docker exec MenderRootFs mount -t overlay overlay -o lowerdir=/rootfs/etc,upperdir=/rootfs/data/etc-overlay,workdir=/rootfs/data/etc-overlay-working /rootfs/etc
#docker exec MenderRootFs chroot /rootfs bash -x /home/pi/get-mender.sh
docker exec MenderRootFs chroot /rootfs systemctl enable ssh
docker stop MenderRootFs


# Mark version
sudo su -c 'echo "Test version built on `date`" > /tmp/rootfs/etc/version'

## Done with interesting things
#################################

# Clean up mount
sudo umount /tmp/rootfs/etc
sudo umount /tmp/rootfs/data
sudo umount /tmp/rootfs

# Extract partition and clone it to the fallpack partition as well.
sudo dd if=${LOOPBACK}p2 of=$IMAGE.p2.ext4 status=progress
sudo dd if=${LOOPBACK}p2 of=${LOOPBACK}p3 status=progress
sudo losetup -d $LOOPBACK

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
   --config configs/raspberrypi4_config \
   -o testartifact.mender



