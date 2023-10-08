# geoblocker-bash
Reliable and easy to use geoip blocker for Linux. Front-end implemented in Bash and the back-end utilizes iptables (nftables support will get implemented eventually).

## Features and operation
_(if you are just looking for installation instructions, skip to **TL;DR** section)_

Basic functionality is automatic download of complete ipv4 subnet lists for user-specified countries, then using these lists to create either a whitelist or a blacklist (selected during installation) in the firewall, to either block all connections from these countries (blacklist), or only allow connections from them (whitelist).

Subnet lists are fetched from the official regional registries (selected automatically based on the country). Currently supports ARIN (American Registry for Internet Numbers) and RIPE (Regional Internet registry for Europe, the Middle East and parts of Central Asia). RIPE stores subnet lists for countries in other regions as well, so currently this can be used for any country in the world.

All necessary configuration changes required for geoblocking to work are automatically applied to the firewall during installation or post-installation when changing config (read TL;DR for more info).

Implements optional (enabled by default) persistence across system reboots and automatic update of the ip lists.

Aims to be very reliable and implements lots of reliability features. Including:
- Downloaded lists go through a validation process, with safeguards in place to prevent application of bad or incomplete lists to the firewall.
- Error detection and handling at each stage and user notification through console messages or through syslog if an error occurs.
- Automatic backup of the active ipsets and the firewall state before any changes, and automatic restore from backup in case an error occurs during these changes (which normally should never happen but implemented just in case).
- Implementation of an easy way for a user to check on current geoblocking status and config (read TL;DR for more info ).

Aims to be very efficient both in the way the scripts operate and in the way the firewall operates:
- When creating iptables rules, a list for each country is compiled into an ipset and that ipset is then used with a matching iptables rule, which is the most efficient way to implement whitelist or blacklist with iptables.
- When creating a new ipset, uses the 'ipset restore' command which is the fastest and most efficient way to do that and normally only takes a second or so for a very large list (depending on the CPU of course).
- Only performs necessary actions. For example, if a list is up-to-date and already active in the firewall, it won't be re-validated and re-applied to the firewall until the data timestamp changes.
- Scripts are only active for a short time when invoked either directly by the user or by a cron job (once after a reboot and then periodically for an auto-update).
- Lists parsing and validation are implemented through efficient regex processing, so this is very quick (validation takes a few milliseconds and parsing takes a fraction of a second for a large list, depending on the CPU).

Intended use case is a server/computer that needs to be publicly accessible only in a certain country or countries (whitelist), or should not be accessible from certain countries (blacklist).

I created this project for running on my own server, and it's being doing its job since the early releases, reducing the bot scans/attacks (which I'd been seeing a lot in the logs) to virtually zero. As I wanted it to be useful to other people as well, I implemented many reliability features which should make it unlikely that the scripts will misbehave on systems other than my own. But of course, use at your own risk. Before publishing a new release, I run the code through shellcheck to test for potential issues, and test the scripts on my server.

## **TL;DR**

Recommended to read the NOTES section below.

**To install:**
1) Install pre-requisites. On Debian, Ubuntu and derivatives run: ```sudo apt install ipset jq wget``` (on other distributions, use their built-in package manager. Note that I only test on Debian, Ubuntu and Mint)
2) Download the latest realease:
https://github.com/blunderful-scripts/geoblocker-bash/releases
3) Extract all scripts included in the release into the same folder somewhere in your home directory and cd into that directory in your terminal
4) ***Optional: If intended use is whitelist and you want to install geoblocker-bash on a remote machine, run the check-ip-in-registry.sh script before installation to make sure that your local public ip addresses are included in the whitelist fetched from the internet registry, so you do not get locked out of your remote server. check-ip-in-registry.sh has an additional pre-requisite: grepcidr. Install it with ```sudo apt install grepcidr```.
- example (for US): ```bash check-ip-in-registry.sh -c US -i <"ip_address ... ip_address">``` (if checking multiple ip addresses, use double quotation marks)
5) ***Optional: if intended use is a blacklist and you know in advance some of the ip addresses you want to block, use check-ip-in-registry.sh script before installation to verify that those ip addresses are included in the list fetched from the registry. The syntax is the same as above.
6) run ```sudo bash geoblocker-bash-install -m <whitelist|blacklist> -c <"country_codes">```
- example (whitelist Germany and block all other countries): ```sudo bash geoblocker-bash-install -m whitelist -c DE```
- example (blacklist Germany and Netherlands and allow all other countries): ```sudo bash geoblocker-bash-install -m blacklist -c "DE NL"```

