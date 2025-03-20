devbox is required!



apt install qemu-guest-agent
systemctl start qemu-guest-agent.service
systemctl enable qemu-guest-agent.service

```
pveum user add ansible@pve
pveum aclmod / -user ansible@pve -role PVEAdmin
pveum aclmod / -user ansible@pve -role Administrator
pveum user token add ansible@pve ansible-token

```

ssh root@192.168.0.2

add hosts


---


TODO

create keys to access k3s nodes
