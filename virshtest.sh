#!/bin/bash

sudo virt-install \
  --name rpios  \
  --arch armv7l \
  --machine versatilepb \
  --cpu arm1176 \
  --vcpus 4 \
  --memory 2048 \
  --import  \
  --disk 2021-01-11-raspios-buster-armhf-lite-raspberrypi4-mender-convert-2.6.0.img,format=raw,bus=virtio \
  --network bridge,source=virbr0,model=virtio  \
  --video vga  \
  --graphics spice \
  --boot 'dtb=qemu-rpi-kernel/versatile-pb-buster.dtb,kernel=qemu-rpi-kernel/kernel-qemu-4.19.50-buster,kernel_args=root=/dev/vda2 panic=1' \
  --events on_reboot=destroy