(when specifying multiple countries, put the list in double quotes)

7) If any significant errors are encountered during installation, the installation will revert itself. Once installation completes successfully, most likely everything is good.
8) That's it! By default, subnet lists will be updated daily at 4am - you can verify that automatic updates work by running ```sudo cat /var/log/syslog | grep geoblocker-bash``` on the next day (change syslog path if necessary, according to the location assigned by your distro).
9) You can check on geoblocking status by running ```sudo geoblocker-bash status```.
 
**To change configuration:**

run ```sudo geoblocker-bash <action> [-c <"country_codes">] | [-s <"cron_schedule">|disable]```

where 'action' is either 'add', 'remove' or 'schedule'.
- example (to add subnet lists for Germany and Netherlands): ```sudo geoblocker-bash add -c "DE NL"```
- example (to remove the subnet list for Germany): ```sudo geoblocker-bash remove -c DE```

 To disable/enable/change the autoupdate schedule, use the '-s' option followed by either cron schedule expression in doulbe quotes, or 'disable':
 ```sudo geoblocker-bash schedule -s <"cron_schdedule_expression">|disable```
- example (to enable or change periodic cron job schedule): ```sudo geoblocker-bash schedule -s "1 4 * * *"```
- example (to disable lists autoupdate): ```sudo geoblocker-bash schedule -s disable```
 
**To check on current geoblocking status:**
- run ```sudo geoblocker-bash status```

**To uninstall:**
- run ```sudo geoblocker-bash-uninstall```

**To switch mode (from whitelist to blacklist or the opposite):**
- simply re-install

## **Pre-requisites**:
(if a pre-requisite is missing, the -install script will tell you which)
- Linux with systemd (tested on Debian, Ubuntu and Mint, should work on any Debian derivative, may work or may require slight modifications to work on other distributions)
- iptables - firewall management utility (nftables support will likely get implemented later)
- standard GNU utilities including awk, sed, grep, bc
- for persistence and autoupdate functionality, requires the cron service to be enabled
- obviously, needs bash (*may* work on some other shells but I do not test on them)

additional mandatory pre-requisites: to install, run ```sudo apt install ipset wget jq```
- wget (or alternatively curl) is used by the "fetch" and "check-ip-in-registry" scripts to download lists from the internet registry
- ipset utility is a companion tool to iptables (used by the "apply" script to create efficient iptables rules)
- jq - Json processor (used to parse ip lists downloaded from RIPE)

optional: the check-ip-in-registry.sh script requires grepcidr. install it with ```sudo apt install grepcidr```
- grepcidr - efficiently filters ip addresses matching CIDR patterns (used to check if an ip address belongs to a subnet from a list of subnets)

## **Notes**

1) Only the *install, *uninstall, *manage (also called by running 'geoblocker-bash' after installation) and check-ip-in-registry.sh scripts are intended as user interface. The *manage script saves the config to a file and implements coherency checks between that file and the actual firewall state. While you can run the other scripts individually, if you make changes to firewall geoblocking rules, next time you run the *manage script it may insist on reverting those changes since they are not reflected in the config file.

2) Firewall config, as well as automatic subnet list updates, is made persistent via cron jobs: a periodic job running by default on a daily schedule, and a job that runs at system reboot (after 30 seconds delay). Either or both cron jobs can be disabled (run the *install script with the -h option to find out how).

