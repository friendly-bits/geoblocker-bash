# geoblocker_bash
Automatic geoip blocker for Linux based on a whitelist for a country or multiple countries, written purely in Bash.

Fetches, parses and validates an ipv4 whitelist for given countries, then blocks (via iptables rules) incoming traffic from anywhere except whitelisted subnets and local subnet. Implements persistence and automatic update of the whitelist. Comes with built-in mechanisms for fault detection and recovery. Easy to install and configure (and easy to uninstall).

The ip lists are fetched from RIPE - regional Internet registry for Europe, the Middle East and parts of Central Asia. RIPE stores ip lists for countries in other regions as well, so currently this can be used for any country in the world.

Intended use case is a server/computer that needs to be publicly accessible only in a certain country or countries.

I created this project for running on my own server, and it's being doing its job since the early releases, reducing the bot scans/attacks (which I'd been seeing a lot in the logs) to virtually zero. As I wanted it to be useful for other people as well, I implemented many reliability features which should make it unlikely that the scripts will misbehave on systems other than my own. But of course, use at your own risk.

## **TL;DR**

Recommended to read the NOTES section below.

**To install:**
1) Install prerequisites. On Debian and derivatives run: ```sudo apt install ipset jq wget grepcidr``` (other distributions may have slightly different package names)
2) Download the latest realease:
https://github.com/blunderful-scripts/geoblocker_bash/releases
3) Put *all* scripts in this suite into the same folder
4) Optional: Use the check_ip_in_ripe.sh script to make sure that your public ip address is included in the list fetched from RIPE, so you do not get locked out of your server.
- example (for Germany): ```bash check_ip_in_ripe.sh -c DE -i <your_public_ip_address>```
5) Once verified that your public ip address is included in the list, run

```sudo bash geoblocker_bash-install -c <"country_codes">```
- example (for Germany): ```sudo bash geoblocker_bash-install -c DE```
- example (for Germany and Netherlands): ```sudo bash geoblocker_bash-install -c "DE NL"```

(when specifying multiple countries, put the list in double quotes)

6) That's it! If no errors occured during installation (such as missing prerequisites), your computer should now only be accessible from the countries you specified during installation, and automatic list updates should just work. By default, ip lists will be updated daily at 4am - you can verify that updates do work next day by running something like ```cat /var/log/syslog | grep geoblocker_bash```
 
**To change configuration:**
run ```sudo geoblocker_bash-manage -a <action> [-c "country_codes"]```

where 'action' is either 'add', 'remove' or 'schedule'.
- example (to add whitelists for Germany and Netherlands): ```sudo geoblocker_bash-manage -a add -c "DE NL"```
- example (to remove whitelist for Germany): ```sudo geoblocker_bash-manage -a remove -c DE```

 To disable/enable/change the schedule, use the '-s' option followed by either cron schedule expression in doulbe quotes, or 'disable':
 ```sudo geoblocker_bash-manage -a schedule -s <cron_schdedule_expression>|disable```
- example (to enable or change periodic cron job schedule): ```sudo geoblocker_bash-manage -a schedule -s "1 4 * * *"```
- example (to disable cron jobs entirely, meaning there will be no persistence): ```sudo geoblocker_bash-manage -a schedule -s disable```
 
**To uninstall:**
- run ```sudo geoblocker_bash-uninstall```

## **Prerequisites**:

- Linux running systemd (tested on Debian and Mint, should work on any Debian derivative, may require modifications to work on other distributions)
- iptables - firewall management utility (nftables support may get implemented later)
- standard GNU utilities including awk, sed, grep, bc

additional mandatory prerequisites: to install, run ```sudo apt install ipset wget jq grepcidr```
- wget (or alternatively curl) is used by the "fetch" and "check_ip_in_ripe" scripts to download lists from RIPE
- ipset utility is a companion tool to iptables (used by the "apply" script to create an efficient iptables whitelist rule)
- jq - Json processor (used to parse lists downloaded from RIPE)
- grepcidr - filters ip addresses matching CIDR patterns (used by check_ip_in_ripe.sh to check if an ip address belongs to a subnet from a list of subnets)

## **Notes**

1) Changes applied to iptables are made persistent via cron jobs: a periodic job running by default on a daily schedule, and a job that runs at system reboot (after 30 seconds delay).

2) You can specify a custom schedule for the periodic cron job by passing an argument to the install script. Run it with the '-h' option for more info.

3) Note that cron jobs will be run as root.

4) To test before deployment, you can run the install script with the "-n" option to apply all actions except actually blocking incoming connections (will NOT set INPUT chain policy to DROP). This way, you can make sure no errors are encountered, and check resulting iptables config before commiting to actual blocking. To enable blocking later, reinstall without the "-n" option.

5) To test before deployment, you can run the install script with the "-s disable" option to skip creating cron jobs. This way, a simple server restart will undo all changes made to the firewall. To enable persistence later, install again without the "-s disable" option or run ```geoblocker_bash-manage -a schedule -s <"your_cron_schedule">```.

6) The run, fetch and apply scripts write to syslog in case an error occurs. The run script also writes to syslog upon success. To verify that cron jobs ran successfully, on Debian and derivatives run ```sudo cat /var/log/syslog | grep geoblocker_bash```

7) In the near'ish future support for blacklists may get implemented as well.

