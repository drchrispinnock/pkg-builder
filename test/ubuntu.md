# Ubuntu packages - basic test suite for hermes/claw

(Successfully run on 16/7/2026)

Hi Terry. I would like you to test a set of Octez packages for me. I would also like you to start afresh and do this from a fresh perspective, i.e. avoid any implicit knowledge that might skew the testing.

Please set up a VM on GCP with 16GB RAM and 200GB of disc. Please follow the instructions at
https://chrispinnock.com/2026/04/03/quick-start-guide-for-the-impatient-bakers.html with the following changes:

1. Use Ubuntu 24.04

2. I want you to use this GPG key and APT repository setup.

Import the GPG key
```
$ curl -s "https://apt.tzinit.org/keys/tzinit.asc" | \
    sudo gpg --dearmor -o /etc/apt/keyrings/tzinit.gpg
```

Set up the Apt repository

```
$ echo "deb [signed-by=/etc/apt/keyrings/tzinit.gpg] https://apt.tzinit.org/ubuntu noble main" \
     | sudo tee /etc/apt/sources.list.d/tzinit-octez.list
```

3. Please use currentnet (and not shadownet or bakingnet). 

4. When you generate a key, please let me know the address and I will fund it from the faucet.

5. At the end I want a working node, dal node and baking node on currentnet on one machine.
