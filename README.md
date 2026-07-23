This repo is a staging area to house tooling to build custom kernel modules and tools.

Some examples we've already run into are:
* wireguard (using userspace wireguard-go)
* a few nf firewall modules k3s needs
* usbip

Since all of the modules are _kernel version specific_, I have currently pinned the Thor BSP and kernel packages to:

```
BSP packages version: 38.2.2-20250925153837
Kernel packages version: 6.8.12-tegra-38.2.2-20250925153837
```

Right now, it's only building the usbip modules and tools but the plan is to build a workflow where we clone the kernel source and build the modules _once_ and then package specific self-contained subsets of those modules into their own .deb packages. (Ex. wireguard-tegra, usbip-tegra, etc)
