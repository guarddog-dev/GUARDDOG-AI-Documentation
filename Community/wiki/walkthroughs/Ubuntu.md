<p align="center">
    <img src="https://guarddog.ai/wp-content/uploads/2024/03/purple-logo.png" alt="gdai_logo" width="300"/>
</p>

<h1 align="center">Ubuntu</h1>

<h2 align="center">Installation, configuration, and deployment of the DCX Edge Sensor</h2>
<h2>Here are the up-to-date instructions to install Docker and the DCX container on <strong>Ubuntu 24.04 LTS (Noble)</strong></h2>

<h3><strong>1. Update Your System:</strong></h3>
<pre><code>
sudo apt update
sudo apt upgrade -y
</code></pre>

<h3><strong>2. Install Docker:</strong></h3>

<h4>1. <strong>Create a Keyring Directory:</strong></h4>
<pre><code>
sudo mkdir -p /etc/apt/keyrings
</code></pre>

<h4>2. <strong>Add Docker’s GPG Key:</strong></h4>
<pre><code>
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null
</code></pre>

<h4>3. <strong>Add Docker Repository:</strong></h4>
<pre><code>
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
</code></pre>

<h4>4. <strong>Install Docker:</strong></h4>
<pre><code>
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y
</code></pre>

<h4>5. <strong>Enable Docker to Start on Boot:</strong></h4>
<pre><code>
sudo systemctl enable docker
</code></pre>

<h3><strong>3. Install and Configure the DCX Container:</strong></h3>

<h4>1. <strong>Pull the DCX Docker Image:</strong></h4>
<pre><code>
docker pull guarddogai/prod:latest
</code></pre>

<h4>2. <strong>Run the DCX Container:</strong></h4>
<p>Replace <code>&lt;DEVICE_NAME&gt;</code>, <code>&lt;USER_EMAIL&gt;</code>, and <code>&lt;LICENSE_KEY&gt;</code> with your actual values:</p>
<pre><code>
docker run -it --cap-add NET_ADMIN --net=host --privileged --restart always -v /etc/guarddog:/etc/guarddog --name gdai guarddogai/prod:latest <DEVICE_NAME> <USER_EMAIL> <LICENSE_KEY>
</code></pre>

<h3><strong>4. Verify and Manage the Container:</strong></h3>

<h4>1. <strong>Check Docker Status:</strong></h4>
<pre><code>
sudo systemctl status docker
</code></pre>

<h4>2. <strong>Check Running Containers:</strong></h4>
<pre><code>
docker ps
</code></pre>

<h4>3. <strong>Stop the Container:</strong></h4>
<pre><code>
docker stop gdai
</code></pre>

<h3><strong>5. Automatic Start on Reboot:</strong></h3>
<p>- The container is set to automatically restart because of the <code>--restart always</code> option included in the run command.</p>
