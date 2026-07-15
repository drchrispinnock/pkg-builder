# VDF server

1. Please set up a GCP instance with 16GB of RAM and 200GB of hard disc.

2. Set up the APT repos

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

3. Install octez-node and octez-baker.

4. As tezos user, Configure the node for local RPC, to be on shadownet with history mode rolling

5. As tezos user, download a snapshot from https://snapshots.tzinit.org/shadownet/rolling and import it.

6. Run and sync the node using systemctl

7. Enable and run the VDF service.
