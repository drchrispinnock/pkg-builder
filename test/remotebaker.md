
1. Please use these instructions as a base:

https://chrispinnock.com/tezos/packages/

2. Set up two instances please. The first is a Tezos node. Set it up on bakingnet in rolling mode using the packages. Open the RPC port up - you can allow all RPC for this. Get the node synced please (using a snapshot).

3. The second should be a baker. Once setup, create a key and let me know what it is so I can fund it. 

You don't have to worry about DAL or companion keys. Set the endpoint in /etc/defaults/octez-baker to the first instance (http://IPADDRESS:8732).

4. Use the octez-baker-remote systenctl to start a remote baker. We need to see if remote baking works.



