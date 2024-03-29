## **Notes**
1) The suite uses RIPE as the default source for ip lists. RIPE is a regional registry, and as such, is expected to stay online and free for the foreseeable future. However, RIPE may be fairly slow in some regions. For that reason, I implemented support for fetching ip lists from ipdeny. ipdeny provides aggregated ip lists, meaning in short that there are less entries for same effective geoblocking, so the machine which these lists are installed on has to do less work when processing incoming connection requests. All ip lists the suite fetches from ipdeny are aggregated lists.

2) The scripts intended as user interface are: **-install**, **-uninstall**, **-manage** (also called by running '**geoblocker-bash**' after installation) and **check-ip-in-registry.sh**. The -manage script saves the config to a file and implements coherency checks between that file and the actual firewall state. While you can run the other scripts individually, if you make changes to firewall geoblocking rules, next time you run the -manage script it may insist on reverting those changes since they are not reflected in the config file. The **-backup** script can be used individually. By default, it creates a backup before every action you apply to the firewall. If you encounter issues, you can use it with the 'restore' command to restore the firewall to its previous state. It also restores the config, so the -manage script will not mind.

3) Geoblocking, as well as automatic list updates, is made persistent via cron jobs: a periodic job running by default on a daily schedule, and a job that runs at system reboot (after 30 seconds delay). Either or both cron jobs can be disabled (run the *install script with the -h option to find out how, or read [DETAILS.md](/DETAILS.md)).

4) You can specify a custom schedule for the periodic cron job by passing an argument to the install script. Run it with the '-h' option for more info.

5) Note that cron jobs will be run as root.

7) The run, fetch and apply scripts write to syslog in case an error occurs. The run and fetch scripts also write to syslog upon success. To verify that cron jobs ran successfully, on Debian and derivatives run ```sudo cat /var/log/syslog | grep geoblocker-bash```. On other distributions, you may need to figure out how to access the syslog.

8) These scripts will not run in the background consuming resources (except for a short time when triggered by the cron jobs). All the actual blocking is done by the system firewall. The scripts offer an easy and relatively fool-proof interface with the firewall, config persistence, automated subnet lists fetching and auto-update.

9) Sometimes the RIPE server is temporarily unavailable and if you're unlucky enough to attempt installation during that time frame, the fetch script will fail which will cause the installation to fail as well. Try again after some time or use the ipdeny source. Once the installation succeeds, an occasional fetch failure during autoupdate won't cause any issues as last successfully fetched ip list will be used until the next autoupdate cycle succeeds.

10) If you want to change the autoupdate schedule but you don't know the crontab expression syntax, check out https://crontab.guru/ (no affiliation - I just think it's handy)

11) To test before deployment:
<details> <summary>Read more:</summary>
  
- If you want to use the whitelist functionality, you can run the install script with the "-p" (nodrop) option to apply all actions except actually blocking incoming connections (will NOT set INPUT chain policy to DROP). This way, you can make sure no errors are encountered, and check resulting iptables config before commiting to actual blocking. To enable blocking later, reinstall without the "-p" option. (the 'nodrop' option has no effect on blacklist function)
- You can run the install script with the "-n" option to skip creating the reboot cron job which implements persistence and with the '-s disable' option to skip creating the autoupdate cron job. This way, a simple machine restart should undo all changes made to the firewall (unless you have some software that restores firewall settings after reboot, which is normally not the case). For example: ```sudo bash geoblocker-bash-install -c <country_code> -m whitelist -n -s disable```. To enable persistence and autoupdate later, reinstall without both options.

</details>

12) How to get yourself locked out of your remote server and how to prevent this:
<details> <summary>Read more:</summary>
  
There are 3 ways to get yourself locked out of your remote server with this suite:
- install in whitelist mode without including your country in the whitelist
- install in whitelist mode and later remove your country from the whitelist
- Blacklist your country (either during installation or later)

The -manage script will warn you in each of these situations and wait for your input (you can press Y and do it anyway), but that depends on you correctly specifying your country code during installation. The -install script will ask you about it. If you prefer, you can skip by pressing Enter - that will disable this feature. If you do provide the -install script your country code, it will be added to the config file on your machine and the -manage script will read the value and perform the necessary checks, during installation or later when you want to make changes to the blacklist/whitelist.

</details>
