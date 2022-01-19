# Mender
Builds an image you can write to a sdcard and put in an rpi 4
  testartifact.mender
Builds a mender artifacte of the same root filesystem that can be used as an update.
  2021-01-11-raspios-buster-armhf-lite-raspberrypi4-mender-convert-2.6.0.img

## Setting up environment
This build uses a special docker that supports running an arm/v7 emulated environment via qemu
Setting it up in ubuntu is as follows:
Create a armv7 docker With this rootfs to do some stuff in.

THIS DOCKER DOESNT WORK UNLESS YOU DO THE FOLLOWING:
  ```sudo add-apt-repository universe
  sudo apt-get install qemu binfmt-support qemu-user-static docker
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo groupadd docker
  sudo usermod -aG docker ${USER}```
Must re login for last setting to take effect
  `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`
After that the output of
  `docker run --rm --platform linux/arm/v7 -t arm32v7/ubuntu uname -m`
Response should be "armv7l"

## Running the script 
Takes two args 
./CreateArtifact.sh {wifiSSID} {wifiPasswd}




