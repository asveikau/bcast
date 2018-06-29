# bcast.pl

### Copyright (C) 2018 Andrew Sveikauskas

This repo provides a very simple perl script to discover a host via UDP
broadcast.

The scenario it was written for was a heterogeneous set of VMs on a private
network that get their IPs dynamically, and writing quick shell scripts to
perform various tasks on them.

eg. a machine would be configured to run at boot:

    perl bcast.pl -d -n 'name of my service'

And a client machine might run a script:

    ip=`perl bcast.pl -n 'name of my service'`
    scp -r files user@$ip:
    ssh user@$ip files/config_script

The client will send a UDP broadcast every 1s until it receives a response
from the server, and print the server's IP on stdout.
