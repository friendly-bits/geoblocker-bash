# geoblocker_bash
Automatic geoip blocker for Linux based on a whitelist for a country or multiple countries.

Suite of bash scripts with easy install and uninstall, focusing on reliability and efficiency. Fetches, parses and validates an ipv4 whitelist for given countries, then blocks incoming traffic from anywhere except whitelisted subnets. Implements automatic update of the whitelist. Uses iptables.

The ip list is fetched from RIPE - regional Internet registry for Europe, the Middle East and parts of Central Asia. RIPE appears to store ip lists for countries in other regions as well, so currently this can be used for any country in the world.

Intended use case is a server/computer that needs to be publically accessible only in a certain country or countries.

**TL;DR**

Recommended to read the NOTES section below.

**To install:**
1) Install prerequisites. On Debian and derivatives run: sudo apt install ipset jq wget grepcidr
2) Download the latest realease:
https://github.com/blunderful-scripts/geoblocker_bash/releases
3) Put *all* scripts in this suite into the same folder
4) Use the check_ip_in_ripe script to make sure that your public ip address is included in the list fetched from RIPE, so you do not get locked out of your server.
- example: _'bash check_ip_in_ripe.sh -c DE -i <your_public_ip_address>' (for Germany)_
5) Once verified that your public ip address is included in the list, run 'sudo bash geoblocker_bash-install -c "<country_code [country_code] ... [country_code]>"'
- example: _'sudo bash geoblocker_bash-install -c DE' (for Germany)_
- example: _'sudo bash geoblocker_bash-install -c "DE NL"' (for Germany and Netherlands)_
 (when specifying multiple countries, put the list in double quotes)
 
**To manage:**
- run 'sudo geoblocker_bash-manage -a <add|remove|schedule> [-c "country_code country_code ... country_code"]'
- example (to add whitelists for Germany and Netherlands): _'sudo geoblocker-manage -a add -c "DE NL"'_
- example (to remove whitelist for Germany): _'sudo geoblocker-manage -a remove -c DE'_
- example (to change periodic cron job schedule): _'sudo geoblocker-manage -a schedule -s "1 4 * * *"_
 
**To uninstall:**
- run 'sudo geoblocker_bash-uninstall'

**Prerequisites**:
- Linux running systemd (tested on Debian and Mint, should work on any Debian derivative, may require modifications to work on other distributions)
- Root access
- iptables (default firewall management utility on most linux distributions)
- standard GNU utilities including awk, sed, grep, bc

additional mandatory prerequisites: to install, run 'sudo apt install ipset wget jq grepcidr'
- wget (or alternatively curl) is used by the "fetch" and "check_ip_in_ripe" scripts to download lists from RIPE
- ipset utility is a companion tool to iptables (used by the "apply" script to create an efficient iptables whitelist rule)
- jq - Json processor (used to parse lists downloaded from RIPE)
- grepcidr - filters ip addresses matching CIDR patterns (used by check_ip_in_ripe.sh to check if an ip address belongs to a subnet from a list of subnets)

**NOTES**

1) Changes applied to iptables are made persistent via cron jobs: a periodic job running at a daily schedule (which you can optionally change when running the install script), and a job that runs at system reboot (after 30 seconds delay).

2) You can specify a custom schedule for the periodic cron job by passing an argument to the install script. Run it with the '-h' switch for more info.

3) **Note** that cron jobs **will be run as root**.

4) To test before deployment, you can run the install script with the "-p" option switch to apply all actions except actually blocking incoming connections (will NOT set INPUT chain policy to DROP). This way, you can make sure no errors are encountered, and check resulting iptables config before commiting to actual blocking. To enable blocking later, install again without the "-p" switch (or manually change iptables policies).

5) To test before deployment, you can run the install script with the "-n" switch to skip creating cron jobs. This way, a simple server restart will undo all changes made to the firewall. To enable persistence later, install again without the "-n" switch.

6) The run, fetch and apply scripts write to syslog in case an error occurs. The run script also writes to syslog upon success. To verify that cron jobs ran successfully, on Debian and derivatives run 'sudo cat /var/log/syslog | grep geoblocker_bash'

7) I will appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have a suggestion for code improvement, please let me know as well. You can use the "Discussions" or "Issues" tab for that.

**Detailed description**

The suite currently includes 9 scripts:
1. geoblocker_bash-install
2. geoblocker_bash-uninstall
3. geoblocker_bash-fetch
4. geoblocker_bash-apply
5. geoblocker_bash-run
6. geoblocker_bash-manage
7. geoblocker_bash-backup
8. validate_cron_schedule.sh
9. check_ip_in_ripe.sh

