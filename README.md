
# Bulk Octez Package Builder

This work is based on my builder of 2023. The package build scripts were handed over to Nomadic Labs in 2023, but I forked them out again sometime ago. As Nomadic Labs are going to stop offering packages, I've decided to start offering packages again.

To use them on Debian and Ubuntu, you need to import the GPG key.

```
curl -s "https://apt.tzinit.org/keys/tzinit.asc" | \
    sudo gpg --dearmor -o /etc/apt/keyrings/tzinit.gpg
```

Then set up the APT repository. For Debian 13(trixie) use:

```
echo "deb [signed-by=/etc/apt/keyrings/tzinit.gpg] https://apt.tzinit.org/debian trixie main" \
    | sudo tee /etc/apt/sources.list.d/tzinit-octez.list
```

For Ubuntu 24.04 (noble) use:

```
echo "deb [signed-by=/etc/apt/keyrings/tzinit.gpg] https://apt.tzinit.org/ubuntu noble main" \
    | sudo tee /etc/apt/sources.list.d/tzinit-octez.list
```

## build_pkg

This script sets up GCP instances for the desired platforms, copys helpers/_buildscript.sh to each on and executes it. The resulting packages are synced to an "incoming" directory.

```
build_pkg.sh [--branch GitBranch]
             [--srn-branch Branch for Smart Rollup Node]                                     
             [--evm-branch Branch for EVM Node]                                              
             [--targets "debian-13 debian-13-arm64 ...\"]                                                     
             [--revision package revision]                                                   
             [--project GCP project]                                                         
             [--service-account GCP service account]                                         
             [--bucket GCP storage bucket]                                                   
             [--(no)-sync] whether to sync the packages to the bucket                        
             [--sleep seconds] interval between polls                                        
             [--devmode] push a developer variable through the process"
```

```build_pkg.sh --branch latest-release``` will build the latest Octez, but also the dedicated releases for EVM node and the Smart Rollup node.

## helpers/aptrepo.sh

This script sets up an APT repository, populates it with packages and signs them.

## helpers/mksite.sh

This script makes a web site for manual download and to access the RPM packages.
