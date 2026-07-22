# Signer


Please set up two servers on my GCP project chris-claw. 

The first server called signer should have 8GB RAM, 20GB of hard disc. 

Install octez-signer please. Setup HWM protection. Also only allow attestations, preattestations and baking. Allow connections from other servers and set it to run on boot. 

Generate two BLS keys on the server called consenus and companion. I will need the tz hashes, the public keys and the BLS proof of possession proofs.

The second server called baker should have 16GB RAM, 200GB of hard disc. Follow the installation guide at https://chrispinnock.com/2026/04/03/quick-start-guide-for-the-impatient-bakers.html but don't create the keys.  Run it on bakingnet please. 

When the time is right, ask me for the baking key address. You can setup the DAL attester and import the consensus and companion keys from the signer. Set up the node, baker and DAL node to run on boot.

Harden the servers so that only SSH connections are accepted from my IP address (ask me if you don't have it). Harden the signer so that signer connections are only accepted from the baker server. 

Once you have finished, please output a MD file describing the activity.


octez-client gen keys hermes_baker_1
TF01017: {1004} octez-client show address hermes_baker_1
Hash: tz1S4buAWUp2ZyeqNMasC7yy3eTJbYRujcfg
Public Key: edpkuPbGtC5ekaP5bJY3ht4azqtZePNVt9ncLs3CRHuDuMEySBD9My
- Faucet

octez-client -E https://rpc.bakingnet.teztnets.com register key hermes_baker_1 as delegate
octez-client -E https://rpc.bakingnet.teztnets.com stake 6000 for hermes_baker_1
octez-client -E https://rpc.bakingnet.teztnets.com set companion key for hermes_baker_1 to unencrypted:BLpk1pgDEuimiGiCyqf57unEWxBwYTnTJF78NUNKsxntgw4XzLx4Y7TYUjLLQJLWHFe2Z3MoJEyT --companion-key-pop BLsigBL2mBtgbeyj5RnzHT34ea6bspzTmyi1L7JG2A2jMe4dCVJ9xdyRCLTD14vHeijfDgmNinTEur7Aj6wAm6bVKUirJFUYvaKnnvSUXKRRXXqHqyzeQeKntd13hFrjCQtkycmoCjiZsU
octez-client -E https://rpc.bakingnet.teztnets.com set consensus key for hermes_baker_1 to unencrypted:BLpk1udyWySJEBw7LKeBLiBJL97AbYozdEaAkxfWjz6oG6gE4dRRQ2D4boKbJkcokg3UoYSU4W1e --consensus-key-pop BLsigBPe275v6eY7Q5BTHKFcpkwwF6cjSUYke62b8nzQzwWEzDVezY7oEu4QYi2E14s1kscQ11bLafKi6Mwp8vqYw2sUKX11oDGmJS8dN6YVyg4WbVweKok8K4KW5bnKBTRpcPKVhvEcP9