**The install script**
- Creates system folder structure for scripts, config and data.
- Copies all scripts included in this suite to /usr/local/bin
- Creates backup of pre-install policies for INPUT and FORWARD chains
- Calls geoblocker_bash-manage
- If an error occurs during the installation, calls the uninstall script to revert any changes made to the system.
- Accepts optional custom cron schedule expression as an argument. Default cron schedule is "0 4 * * *" - at 4:00 [am] every day.

**The uninstall script**
- Deletes associated cron jobs
- Restores pre-install state of default policies for INPUT and FORWARD chains
- Deletes associated iptables rules and removes the whitelist ipset
- Deletes scripts' data folder /var/lib/geoblocker_bash
- Deletes the scripts from /usr/local/bin

**The manage script**

Currently supports actions: add, remove, schedule

*manage -a add|remove -c country_code:
* Adds or removes the specified country codes (tld's) to/from the config file
* Calls the -run script to fetch and apply the whitelists
* Creates a periodic cron job and a reboot job, unless ran with the -n (no persistence) option. Cron jobs implement persistence and automatic list updates.
* Accepts optional custom cron schedule expression as an argument.
* If schedule is not specified, uses schedule from the config file (set during the installation by the -install script or later by the -manage script)

*manage -a schedule: changes the schedule for the periodic cron job

**The run script**

Supports actions: add, remove, update

*run -a add -c country_code: Calls the fetch script, then calls the apply script, passing required arguments to fetch and apply ipset and iptables rules for the specified country. If multiple countries are specified, repeats the operation for each country's ip list.

 *run -a remove -c country_code: Calls the apply script, passing required arguments to remove the ipset and iptables rules for the specified country. If multiple countries are specified, repeats the operation for each country's ip list.

 *run -a update: used for triggering from the cron jobs. Calls the fetch script (unless called with the -s - Skip fetch option), then calls the apply script, passing required arguments to fetch and apply ipset and iptables rules for countries listed in the config file. Used to update the ip lists at a periodic schedule, and to activate the rules on reboot.
 
 all actions:
- If successful, calls the backup script to create backup of the current (known-good) iptables state and current ipset.
- If an error is enountered, classifies it as a fatal or a non-fatal error. Fatal errors mean that something is fundamentally broken. Non-fatal errors are transient (for example a download error). For fatal errors, calls the -backup script to restore last known-good ipsets and iptables state.

**The fetch script**
- Fetches ipv4 subnets list for a given country from RIPE.
- Parses, validates and compiles the downloaded list into a plain list, and saves to a file.

**The apply script**
- supports actions: add, remove

*apply -a add -c country_code:
- Loads an existing ip list file for the specified country into an ipset and sets iptables rules to only allow connections from subnets included in the ipset.
- Attempts to determine the local ipv4 subnet for the main network interface and creates an iptables rule to allow all traffic from it.

 *apply -a remove -c country_code:
- removes the ipset and iptables rules for the specified country.

**The backup script**

Supports actions: -b (backup), -r (restore)

*backup -f backup_file -b:
- Creates a backup of the current iptables state and current geoblocker-associated ipsets

*backup -f backup_file -r: used for automatic recovery from fault conditions
- Restores ipsets and iptables state from backup
- If restore from backup fails, assumes a fundamental issue and calls the uninstall script to perform a partial uninstall (removes associated ipsets and iptables rules, restores pre-install policies for INPUT and FORWARD iptables chains, does not remove installed files, config and data).

**The validate_cron_schedule.sh script** is used by the -manage script. It accepts cron schedule expression and attempts to make sure that it complies with the format that cron expects. Used to validate optionally user-specified cron schedule expression.

**The check_ip_in_ripe.sh script** can be used to verify that a certain ip address belongs to a subnet found in RIPE's records for a given country. It is not called from other scripts.

**Additional comments**
- All scripts display "usage" when called with the "-h" switch
- Most scripts accept the "-d" switch for debug
- The fetch script can be easily modified to get the lists from another source instead of RIPE, for example from ipdeny.com
- If you live in a small or undeveloped country, the fetched list may be shorter than 100 subnets. If that's the case, the fetch and check_ip_in_ripe scripts will assume that the download failed and refuse to work. You can change the value of the "min_subnets_num" variable in both scripts to work around that.
- If you remove your country's whitelist using the -manage script, you will probably get locked out of your remote server.
