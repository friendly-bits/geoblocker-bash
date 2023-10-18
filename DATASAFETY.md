## **Data safety**
These scripts do not share your data with anyone, as long as you downloaded them from the official source, which is
https://github.com/blunderful-scripts/geoblocker-bash

I purposefully avoided implementing any feature that could establish a connection with a 3rd party, even at the expense of user inconvenience (such as asking the user about their country instead of automatically checking it through a 3rd party service). The one exclusion is, of course, fetching the ip lists: one can not download them without connecting to a remote server. The 2 sources currently implemented are RIPE and ARIN - both are official regional Internet registries, so I consider them a trusted source.

Besides that, the scripts store some data in the config file which can be read by any local user on your machine. I don't think there is any sensitive data in there but you can check by yourself. The path is /etc/geoblocker-bash/geoblocker-bash.conf .

There is also the "data" folder which the -install script creates in /var/lib/geoblocker-bash . It stores: fetched ip lists, a backup of the config file, a file that stores pre-install default policies for the INPUT and FORWARD iptables chains (which is used to restore the policies if you uninstall), and a backup file of last-known-good iptables state and geoblocker-related ipsets. That last file is the only thing that is probably somewhat sensitive. The data folder and the files inside it require root permissions to read.

All that said, this is open-source software that I'm developing for free, and I'm not taking **any** responsibility for your data, or for these scripts behaving or misbehaving in your environment etc etc etc. You are welcome to inspect the code by yourself and modify it to your taste.
