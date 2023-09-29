# geoblocker-bash
Automatic geoip blocker for Linux, written purely in Bash.

Fetches ipv4 ip lists for user-specified countries, then uses them for either a whitelist or a blacklist (selected during installation) to either block all connections from those countries (blacklist), or only allow connections from them (whitelist).

Currently employs iptables as the backend (nftables support will probably get added eventually). Implements persistence and automatic update of the ip lists. When creating iptables rules, employs ipsets for best performance. Implements many reliability features. Allows for quite a lot of customization but easy to install and configure (and easy to uninstall).

The ip lists are fetched from RIPE - regional Internet registry for Europe, the Middle East and parts of Central Asia. RIPE stores ip lists for countries in other regions as well, so currently this can be used for any country in the world.

Intended use case is a server/computer that needs to be publicly accessible only in a certain country or countries (whitelist), or should not be accessible from certain countries.

I created this project for running on my own server, and it's being doing its job since the early releases, reducing the bot scans/attacks (which I'd been seeing a lot in the logs) to virtually zero. As I wanted it to be useful to other people as well, I implemented many reliability features which should make it unlikely that the scripts will misbehave on systems other than my own. But of course, use at your own risk. Before publishing a new release, I run the code through shellcheck to test for potential issues, and test the scripts on my server.

## **TL;DR**

Recommended to read the NOTES section below.

**To install:**
1) Install prerequisites. On Debian, Ubuntu and derivatives run: ```sudo apt install ipset jq wget grepcidr``` (on other distributions, use their built-in package manager. note that I only test on Debian, Ubuntu and Mint)
2) Download the latest realease:
https://github.com/blunderful-scripts/geoblocker-bash/releases
3) Put all scripts in this suite into the same folder somewhere in your home directory
4) Optional: If intended use is whitelist, use the check_ip_in_ripe.sh script to make sure that your public ip address is included in the list fetched from RIPE, so you do not get locked out of your server.
- example (for Germany): ```bash check_ip_in_ripe.sh -c DE -i <your_public_ip_address>```
5) Run ```sudo bash geoblocker-bash-install -m <whitelist|blacklist> -c <"country_codes">```
- example (whitelist for Germany): ```sudo bash geoblocker-bash-install -m whitelist -c DE```
- example (blacklist for Germany and Netherlands): ```sudo bash geoblocker-bash-install -m blacklist -c "DE NL"```

(when specifying multiple countries, put the list in double quotes)

6) That's it! If no errors occured during installation (such as missing prerequisites), geoblocking should be active, and automatic list updates should just work. By default, ip lists will be updated daily at 4am - you can verify that updates do work next day by running something like ```sudo cat /var/log/syslog | grep geoblocker-bash```
 
**To change configuration:**
run ```sudo geoblocker-bash <action> [-c "country_codes"]```

where 'action' is either 'add', 'remove' or 'schedule'.
- example (to add whitelists for Germany and Netherlands): ```sudo geoblocker-bash add -c "DE NL"```
- example (to remove whitelist for Germany): ```sudo geoblocker-bash remove -c DE```

 To disable/enable/change the autoupdate schedule, use the '-s' option followed by either cron schedule expression in doulbe quotes, or 'disable':
 ```sudo geoblocker-bash schedule -s <cron_schdedule_expression>|disable```
- example (to enable or change periodic cron job schedule): ```sudo geoblocker-bash schedule -s "1 4 * * *"```
- example (to disable ip lists autoupdate entirely): ```sudo geoblocker-bash schedule -s disable```
 
**To check on current geoblocking status:**
- run ```sudo geoblocker-bash status```

**To uninstall:**
- run ```sudo geoblocker-bash-uninstall```

**To switch mode (from whitelist to blacklist or the opposite):**
- simply re-install

## **Prerequisites**:

- Linux running systemd (tested on Debian, Ubuntu and Mint, should work on any Debian derivative, may require modifications to work on other distributions)
- iptables - firewall management utility (nftables support may get implemented later)
- standard GNU utilities including awk, sed, grep, bc

