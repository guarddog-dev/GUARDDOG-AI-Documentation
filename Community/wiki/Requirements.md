<p align="center">
    <img src="https://guarddog.ai/wp-content/uploads/2024/03/purple-logo.png" alt="gdai_logo" width="300"/>
</p>

<h1 align="center">Requirements</h1>



1. **Container Compute Requirements:** Minimum -> 4CPU/4GB/40GB; Recommended -> 4CPU/8GB/64GB.
2. **Architecture** x86/x64
3. **Port Mirroring** This is a key configuration needed to allow the container to have the required visibility to provide the assessments and protection desired. Port mirroring needs to be enabled both ways (ingress **and** egress).
4. **Network configuration** The container needs to be deployed on a network that is configured to allow traffic to and from the container out to the internet.
5. **DHCP:** The container is configured to work with a dynamic IP, please have DHCP enabled and at least one IP available for the container.
6. **Firewall configuration** Refer to the [firewall_rules](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/GDAI%20Configuration%20for%20Firewall%20Rules.pdf) document for the list of ports allowed through the firewall.
7. **Docker** At least Docker version 23.x must be installed on the system where the container is to be deployed.
8. **License** Every container uses a unique, non-transferrable license that is to be requested by contacting us. Follow the process below.
9. **Host network interfaces** The container is prepared to work with the network interfaces presented to the host. Have those configured with IP, Subnet, Gateway, VLAN, and DNS before running the container.
10. **Container runs with host networking access** to be able to be completely functional. It will detect all ethernet interfaces and add them to the internal network configuration within the container.
11. **Container runs in privilege mode** to be able to perform the functions it is designed for.
12. **Container resources** The container is designed to be deployed on a standalone machine as a single deployment. This way the container will utilize all the resources available from the host machine.