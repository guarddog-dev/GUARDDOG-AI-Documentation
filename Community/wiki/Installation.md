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

6. To keep it short, you need 2 commands:
   1. >```docker pull guarddogai/prod:latest```
   2. >```docker run -it --cap-add NET_ADMIN --net=host --privileged --restart always -v /etc/guarddog:/etc/guarddog --name gdai guarddogai/prod:latest <DEVICE_NAME> <USER_EMAIL> <LICENSE_KEY>```
      1. <DEVICE_NAME>, indicates a friendly name for the container. 
      2. <USER_EMAIL>, this is the email address used to create the account at https://dcx.guarddog.ai.
      3. <LICENSE_KEY>, this is the license key that will be provided by GUARDDOG AI for each container to be deployed. 

7. Once the container is running, and given all the requirements have been met, please allow for 1h - 2h for the container to fully update. 

8. Once done it will automatically start learning and assessing the network to discover digital assets.

9. Once those digital assets are identified then it will automatically proceed to identify vulnerabilities.