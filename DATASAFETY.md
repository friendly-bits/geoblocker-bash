## **Data safety**
These scripts do not share your data with anyone, as long as you downloaded them from the official source, which is
https://github.com/blunderful-scripts/geoblocker-bash

I purposefully avoided implementing any feature that could even theoretically establish a connection with a 3rd party. The one exclusion is, of course, fetching the ip lists - the scripts can not download them without connecting to a remote server. The 2 sources currently implemented are RIPE and ARIN - both are official regional Internet registries, so I consider them a trusted source. If you don't trust them then you probably should not be using the Internet because I believe that literally every  service and website on the Internet uses their data (either directly or via 3rd parties), since these registries are the bodies that assign ip ranges to Internet providers.

Besides that, the scripts store some data in the config file which can be read by any local user on your machine. I don't think there is any sensitive data in there but you can check by yourself. The path is /etc/geoblocker-bash/geoblocker-bash.conf .

There is also the "data" folder which the -install script creates in /var/lib/geoblocker-bash . It stores: fetched ip lists, a backup of your config file, a file that stores pre-install default policies for the INPUT and FORWARD iptables chains, and a backup file of last-known-good iptables state and geoblocker-related ipsets. That last file is the only thing that is probably somewhat sensitive. The data folder and the files inside it require root permissions to read.

All that said, this is an open-source software that I'm developing for free, and I'm not taking **any** responsibility for your data, or for these scripts behaving or misbehaving in your environment etc etc etc. If you are a security nerd, you are welcome to inspect the code by yourself and modify it to your taste.
