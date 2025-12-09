<!-- <div style="background-color: #3C434B; padding: 20px;"> -->

<p align="center">
    <img src="https://guarddog.ai/wp-content/uploads/2024/03/purple-logo.png" alt="gdai_logo" width="300"/>
</p>


<h1 align="center">GUARDDOG AI Documentation</h1>

<div align="center">

[Website](https://guarddog.ai) •
[Web Application](https://dcx.guarddog.ai) •
[Community](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/wiki) •
[User Manual](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/Manual/DCX_Manual.md) •
[Supported OS](#supported-operating-systems) •
[Requirements](#requirements) •
[Index](#index) •
[Request a license](#requesting-a-license-and-deployment-summary) •
[Deployment](#requesting-a-license-and-deployment-summary)

</div>

This is a public repository with the documentation pertaining to the installation, implementation and deployment of our technology. Documents will be reviewed from time to time to maintain accuracy. New versions and brand new documents covering other parts of the technology will be uploaded as they become available.

Refer to the wiki [here](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/wiki) for Community Support and for more information.


## **Supported Operating Systems**
- RedHat Enterprise Linux 9.x

## **Requirements**
1. **Container Compute Requirements:** Minimum -> 4CPU/4GB/40GB; Recommended -> 4CPU/8GB/64GB.
2. **Architecture** x86/x64
3. **Port Mirroring** This is a key configuration needed to allow the container to have the required visibility to provide the assessments and protection desired. Port mirroring needs to be enabled both ways (ingress **and** egress).
4. **Network configuration** The container needs to be deployed on a network that is configured to allow traffic to and from the container, and out to the internet.
5. **DHCP:** The container is configured to work with a dynamic IP, please have DHCP enabled and at least one IP available for the container.
6. **Firewall configuration** Refer to the [firewall_rules](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/GDAI%20Configuration%20for%20Firewall%20Rules.pdf) document for the list of ports allowed through the firewall.
7. **Podman** Podman replaces docker and the installation as it was previously.
8. **License** Every container uses a unique, non-transferrable license that is to be requested by contacting us. Follow the process below.
9. **Host network interfaces** The container is prepared to work with the network interfaces presented to the host. Have those configured with IP, Subnet, Gateway, VLAN, and DNS before running the container.
10. **Container runs with host networking access** to be able to be completely functional. It will detect all ethernet interfaces and add them to the internal network configuration within the container.
11. **Container resources** The container is designed to be deployed on a standalone machine (physical or virtual) as a single deployment. This way the container will utilize all the resources available from the host machine.

## **Index**
1. **Requirements Guide** Refer to the [requirements_doc](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/GDAI%20Container%20Installation%20and%20Configuration%20Requirements.pdf) This document goes over the initial steps on how to use the platform.
2. **Manual.** The [manual](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/Manual/DCX_Manual.md) is a more in-depth document explaining the multiple modules and settings of the dashboard.
3. **Firewall Document** This [firewall_rules](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/GDAI%20Configuration%20for%20Firewall%20Rules.pdf) document shows the communication that needs to be allowed through in the firewall in order for the container to be fully operational.
4. **RHEL Deployment Guide** This latest [deployment guide](https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/GuardDog%20AI%20Container%20Deployment%20Guide%20-%20RHEL%20version.pdf) which shows the simple steps needed to deploy the container on a supported RHEL system.

## **Requesting a License and Deployment Summary**
1. Create an account at https://dcx.guarddog.ai

2. Contact us at support@guarddog.ai to request a license with the following information:
    - Subject: Container License Request for [enter the email address the request is for]    
    - Customer company name:  
    - Main customer name: 
    - Number of customer email accounts: 
    - Have accounts been created at https://dcx.guarddog.ai ?: 
    - Sales approval needed:
    - Billing/Payment verified: 
    - Customer email used for account: 
    - Number of licenses required: 
    - Duration for each license: 
    - Type of license: 

3. Once the account is verified, validated and payment is completed the license will be generated and we will communicate with you.

4. The license will show up on the dashboard at https://dcx.guarddog.ai 
   1. when logged in go to Settings > Preferences > Licensing
   2. click on the license to reveal the license key

5. Use the license as stated in the deployment guide to start the container, refer to the documentation for more information.

6. Once the license has been received, you can now proceed to deploy the container using 2 methods. You can either follow the steps on the deployment guide pdf file, or run through the steps below
   1. Run this one-liner to get the local install script:
   2. ```bash <(curl -fsSL https://github.com/guarddog-dev/GUARDDOG-AI-Documentation/blob/main/Deployment%20scripts/gdai_install.sh)```
   3. then run it as sudo
   4. once the latest version of the gdai_deploy script has been downloaded it will prompt for several paramaters. These are the required ones, everything else is optional
      1. <DEVICE_NAME>, indicates a friendly name for the container. 
      2. <EMAIL>, this is the email address used to create the account at https://dcx.guarddog.ai.
      3. <LICENSE>, this is the license key that will be provided by GUARDDOG AI for each container to be deployed. 

7. Once the container is running, and given all the requirements have been met, please allow for 1h - 2h for the container to fully update. 

8. The sensor will automatically and quickly start detecting and protecting. Depending on the license acquired it may perform different actions.

9. Enjoy and stay safe.

</div>