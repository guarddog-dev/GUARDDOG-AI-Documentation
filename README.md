# GUARDDOG-AI-Documentation
This is a public repository with the documentation pertaining to the installation, implementation and deployment of our technology. Documents will be reviewed from time to time to maintain accuracy. New versions and brand new documents covering other parts of the technology will be uploaded as they become available.

#Refer to the wiki for more information.
https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/wiki

## Supported Operating Systems:
- RedHat Enterprise Linux 8.8
- RedHat Enterprise Linux 8.9
- RedHat Enterprise Linux 9.2
- RedHat Enterprise Linux 9.3

## Requirements:
1. **System Requirements** Minimum: 4CPU/4GB/40GB; Recommended: 4CPU/8GB/64GB.
2. **Port Mirroring** This is a key configuration that is needed to allow us to have the visibility needed to provide the assessments and protection desired.
3. **Network configuration** The container needs to be deployed on a network that is configured to allow traffic to and from the container out to the internet.
4. **Firewall configuration** Refer to the [firewall_ports](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/Firewall%20Ports-v3.pdf) document for the list of ports allowed through the firewall.
5. **Docker** At least Docker version 23.x must be installed on the system where the container is to be deployed.
6. **License** Every container uses a unique, non-transferrable license that is to be requested by contacting us. Follow the process below.
7. **Host network interfaces** The container is prepared to work with the network interfaces presented to the host. Have those configured with IP, Subnet, Gateway, VLAN, and DNS before running the container.
8. **Container runs with host networking access** to be able to be completely functional. It will detect all ethernet interfaces and add them to the internal network configuration within the container.
9. **Container runs in privilege mode** to be able to perform the functions it is designed for.
10. **Container resources** The container is designed to be deployed on a standalone machine as a single deployment. This way the container will utilize all the resources available from the host machine.

## Index:
1. **Requirements Guide** Refer to the [requirements_doc](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/GuardDog%20Fido%20Installation%20%26%20Configuration%20Requirements.pdf) This document goes over the initial steps on how to use the platform.
2. **Manual.** The [manual](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/Protective%20Cloud%20Services%20v3%20-%20StepbyStep%20-%2020231010.pdf) is a more in-depth document explaining the multiple modules and settings of the dashboard.
3. **Firewall Document** This [firewall_ports](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/Firewall%20Ports-v3.pdf) document shows the communication that needs to be allowed through in the firewall in order for the container to be fully operational.
4. **RHEL Deployment Guide** This [deployment guide](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/GuardDog%20AI%20Container%20Deployment%20Guide%20-%20RHEL%20(1).pdf) shows the simple steps needed to deploy the container on a supported RHEL system.

## Licensing and Deployment Summary:
1. Create an account at https://fido.guarddog.ai
2. Contact us at support@guarddog.ai to request a license.
3. Once the account is verified, validated and payment is completed the license will be generated and we will communicate with you.
4. Use the license as stated in the deployment guide to start the container.
5. Once the container is running, and given all the requirements have been met, please allow for 1h - 2h for the container to fully update. Once done it will automatically start learning and assessing the network to discover digital assets.
6. Once those digital assets are identified then it will automatically proceed to identify vulnerabilities.

