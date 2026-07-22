# Rocky Linux 9

0. Set up a Rocky Linux 9 instance

1. Prepare the DNF installation

```
sudo dnf install -y 'dnf-command(config-manager)'
sudo dnf config-manager --set-enabled crb
sudo dnf config-manager --set-enabled devel
sudo dnf update -y
```        

2. Install the client

```
sudo dnf install -y https://packages.tzinit.org/release/rocky-linux-9/octez-client-25.1-1.x86_64.rpm
```

3. Install the node

```
sudo dnf install -y https://packages.tzinit.org/release/rocky-linux-9/octez-zcash-params-1.0.0-2.x86_64.rpm
sudo dnf install -y https://packages.tzinit.org/release/rocky-linux-9/octez-node-25.1-1.x86_64.rpm
```

4. Configure the node

As tezos:

```
octez-node config init --network=https://teztnets.com/currentnet --history=rolling --rpc-addr=127.0.0.1 --node-addr=0.0.0.0
wget https://snapshots.tzinit.org/currentnet/rolling
octez-node snapshot import rolling 
rm -f rolling
```

5. Use systemctl to enable and run the node

6. Generate keys

As tezos:

```
octez-client gen keys baker --sig bls
octez-client gen keys companion --sig bls
```

Send me the baker key and I will fund it.

7. Self delegate as tezos:

```
octez-client register key baker as delegate
octez-client set companion key for baker to companion
octez-client stake 6000 for baker
```

8. Install the dal-node and baker


```
sudo dnf install -y https://packages.tzinit.org/release/rocky-linux-9/octez-dal-node-25.1-1.x86_64.rpm
sudo dnf install -y https://packages.tzinit.org/release/rocky-linux-9/octez-baker-25.1-1.x86_64.rpm
```

9. Configure the DAL node using the baker address BAKER_ADDR

As tezos:

```
octez-dal-node config init --attester=BAKER_ADDR
```

Use systemctl to enable and start the DAL node

10. Modify the baker defaults to use pass for liquidity baking and to use the dal node in DAL OPTIONS.

11. Use systemctl to enable and start the baker.
