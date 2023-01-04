echo "" > serial.log

qemu-system-x86_64 \
	--enable-kvm \
	-cpu max \
	-smp 2 \
	-m 128 \
	-cdrom build/aiden.iso \
	-netdev user,id=ethx \
	-device e1000,netdev=ethx \
	-rtc base=localtime \
	-serial file:serial.log

cat serial.log