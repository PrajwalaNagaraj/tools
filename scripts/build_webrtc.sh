#!/bin/bash
#Ensure git works in the setup
#steps to install webrtc M84[4147] version for debug/release build_type on ubuntu/raspberry-pi target os


#basic parameter checks on script
helpFunction()
{
	echo ""
	echo "Usage: $0 -b build_type -t target_os"
	echo -e "\t-b build_type can be $build_type or debug"
	echo -e "\t-t target_os can be ubuntu or raspberry-pi"
	exit 1 # Exit script after printing help
}

while getopts b:t: opt
do
	case "$opt" in
		b ) build_type="$OPTARG" ;;
		t ) target_os="$OPTARG" ;;
		? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
	esac
done

# Print helpFunction in case parameters are empty
if [ -z "$build_type" ] || [ -z "$target_os" ]
then
	echo "Some or all of the parameters are empty";
	helpFunction
fi
if [ "$build_type" != "debug" ] && [ "$build_type" != "$build_type" ]; then
	echo "Wrong build_type spelling"
	helpFunction
elif [ "$target_os" != "ubuntu" ] && [ "$target_os" != "raspberry-pi" ]; then
	echo "Wrong OS type spelling"
	helpFunction
fi
#for gn cmd
debug_flag=false
if [ "$build_type" == "debug" ]; then
	$debug_flag = true;
fi

#clang installation
sudo apt install clang
sudo apt-get install libc++-dev

mkdir -p ~/workspace/webrtc-checkout && cd ~/workspace/webrtc-checkout
#install Toolchain according to OS
if [ "$target_os" == "ubuntu" ]; then
	sudo apt-get update && sudo apt-get -y install git python
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
	export PATH=`pwd`/depot_tools:"$PATH"
else
	sudo apt update && sudo apt install -y debootstrap qemu-user-static git python3-dev
	sudo git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /opt/depot_tools
	echo "export PATH=/opt/depot_tools:\$PATH" | sudo tee /etc/profile.d/depot_tools.sh
	sudo git clone https://github.com/raspberrypi/tools.git /opt/rpi_tools
	echo "export PATH=/opt/rpi_tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin:\$PATH" | sudo tee /etc/profile.d/rpi_tools.sh
	sudo chown -R `whoami`:`whoami` /opt/depot_tools /opt/rpi_tools
	source /etc/profile
	sudo debootstrap --arch armhf --foreign --include=g++,libasound2-dev,libpulse-dev,libudev-dev,libexpat1-dev,libnss3-dev,libgtk2.0-dev jessie rootfs
	sudo cp /usr/bin/qemu-arm-static rootfs/usr/bin/
	sudo chroot rootfs /debootstrap/debootstrap --second-stage
	find rootfs/usr/lib/arm-linux-gnueabihf -lname '/*' -printf '%p %l\n' | while read link target; do sudo ln -snfv "../../..${target}" "${link}"; done
	find rootfs/usr/lib/arm-linux-gnueabihf/pkgconfig -printf "%f\n" | while read target; do sudo ln -snfv "../../lib/arm-linux-gnueabihf/pkgconfig/${target}" rootfs/usr/share/pkgconfig/${target}; done
fi

#build webrtc
errormsg=$( fetch --nohooks webrtc 2>&1)
if [[ "$errormsg" == *"error"* ]]; then
	echo $errormsg
	exit 1;
fi
cd src
git checkout branch-heads/4147
errormsg=$( gclient sync 2>&1)
if [[ "$errormsg" == *"error"* ]]; then
	echo $errormsg
	exit 1;
fi
if [ "$target_os" == "ubuntu" ]; then
	sudo apt-get install gtk2.0
else
	./build/install-build-deps.sh
	./build/linux/sysroot_scripts/install-sysroot.py --arch=arm
fi

if [ "$target_os" == "ubuntu" ]; then
	gn gen out/$build_type "--args=enable_iterator_debugging=false is_component_build=false is_debug=$debug_flag"
else
	gn gen out/$build_type "--args='target_os=\"linux\" target_cpu=\"arm\" is_debug=$debug_flag enable_iterator_debugging=false is_component_build=false is_debug=true rtc_build_wolfssl=true rtc_build_ssl=false rtc_ssl_root=\"/usr/local/include\"\'"
fi

#ninja cmd to compile the required webrtc libraries
webrtc_libs = boringssl boringssl_asm protobuf_lite rtc_p2p rtc_base_approved rtc_base jsoncpp rtc_event logging pc api rtc_pc_base call
errormsg=$( ninja -C out/$build_type/ $webrtc_libs 2>&1)
if [[ "$errormsg" == *"error"* ]] || [[ "$errormsg" == *"fatal"* ]]; then
	echo $errormsg
	exit 1;
fi