8) If you want support for ipv6, please let me know using the Issues tab, and I may consider implementing it.

9) These scripts will not run in the background consuming resources (except for a short time when triggered by the cron jobs). All the actual blocking is done by the system firewall. The scripts offer an easy and relatively fool-proof interface with the firewall, and automated ip lists fetching, persistence and auto-update.

10) I will appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have a suggestion for code improvement, please let me know as well. You can use the "Discussions" and "Issues" tabs for that.

## **In detail**

The suite currently includes 11 scripts:
1. geoblocker_bash-install
2. geoblocker_bash-uninstall
3. geoblocker_bash-manage
4. geoblocker_bash-run
5. geoblocker_bash-fetch
6. geoblocker_bash-apply
7. geoblocker_bash-cronsetup
8. geoblocker_bash-backup
9. geoblocker_bash-common
10. validate_cron_schedule.sh
11. check_ip_in_ripe.sh

The scripts intended as user interface are **-install**, **-uninstall**, **-manage** and **check_ip_in_ripe.sh**. All the other scripts are intended as a back-end, although they can be run by the user as well. If you just want to install and move on, you only need to run the -install script and specify your country with the "-c <country>" option. Provided you are not missing any prerequisites, it should be as easy as that.

**The -install script**
- Creates system folder structure for scripts, config and data.
- Copies all scripts included in this suite to /usr/local/bin
- Creates backup of pre-install policies for INPUT and FORWARD chains
- Calls geoblocker_bash-manage to set up geoblocker and then call the -fetch and -apply scripts.
- If an error occurs during the installation, calls the uninstall script to revert any changes made to the system.
- Accepts optional custom cron schedule expression as an argument. Default cron schedule is "0 4 * * *" - at 4:00 [am] every day.

**The -uninstall script**
- Doesn't require any arguments
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes associated iptables rules and removes the whitelist ipset
- Deletes scripts' data folder /var/lib/geoblocker_bash
- Deletes the scripts from /usr/local/bin

**The -manage script**: provides an interface to configure geoblocking.

```geoblocker_bash-manage -a add|remove -c <country_code>``` :
* Adds or removes the specified country codes (tld's) to/from the config file
* Calls the -run script to fetch and apply the ip lists
* Calls the -backup script to create a backup of current config, ipsets and iptables state.

```geoblocker_bash-manage -a schedule -s <"schedule_expression">``` : enables persistence and configures the schedule for the periodic cron job.

```geoblocker_bash-manage -a schedule -s disable``` : disables persistence.

**The -run script**: Serves as a proxy to call the -fetch, -apply and -backup scripts with arguments required for each action.

```geoblocker_bash-run -a add -c <"country_codes">``` : Fetches iplists and loads ipsets and iptables rules for specified countries.

```geoblocker_bash-run -a remove -c <"country_codes">``` : Removes iplists, ipsets and iptables rules for specified countries.

```geoblocker_bash-run -a update``` : intended for triggering from periodic cron jobs. Updates the ipsets for all country codes that had been previously configured. Also used by the reboot cron job to implement persistence.

**The -fetch script**
- Fetches ipv4 subnets list for a given country code from RIPE.
- Parses, validates, compiles the downloaded list, and saves to a file.

**The -apply script**:  directly interfaces with iptables. Creates or removes ipsets and iptables rules for specified country codes.

```geoblocker_bash-apply -a add -c <"country_codes">``` :
- Loads an ip list file for specified countries into ipsets and sets iptables rules to only allow connections from the local subnet and from subnets included in the ipsets.

```geoblocker_bash-apply -a remove -c <"country_codes">``` :
- removes ipsets and associated iptables rules for specified countries.

**The -cronsetup script** exists to manage all the cron-related logic in one place. Called by the -manage script to enable/disable persistence and schedule cron jobs.

**The -backup script**: Creates a backup of the current iptables state and geoblocker-associated ipsets, or restores them from backup.

```geoblocker_bash-backup -a backup``` : Creates a backup of the current iptables state and geoblocker-associated ipsets.

```geoblocker_bash-backup -a restore``` : Used for automatic recovery from fault conditions (should not happen but implemented just in case)
- Restores ipsets and iptables state from backup
- If restore from backup fails, assumes a fundamental issue and disables geoblocking entirely

**The -common script:** : Stores common functions and variables for geoblocker_bash suite. Does nothing if called directly.

**The validate_cron_schedule.sh script** is used by the -cronsetup script. It accepts a cron schedule expression and attempts to make sure that it conforms to cron format.

**The check_ip_in_ripe.sh script** can be used to verify that a certain ip address belongs to a subnet found in RIPE's records for a given country. It is not called from other scripts.

## **Extra notes**

- All scripts (except -common) display "usage" when called with the "-h" option. You can find out about some additional options specific for each script by running it with the "-h" option.
- All scripts accept the "-d" option for debug
- The fetch script can be easily modified to get the lists from another source instead of RIPE, for example from ipdeny.com
- If you live in a small country, the fetched list may be shorter than 100 subnets. If that's the case, the fetch and check_ip_in_ripe scripts will assume that the download failed and refuse to work. You can change the value of the "min_subnets_num" variable in both scripts to work around that.
- If you remove your country's whitelist using the -manage script, you will probably get locked out of your remote server.