additional mandatory prerequisites: to install, run ```sudo apt install ipset wget jq grepcidr```
- wget (or alternatively curl) is used by the "fetch" and "check_ip_in_ripe" scripts to download lists from RIPE
- ipset utility is a companion tool to iptables (used by the "apply" script to create an efficient iptables whitelist rule)
- jq - Json processor (used to parse lists downloaded from RIPE)
- grepcidr - filters ip addresses matching CIDR patterns (used by check_ip_in_ripe.sh to check if an ip address belongs to a subnet from a list of subnets)

## **Notes**

1) Only the *install, *uninstall, *manage (also called by running 'geoblocker-bash' after installation) and check_ip_in_ripe.sh scripts are intended as a user interface. The *manage script saves the config to a file and implements coherency checks between that file and the actual firewall state. While you can run the other scripts separately, if you make any changes to firewall geoblocking, next time you run the *manage script it will insist on reverting any such changes as they are not reflected in the config file.

2) Firewall config, as well as automatic ip list updates, is made persistent via cron jobs: a periodic job running by default on a daily schedule, and a job that runs at system reboot (after 30 seconds delay). Either or both cron jobs can be disabled (run the *install script with the -h switch to find out how).

3) You can specify a custom schedule for the periodic cron job by passing an argument to the install script. Run it with the '-h' option for more info.

4) Note that cron jobs will be run as root.

5) To test before deployment, you can run the install script with the "-p" (nodrop) option to apply all actions except actually blocking incoming connections (will NOT set INPUT chain policy to DROP). This way, you can make sure no errors are encountered, and check resulting iptables config before commiting to actual blocking. To enable blocking later, reinstall without the "-p" option.

6) To test before deployment, you can run the install script with the "-n" option to skip creating the reboot cron job which implements persistence. This way, a simple machine restart will undo all changes made to the firewall. To enable persistence later, reinstall without the "-n" option.

7) The run, fetch and apply scripts write to syslog in case an error occurs. The run script also writes to syslog upon success. To verify that cron jobs ran successfully, on Debian and derivatives run ```sudo cat /var/log/syslog | grep geoblocker-bash```

8) If you want support for ipv6, please let me know using the Issues tab, and I may consider implementing it.

9) These scripts will not run in the background consuming resources (except for a short time when triggered by the cron jobs). All the actual blocking is done by the system firewall. The scripts offer an easy and relatively fool-proof interface with the firewall, and automated ip lists fetching, persistence and auto-update.

10) I will appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have a suggestion for code improvement, please let me know as well. You can use the "Discussions" and "Issues" tabs for that.

## **In detail**

The suite currently includes 12 scripts:
1. geoblocker-bash-install
2. geoblocker-bash-uninstall
3. geoblocker-bash-manage
4. geoblocker-bash-run
5. geoblocker-bash-fetch
6. geoblocker-bash-apply
7. geoblocker-bash-cronsetup
8. geoblocker-bash-backup
9. geoblocker-bash-common
10. geoblocker-bash-reset
11. validate_cron_schedule.sh
12. check_ip_in_ripe.sh

The scripts intended as user interface are **-install**, **-uninstall**, **-manage** and **check_ip_in_ripe.sh**. All the other scripts are intended as a back-end, although they can be run by the user as well. If you just want to install and move on, you only need to run the -install script, specify mode with the -m option and specify country codes with the "-c" option. Provided you are not missing any prerequisites, it should be as easy as that.
After installation, the user interface is provided by simply running "geoblocker-bash", which is a symlink to the -manage script.

