## **Notes**
1) Only the **-install**, **-uninstall**, **-manage** (also called by running '**geoblocker-bash**' after installation) and **check-ip-in-registry.sh** scripts are intended as user interface. The -manage script saves the config to a file and implements coherency checks between that file and the actual firewall state. While you can run the other scripts individually, if you make changes to firewall geoblocking rules, next time you run the -manage script it may insist on reverting those changes since they are not reflected in the config file.

2) There are 3 ways to get yourself locked out of your remote server with this suite:
- install in whitelist mode without including your country in the whitelist
- install in whitelist mode and later remove your country from the whitelist
- Blacklist your country (either during installation or later)

The scripts will warn you in each of these situations and wait for your input (you can press Y and do it anyway), but that depends on you correctly specifying your country code during installation. The installer will ask you about it. If you prefer, you can skip by pressing Enter - that will disable this feature. If you do provide the -install script your country code, it will be added to the config file on your machine. That config file (path: /etc/geoblocker-bash/geoblocker-bash.conf) is plain-text, so technically any user on your machine can read it. However neither script in this suite will share the information with any external service. That said, once you connect to any server on the internet, that server knows your ip and can check your location by that ip - so I do not consider this a big secret.

3) Geoblocking, as well as automatic list updates, is made persistent via cron jobs: a periodic job running by default on a daily schedule, and a job that runs at system reboot (after 30 seconds delay). Either or both cron jobs can be disabled (run the *install script with the -h option to find out how).

4) You can specify a custom schedule for the periodic cron job by passing an argument to the install script. Run it with the '-h' option for more info.

5) Note that cron jobs will be run as root.

6) To test before deployment, if you want to use the whitelist functionality, you can run the install script with the "-p" (nodrop) option to apply all actions except actually blocking incoming connections (will NOT set INPUT chain policy to DROP). This way, you can make sure no errors are encountered, and check resulting iptables config before commiting to actual blocking. To enable blocking later, reinstall without the "-p" option. (the 'nodrop' option has no effect on blacklist function)

7) To test before deployment, you can run the install script with the "-n" option to skip creating the reboot cron job which implements persistence and with the '-s disable' option to skip creating the autoupdate cron job. This way, a simple machine restart will undo all changes made to the firewall. For example: ```sudo bash geoblocker-bash-install -c <country_code> -m whitelist -n -s disable```. To enable persistence and autoupdate later, reinstall without both options.

8) The run, fetch and apply scripts write to syslog in case an error occurs. The run and fetch scripts also write to syslog upon success. To verify that cron jobs ran successfully, on Debian and derivatives run ```sudo cat /var/log/syslog | grep geoblocker-bash```

9) If you want support for ipv6, please let me know using the Issues tab, and I may consider implementing it.

10) These scripts will not run in the background consuming resources (except for a short time when triggered by the cron jobs). All the actual blocking is done by the system firewall. The scripts offer an easy and relatively fool-proof interface with the firewall, config persistence, automated subnet lists fetching and auto-update.

11) Sometimes the RIPE server is temporarily unavailable and if you're unlucky enough to attempt installation during that time frame, the fetch script will fail which will cause the installation to fail as well. Try again after some time. Once the installation succeeds, an occasional fetch failure during autoupdate won't cause any issues as last successfully fetched ip list will be used until the next autoupdate cycle succeeds.

12) If you want to change the autoupdate schedule but you don't know the crontab expression syntax, check out https://crontab.guru/ (no affiliation - I just think it's handy)

13) I will appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have a suggestion for code improvement, please let me know as well. You can use the "Discussions" and "Issues" tabs for that.
