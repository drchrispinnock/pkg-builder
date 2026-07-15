# Basic test suite for hermes/claw

Hi Terry. I would like you to test this set of packages for me. Please set up a VM on GCP with 16GB RAM and 200GB of disc. Please follow the instructions at
https://chrispinnock.com/2026/04/03/quick-start-guide-for-the-impatient-bakers.html more or less with the following changes:

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

2. Please use currentnet (and not shadownet or bakingnet). 

3. When you generate a key, please let me know the address and I will fund it from the faucet.

4. At the end I want a working node, dal node and baking node on currentnet on one machine.
