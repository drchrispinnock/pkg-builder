# Testing a Smart Rollup setup

Hi Terry. I would like you to set up a smart rollup operator that participates on the Test Etherlink Rollup. This is to test some packages from my APT repository. To do this follow these steps:

1. Set up a GCP instance with 32GB RAM, at least 4 cores and 800GB of hard disc
2. Set up the APT repository for the packages as follows:

```
curl -s "https://apt.tzinit.org/keys/tzinit.asc" | sudo gpg --dearor -o /etc/apt/keyrings/tzinit.gpg
echo "deb [signed-by=/etc/apt/keyrings/tzinit.gpg] https://apt.tzinit.org/debian trixie main" | \
  sudo tee -o /etc/apt/sources.list.d/tzinit-octez.list
sudo apt update
```

3. Install octez-node, octez-client and octez-smart-rollup-node

4. Configure the node for shadownet and install a tar of full:50. e.g.

```
sudo su - tezos
mkdir -p /var/tezos/.tezos-node
cd /var/tezos/.tezos-node
wget -O - https://snapshots.tzinit.org/shadownet/full50.tar.lz4 | lz4cat | tar xf -
octez-node config init --network=https://teztnets.com/shadownet --history=full:50 --net-addr=0.0.0.0 --rpc-addr=127.0.0.1
```

5. Start the node with systemctl and sync it.

6. Configure the octez-smart-rollup-node to participate as an observer on the etherlink rollup

```
sudo su - tezos
octez-smart-rollup-node init observer config for sr19fMYrr5C4qqvQqQrDSjtP31GcrWjodzvg \
  with operators --history-mode full --rpc-addr 0.0.0.0 --rpc-port 8932 \
                --pre-images-endpoint "https://snapshots.tzinit.org/etherlink-shadownet/wasm_2_0_0"
```
7. Get a snapshot from https://snapshots.tzinit.org/etherlink-shadownet/eth-shadownet.full
and import it:

```
octez-smart-rollup-node snapshot import eth.shadownet.full
```

7. Start the smart rollup node with systemctl and see what happens!