3) You can specify a custom schedule for the periodic cron job by passing an argument to the install script. Run it with the '-h' option for more info.

4) Note that cron jobs will be run as root.

5) To test before deployment, if you want to use the whitelist functionality, you can run the install script with the "-p" (nodrop) option to apply all actions except actually blocking incoming connections (will NOT set INPUT chain policy to DROP). This way, you can make sure no errors are encountered, and check resulting iptables config before commiting to actual blocking. To enable blocking later, reinstall without the "-p" option. (the 'nodrop' option has no effect on blacklist function)

6) To test before deployment, you can run the install script with the "-n" option to skip creating the reboot cron job which implements persistence and with the '-s disable' option to skip creating the autoupdate cron job. This way, a simple machine restart will undo all changes made to the firewall. For example: ```sudo bash geoblocker-bash-install -c <country_code> -m whitelist -n -s disable```. To enable persistence and autoupdate later, reinstall without both options.

7) The run, fetch and apply scripts write to syslog in case an error occurs. The run and fetch scripts also write to syslog upon success. To verify that cron jobs ran successfully, on Debian and derivatives run ```sudo cat /var/log/syslog | grep geoblocker-bash```

8) If you want support for ipv6, please let me know using the Issues tab, and I may consider implementing it.

9) These scripts will not run in the background consuming resources (except for a short time when triggered by the cron jobs). All the actual blocking is done by the system firewall. The scripts offer an easy and relatively fool-proof interface with the firewall, config persistence, automated subnet lists fetching and auto-update.

10) Sometimes the RIPE server is temporarily unavailable and if you're unlucky enough to attempt installation during that time frame, the fetch script will fail which will cause the installation to fail as well. Try again after some time. Once the installation succeeds, an occasional fetch failure during autoupdate won't cause any issues as last successfully fetched ip list will be used until the next autoupdate cycle succeeds.

11) If you want to change the autoupdate schedule but you don't know the crontab expression syntax, check out https://crontab.guru/

12) I will appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have a suggestion for code improvement, please let me know as well. You can use the "Discussions" and "Issues" tabs for that.

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
11. validate-cron-schedule.sh
12. check-ip-in-registry.sh

The scripts intended as user interface are **-install**, **-uninstall**, **-manage** and **check-ip-in-registry.sh**. All the other scripts are intended as a back-end, although they can be run by the user as well. If you just want to install and move on, you only need to run the -install script, specify mode with the -m option and specify country codes with the "-c" option. Provided you are not missing any pre-requisites, it should be as easy as that.
After installation, the user interface is provided by simply running "geoblocker-bash", which is a symlink to the -manage script.

