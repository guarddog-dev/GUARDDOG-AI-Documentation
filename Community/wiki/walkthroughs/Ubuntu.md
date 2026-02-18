<p align="center">
  <img src="https://guarddog.ai/wp-content/uploads/2024/03/purple-logo.png" alt="gdai_logo" width="300"/>
</p>

<h1 align="center">Ubuntu</h1>

<h2 align="center">Installation, configuration, and deployment of the DCX Edge Sensor</h2>
<h2>Instructions to install Docker and deploy the GuardDog AI Sensor container on <strong>Ubuntu 24.04 LTS (Noble)</strong></h2>

<hr/>

<h3><strong>Prerequisites &amp; deployment assumptions (read this first)</strong></h3>
<ul>
  <li><strong>Network traffic visibility is mandatory:</strong> Port mirroring is preferred (ingress + egress) or SPAN/TAP equivalent must be configured so the sensor can see packets and communicate out on the same network being able to receive and IP on the network that is protecting.</li>
  <li><strong>Firewall/network rules must allow cloud communication:</strong> Ensure required egress/return traffic is permitted <em>before</em> starting the container.</li>
  <li><strong>Host network interfaces must be configured first:</strong> VLANs/logical/physical interfaces should be ready on the host; the container will detect host ethernet interfaces via host networking.</li>
  <li><strong>Persistent configuration:</strong> This deployment mounts <code>/etc/guarddog</code> to persist configuration across reboots and image updates.</li>
  <li><strong>License required:</strong> You need a valid license tied to the email used to create your account.</li>
</ul>

<h3><strong>1. Create your account and obtain licensing</strong></h3>
<ol>
  <li>Create an account at <code>https://dcx.guarddog.ai</code>, verify it, and log in.</li>
  <li>Contact GuardDog AI support/sales with the email you used and request your license parameters.</li>
</ol>

<h3><strong>2. Update the system that will be used to deploy the sensor</strong></h3>
<pre><code>sudo apt update
sudo apt upgrade -y
sudo reboot
</code></pre>

<h3><strong>3. Baseline hardening (optional but recommended)</strong></h3>

<h4>3.1 <strong>SSH keys + disable password authentication</strong></h4>
<p><strong>On your admin machine:</strong></p>
<pre><code>ssh-keygen -t rsa -b 4096
ssh-copy-id &lt;user&gt;@&lt;server_ip&gt;
</code></pre>

<p><strong>On the Ubuntu host:</strong></p>
<pre><code>sudo nano /etc/ssh/sshd_config
</code></pre>

<p>Set (or ensure) these values:</p>
<pre><code>PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
</code></pre>

<pre><code>sudo systemctl restart ssh
</code></pre>

<h4>3.2 <strong>Firewall (UFW example)</strong></h4>
<pre><code>sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status
</code></pre>

<h4>3.3 <strong>Enable IRQ balancing (recommended)</strong></h4>
<pre><code>sudo apt install -y irqbalance
sudo systemctl enable --now irqbalance
</code></pre>

<h3><strong>4. Install Docker Engine (official repository method)</strong></h3>

<h4>4.1 <strong>Remove older/conflicting packages (safe to run)</strong></h4>
<pre><code>sudo apt remove -y docker docker-engine docker.io containerd runc || true
</code></pre>

<h4>4.2 <strong>Install prerequisites</strong></h4>
<pre><code>sudo apt update
sudo apt install -y ca-certificates curl gnupg
</code></pre>

<h4>4.3 <strong>Create a keyring directory</strong></h4>
<pre><code>sudo install -m 0755 -d /etc/apt/keyrings
</code></pre>

<h4>4.4 <strong>Add Docker’s official GPG key</strong></h4>
<pre><code>sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
</code></pre>

<h4>4.5 <strong>Add Docker repository</strong></h4>
<pre><code>echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release &amp;&amp; echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list &gt; /dev/null
</code></pre>

<h4>4.6 <strong>Install Docker Engine</strong></h4>
<pre><code>sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
</code></pre>

<h4>4.7 <strong>Enable Docker to start on boot</strong></h4>
<pre><code>sudo systemctl enable --now docker
</code></pre>

<h4>4.8 <strong>Verify Docker</strong></h4>
<pre><code>docker --version
sudo systemctl status docker --no-pager
</code></pre>

