-- Creates a Windows Reset Lab VM: Windows 11 arm64, UEFI, 4 CPUs, 6 GB, 64 GB NVMe disk, three empty USB drives
-- (Windows ISO, answer ISO, provisioning package image), shared network, ramfb display. TPM 2.0 and the images are set
-- afterwards in config.plist, since UTM scripting has no TPM property and ignores `source` for removable drives.
-- Run: osascript vm/create-vm.applescript <name>
on run argv
	set vmName to item 1 of argv
	tell application "UTM"
		set vm to make new virtual machine with properties {backend:qemu, configuration:{name:vmName, architecture:"aarch64", memory:6144, cpu cores:4, hypervisor:true, uefi:true, drives:{{removable:false, interface:NVMe, guest size:65536}, {removable:true, interface:USB}, {removable:true, interface:USB}, {removable:true, interface:USB}}, network interfaces:{{mode:shared, hardware:"virtio-net-pci"}}, displays:{{hardware:"virtio-ramfb"}}}}
		return id of vm
	end tell
end run
