# Signer

(Successfully run 23/7/2026)

1. I want you to use this GPG key and APT repository setup.

Import the GPG key
```
$ curl -s "https://apt.tzinit.org/keys/tzinit.asc" | \
    sudo gpg --dearmor -o /etc/apt/keyrings/tzinit.gpg
```

Set up the Apt repository

```
$ echo "deb [signed-by=/etc/apt/keyrings/tzinit.gpg] https://apt.tzinit.org/debian trixie main" \
     | sudo tee /etc/apt/sources.list.d/tzinit-octez.list
```

2. Use this as a reference https://chrispinnock.com/2026/04/03/quick-start-guide-for-the-impatient-bakers.html but make sure you use the apt repos above.

3. Please set up two servers on my GCP project chris-claw. 

i. The first server called signer should have 8GB RAM, 20GB of hard disc. 

Install octez-signer please from the APT repos. Setup HWM protection. 
Also only allow attestations, preattestations and baking. Allow connections from other servers and set it to run on boot. 

Generate two BLS keys on the server called consenus and companion. I will need the tz hashes, the public keys and the BLS proof of possession proofs.

ii. The second server called baker should have 16GB RAM, 200GB of hard disc. Follow the installation guide at https://chrispinnock.com/2026/04/03/quick-start-guide-for-the-impatient-bakers.html but don't create the keys and please make sure you use the right APT repos.  Run it on currentnet please. 

4. When the time is right, ask me for the baking key address. You can setup the DAL attester and import the consensus and companion keys from the signer. Set up the node, baker and DAL node to run on boot. 

5. Harden the servers so that only SSH connections are accepted from my IP address (ask me if you don't have it). Harden the signer so that signer connections are only accepted from the baker server.