**The -install script**
- Creates system folder structure for scripts, config and data.
- Copies all scripts included in this suite to /usr/local/bin
- Creates backup of pre-install policies for INPUT and FORWARD chains
- Calls geoblocker-bash-manage to set up geoblocker and then call the -fetch and -apply scripts.
- If an error occurs during the installation, calls the uninstall script to revert any changes made to the system.
- Accepts optional custom cron schedule expression for autoupdates as an argument with the '-s' option. Default cron schedule is "0 4 * * *" - at 4:00 [am] every day. 'disable' instead of the schedule will disable autoupdate.
- Accepts the '-n' option to disable persistence (reboot cron job won't be created so after system reboot, there will be no more geoblocking - although if you have an autoupdate cron job then it will eventually kick in and re-activate geoblocking)

**The -uninstall script**
- Doesn't require any arguments
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes geoblocking iptables rules and removes the associated ipsets
- Deletes scripts' data folder /var/lib/geoblocker-bash
- Deletes the scripts from /usr/local/bin

**The -manage script**: serves as the main user interface to configure geoblocking after installation. You can also call it by simply typing geoblocker-bash (as during installation, a symlink is created to allow that). As most scripts in this suite, you need to use it with 'sudo' because root privileges are required to access the firewall.

```geoblocker-bash <add|remove> [-c <country_code>]``` :
* Adds or removes the specified country codes (tld's) to/from the config file
* Calls the -run script to fetch and apply the ip lists
* After successful firewall config changes, calls the -backup script to create a backup of current config, ipsets and iptables state.

```geoblocker-bash status```
* Displays information on the current state of geoblocking

```geoblocker-bash-manage schedule -s <"schedule_expression">``` : enables automatic ip lists update and configures the schedule for the periodic cron job which implements this feature.

```geoblocker-bash-manage schedule -s disable``` : disables ip lists autoupdate.

**The -run script**: Serves as a proxy to call the -fetch, -apply and -backup scripts with arguments required for each action.

```geoblocker-bash-run add -c <"country_codes">``` : Fetches iplists and loads ipsets and iptables rules for specified countries.

```geoblocker-bash-run remove -c <"country_codes">``` : Removes iplists, ipsets and iptables rules for specified countries.

```geoblocker-bash-run update``` : intended for triggering from periodic cron jobs. Updates the ipsets for all country codes that had been previously configured. Also used by the reboot cron job to implement persistence.

**The -fetch script**
- Fetches ipv4 subnets lists for given country codes from the regional internet registry (automatically selected based on the country).
- Parses, validates, compiles the downloaded lists, and saves each list to a separate file.
- Implements extensive sanity checks at each stage (fetching, parsing, validating and saving) and handles errors if they occur.
- If a "soft" error is encountered (mostly a temporary network error), retries the download up to 3 times.

**The -apply script**:  directly interfaces with the firewall. Creates or removes ipsets and iptables rules for specified country codes.

```geoblocker-bash-apply add -c <"country_codes">``` :
- Loads an ip list file for specified countries into ipsets and sets iptables rules to only allow connections from the local subnet and from subnets included in the ipsets.

```geoblocker-bash-apply remove -c <"country_codes">``` :
- removes ipsets and associated iptables rules for specified countries.

**The -cronsetup script** manages all the cron-related logic in one place. Called by the -manage script. Applies settings stored in the config file.

**The -backup script**: Creates a backup of the current iptables state and geoblocker-associated ipsets, or restores them from backup.

```geoblocker-bash-backup create-backup``` : Creates a backup of the current iptables state and geoblocker-associated ipsets.

```geoblocker-bash-backup restore``` : Used for automatic recovery from fault conditions (should not happen but implemented just in case)
- Restores ipsets and iptables state from last known good backup
- If restore from backup fails, either gives up (default behavior) or (if you ran the -install script with the -e option for Emergency Deactivation) deactivates geoblocking entirely

**The -reset script:**: is called by the *install script to clean up previous geoblocking rules in the firewall and reset the config (just in case you install again without uninstalling first)

**The -common script:** : Stores common functions and variables for the geoblocker-bash suite. Does nothing if called directly. Most other scripts won't work without it.

**The validate-cron-schedule.sh script** is used by the -cronsetup script. It accepts a cron schedule expression and attempts to make sure that it conforms to the crontab format.

**The check-ip-in-registry.sh script** can be used to verify that a certain ip address belongs to a subnet found in regional registry's records for a given country. It is intended for manual use and is not called from other scripts.

## **Extra notes**

- All scripts (except -common) display "usage" when called with the "-h" option. You can find out about some additional options specific for each script by running it with that option.
- Most scripts accept the "-d" option for debug (and pass it on to any other scripts they call)
- The fetch script can be easily modified to get the lists from another source, for example from ipdeny.com
- If you install the suite in whitelist mode and then remove your country's whitelist using the -manage script, you will probably get locked out of your remote server. If you only have one country in your whitelist, the -manage script will not allow you to remove it in order to prevent exactly this situation. But you can fool it by adding another country and then removing your own country. You may not get locked out while you're still connected to the server but once you disconnect, you may no longer be able to reconnect.
