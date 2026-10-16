#!/usr/bin/env python3 -I
"""Writes the Fedora kickstart (and meta) for an unattended encrypted install, from .env, into a SERVE directory outside the repo.
usage: tests/gen-fedora-ks.py <serve-dir>      Secrets go only into <serve-dir>/ks.cfg (mode 600). Prints nothing secret."""
import os,sys,re,subprocess
lab='/Users/adam/Downloads/fleet-54871-lab/'
env=dict(l.split('=',1) for l in open(lab+'.env').read().splitlines() if '=' in l and not l.startswith('#'))
d=sys.argv[1]; os.makedirs(d,exist_ok=True)
h=env['LAB_USER_PASSWORD']  # plain: macOS openssl/python cannot make a sha512 hash; anaconda hashes it
assert len(h)>=8
pub=open(lab+'secrets/lab_ed25519.pub').read().strip()
ks=f'''# Fedora Server netinst, unattended: LVM on LUKS2, GNOME for Fleet Desktop, fleetd rpm, qemu-guest-agent. Generated, contains secrets, never committed.
text
reboot --eject
lang en_US.UTF-8
keyboard us
timezone UTC
network --bootproto=dhcp --hostname=luks-fedora
rootpw --lock
selinux --permissive
user --name=lab --groups=wheel --plaintext --password={h}
sshkey --username=lab "{pub}"
zerombr
clearpart --all --initlabel
autopart --type=lvm --encrypted --passphrase={env['LUKS_USER_PASSPHRASE']}
bootloader --location=mbr --timeout=5 --append="nomodeset plymouth.enable=0 rd.plymouth=0 console=tty0 console=ttyAMA0,115200"
firstboot --disable
%packages
@^workstation-product-environment
cryptsetup
zenity
qemu-guest-agent
openssh-server
curl
%end
%post --log=/root/ks-post.log
curl -fsS -o /root/fleet-osquery.rpm http://192.168.64.1:18080/fleet-osquery.rpm && dnf -y install /root/fleet-osquery.rpm
systemctl enable qemu-guest-agent sshd
echo 'lab ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/lab && chmod 440 /etc/sudoers.d/lab
mkdir -p /etc/gdm && printf '[daemon]\\nAutomaticLoginEnable=True\\nAutomaticLogin=lab\\n' > /etc/gdm/custom.conf
systemctl set-default graphical.target
%end
'''
p=os.path.join(d,'ks.cfg'); open(p,'w').write(ks); os.chmod(p,0o600); print('ks.cfg written (secrets inside, not shown):',p)
