set diskFile to POSIX file "~/Downloads/fleet-54654-lab/vm/linux/disk.qcow2"
tell application "UTM"
	set vm to make new virtual machine with properties {backend:qemu, configuration:{name:"lab-linux", architecture:"aarch64", memory:4096, cpu cores:4, hypervisor:true, uefi:true, drives:{{removable:false, interface:VirtIO, source:diskFile}}, network interfaces:{{mode:shared}}, displays:{{hardware:"virtio-gpu-pci"}}, qemu additional arguments:{{argument string:"-smbios"}, {argument string:"type=1,serial=ds=nocloud-net;s=http://192.168.64.1:8000/"}}}}
	return id of vm
end tell