**The -install script**
- Creates system folder structure for scripts, config and data.
- Copies all scripts included in this suite to /usr/local/bin
- Creates backup of pre-install policies for INPUT and FORWARD chains
- Calls geoblocker-bash-manage to set up geoblocker and then call the -fetch and -apply scripts.
- If an error occurs during the installation, calls the uninstall script to revert any changes made to the system.
- Accepts optional custom cron schedule expression as an argument. Default cron schedule is "0 4 * * *" - at 4:00 [am] every day.
- Accepts the '-n' option switch to disable persistence

**The -uninstall script**
- Doesn't require any arguments
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes associated iptables rules and removes the whitelist ipset
- Deletes scripts' data folder /var/lib/geoblocker-bash
- Deletes the scripts from /usr/local/bin

**The -manage script**: provides an interface to configure geoblocking.

```geoblocker-bash-manage <add|remove|status> [-c <country_code>]``` :
* Adds or removes the specified country codes (tld's) to/from the config file
* Calls the -run script to fetch and apply the ip lists
* Calls the -backup script to create a backup of current config, ipsets and iptables state.

```geoblocker-bash-manage schedule -s <"schedule_expression">``` : enables automatic ip lists update and configures the schedule for the periodic cron job which implements this feature.

```geoblocker-bash-manage schedule -s disable``` : disables ip lists autoupdate.

**The -run script**: Serves as a proxy to call the -fetch, -apply and -backup scripts with arguments required for each action.

```geoblocker-bash-run add -c <"country_codes">``` : Fetches iplists and loads ipsets and iptables rules for specified countries.

```geoblocker-bash-run remove -c <"country_codes">``` : Removes iplists, ipsets and iptables rules for specified countries.

```geoblocker-bash-run update``` : intended for triggering from periodic cron jobs. Updates the ipsets for all country codes that had been previously configured. Also used by the reboot cron job to implement persistence.

**The -fetch script**
- Fetches ipv4 subnets list for a given country code from RIPE.
- Parses, validates, compiles the downloaded list, and saves to a file.

**The -apply script**:  directly interfaces with iptables. Creates or removes ipsets and iptables rules for specified country codes.

```geoblocker-bash-apply add -c <"country_codes">``` :
- Loads an ip list file for specified countries into ipsets and sets iptables rules to only allow connections from the local subnet and from subnets included in the ipsets.

```geoblocker-bash-apply remove -c <"country_codes">``` :
- removes ipsets and associated iptables rules for specified countries.

**The -cronsetup script** exists to manage all the cron-related logic in one place. Called by the -manage script. Applies settings stored in the config file.

**The -backup script**: Creates a backup of the current iptables state and geoblocker-associated ipsets, or restores them from backup.

```geoblocker-bash-backup backup``` : Creates a backup of the current iptables state and geoblocker-associated ipsets.

```geoblocker-bash-backup restore``` : Used for automatic recovery from fault conditions (should not happen but implemented just in case)
- Restores ipsets and iptables state from backup
- If restore from backup fails, assumes a fundamental issue and disables geoblocking entirely

**The -reset script:**: is called by the install script to clean up previous installation config (just in case you install again without uninstalling first)

**The -common script:** : Stores common functions and variables for geoblocker-bash suite. Does nothing if called directly.

**The validate_cron_schedule.sh script** is used by the -cronsetup script. It accepts a cron schedule expression and attempts to make sure that it conforms to the crontab format.

**The check_ip_in_ripe.sh script** can be used to verify that a certain ip address belongs to a subnet found in RIPE's records for a given country. It is not called from other scripts.

## **Extra notes**

- All scripts (except -common) display "usage" when called with the "-h" option. You can find out about some additional options specific for each script by running it with that option.
- Most scripts accept the "-d" option for debug
- The fetch script can be easily modified to get the lists from another source instead of RIPE, for example from ipdeny.com
- If you live in a small country, the fetched list may be shorter than 100 subnets. If that's the case, the fetch and check_ip_in_ripe scripts will assume that the download failed and refuse to work. You can change the value of the "min_subnets_num" variable in both scripts to work around that.
- If you remove your country's whitelist using the -manage script, you will probably get locked out of your remote server.
