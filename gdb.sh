#!/bin/bash

qemu-system-x86_64		\
	-s -S			\
	--enable-kvm		\
	-cpu max		\
	-smp 2			\
	-m 128			\
	-cdrom build/aiden.iso	\
	-rtc base=localtime 	\
	-serial file:serial.log &

sleep 1

./r2.sh