<h4>4.9 <strong>(Optional) Run Docker without sudo</strong></h4>
<pre><code>sudo usermod -aG docker $USER
newgrp docker
</code></pre>

<h3><strong>5. Prepare persistent configuration directory</strong></h3>
<pre><code>sudo mkdir -p /etc/guarddog
sudo chmod 755 /etc/guarddog
</code></pre>

<h3><strong>6. Download and run the DCX container</strong></h3>

<h4>6.1 <strong>Pull the DCX image</strong></h4>
<pre><code>docker pull guarddogai/prod:latest
</code></pre>

<h4>6.2 <strong>Set required variables</strong></h4>
<pre><code>export EMAIL="customer@email.com"
export LICENSE="YOUR-LICENSE-KEY"
export NAME="sensor_name"
</code></pre>

<h4>6.3 <strong>Run the container (use this exact command)</strong></h4>
<p>If you want a different device name, replace <code>gdai01</code> in both <code>--name</code> and <code>--device_name</code>.</p>
<pre><code>docker run  -it --cap-add NET_ADMIN --net=host --restart unless-stopped -v /etc/guarddog:/etc/guarddog --name $NAME guarddogai/prod:latest gdai --device_name=$NAME --email=$EMAIL --license=$LICENSE
</code></pre>

<p><em>Note:</em> If Support/Engineering requests it, add <code>--cap-add NET_RAW</code> to the <code>docker run</code> command.</p>

<h3><strong>7. Verify and manage the container</strong></h3>

<h4>7.1 <strong>Check running containers</strong></h4>
<pre><code>docker ps
</code></pre>

<h4>7.2 <strong>View logs</strong></h4>
<pre><code>docker logs -f gdai01 (use the name of the container)
</code></pre>

<h4>7.3 <strong>Stop / Start / Remove</strong></h4>
<pre><code>docker stop gdai01 (use the name of the container)
docker start gdai01 (use the name of the container)
docker rm -f gdai01 (use the name of the container)
</code></pre>

<h3><strong>8. Automatic start on reboot</strong></h3>
<ul>
  <li>The container will automatically restart after a host reboot or Docker daemon restart because of <code>--restart unless-stopped</code>.</li>
  <li>If you manually stop the container, Docker will not restart it until you start it again.</li>
</ul>

<h3><strong>9. Optional troubleshooting (DNS &amp; interface naming)</strong></h3>

<h4>9.1 <strong>DNS checks (if image pull or cloud registration fails)</strong></h4>
<pre><code>resolvectl status || true
cat /etc/resolv.conf
nslookup dcx.guarddog.ai 8.8.8.8 || true
</code></pre>

<h4>9.2 <strong>Set DNS using systemd-resolved (recommended approach)</strong></h4>
<pre><code>sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/guarddog-dns.conf &gt;/dev/null &lt;&lt;'EOF'
[Resolve]
DNS=8.8.8.8 8.8.4.4
EOF

sudo systemctl restart systemd-resolved
</code></pre>

<p>Optional per-interface DNS (quick testing):</p>
<pre><code>sudo resolvectl dns &lt;iface&gt; 8.8.8.8 8.8.4.4
</code></pre>

<h4>9.3 <strong>(Optional) Disable predictable interface names (only if engineering recommends)</strong></h4>
<pre><code>sudo nano /etc/default/grub
</code></pre>

<p>Add <code>net.ifnames=0 biosdevname=0</code> to <code>GRUB_CMDLINE_LINUX_DEFAULT</code>, for example:</p>
<pre><code>GRUB_CMDLINE_LINUX_DEFAULT="quiet splash net.ifnames=0 biosdevname=0"
</code></pre>

<pre><code>sudo update-grub
sudo reboot
</code></pre>

<h3><strong>10. Upgrade procedure</strong></h3>
<pre><code>docker pull guarddogai/prod:latest
docker stop gdai01
docker rm gdai01
# Re-run the same docker run command from section 6.3
</code></pre>

<h3><strong>11. Security recommendations</strong></h3>
<ul>
  <li>Do not share your license key publicly (GitHub, tickets, screenshots, etc.).</li>
  <li>Keep Ubuntu patched.</li>
  <li>Because <code>--net=host</code> reduces isolation, run on a dedicated host and keep exposure minimal.</li>
</ul>
