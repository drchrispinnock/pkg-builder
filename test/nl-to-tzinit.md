# Conversion from NL to tzinit

Run successfully on 23rd July, with these caveats:

*Correcting my earlier summary: the migration is not actually zero-touch. In
  addition to the conffile prompt and manual octez-baker start I already found,
  octez-node.service silently never restarts on apt upgrade — it kept running
  the old NL binary/invocation for 5+ minutes after I'd already (wrongly)
  declared the migration complete, and systemctl status gave no visible hint of
  this since "active (running)" looked identical either way. That's the most
  important finding from this whole test — thanks for catching it. A real
  migration runbook needs an explicit systemctl restart octez-node (and probably
  octez-dal-node/octez-baker too, to not rely on incidental behavior) as a
  required step, not an assumption that apt upgrade handles it.*


1. Set up a GCP server in the chris-claw project with 16GB of RAM and 200GB of hard disc.
 
2. Install the NL packages

```
export distribution=debian
export release=trixie
sudo apt-get install -y gpg curl wget
curl -s "https://packages.nomadic-labs.com/$distribution/octez.asc" | sudo gpg --dearmor -o /etc/apt/keyrings/octez.gpg
echo "deb [signed-by=/etc/apt/keyrings/octez.gpg] https://packages.nomadic-labs.com/$distribution $release main" |   sudo tee /etc/apt/sources.list.d/octez.list
sudo apt-get update
sudo apt-get install -y octez-archive-keyring
sudo sed -i 's|signed-by=/etc/apt/keyrings/octez.gpg|signed-by=/usr/share/keyrings/octez-archive-keyring.gpg|' \
  /etc/apt/sources.list.d/octez.list
sudo apt-get update
sudo apt install -y octez-baker=25.0
```

3. Configure the node

```
sudo su - tezos
octez-node config init --network=https://teztnets.com/currentnet \
  --history=rolling --rpc-addr=127.0.0.1:8732 --net-addr=0.0.0.0:9732
wget https://snapshots.tzinit.org/currentnet/rolling
octez-node snapshot import rolling
exit
```

4. Start the node

```
sudo systemctl enable octez-node
sudo systemctl start octez-node
```

5. Configure the DAL node

```
sudo su - tezos
octez-dal-node config init
exit
```

6. Add 

```
RUNTIME_OPTS="--dal-node http://localhost:10732"
LQ_VOTE="pass"
```

to the bottom of /etc/default/octez-baker.

7. As tezos, generate one key (any key type).

8. Use systemctl to start the DAL and baker packages. There's no need to worry about keys at this point.

9. Make sure that the node, DAL and baker are running.

10. Wait for 5 minutes

11. Remove  /etc/apt/sources.list.d/octez.list

```apt update -y```

12. Add the tzinit repo.

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

13. 
```
apt update -y
apt upgrade
```
