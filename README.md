# geoblocker-bash
Geoip blocker for Linux aiming for efficiency, reliability and ease of use. Front-end implemented in Bash and the back-end utilizes iptables (nftables support will get implemented eventually).

Intended use case is a server that needs to be publicly accessible only in a certain country or countries (whitelist), or should not be accessible from certain countries (blacklist).

## Features
_(if you are just looking for installation instructions, skip to the [**TL;DR**](#tldr) section)_

Basic functionality is automatic download of complete ipv4 subnet lists for user-specified countries, then using these lists to create either a whitelist or a blacklist (selected during installation) in the firewall, to either block all connections from these countries (blacklist), or only allow connections from them (whitelist).

Subnet lists are fetched from the official regional registries (selected automatically based on the country). Currently supports ARIN (American Registry for Internet Numbers) and RIPE (Regional Internet registry for Europe, the Middle East and parts of Central Asia). RIPE stores subnet lists for countries in other regions as well, so currently this can be used for any country in the world.

All configuration changes required for geoblocking to work are automatically applied to the firewall during installation.

Implements optional (enabled by default) persistence across system reboots and automatic update of the ip lists.

**Reliability**:
- Downloaded lists go through validation process, which safeguards against application of corrupted or incomplete lists to the firewall.
- All scripts perform extensive error detection and handling, so if something goes wrong, chances for bad consequences are rather low.
- Automatic backup of the firewall state before any changes or updates, and automatic restore from backup in case an error occurs during these changes (which normally should never happen but implemented just in case).
- Scripts which serve as a user interface validate all user input to prevent unintended mistakes.
- If a user accidentally requests an action that is about to block their own country (which can happen both in blacklist mode and in whitelist mode), the -manage script will warn them and wait for their input before proceeding.

**Efficiency**:
- When creating iptables rules, a list for each country is compiled into an ipset and that ipset is then used with a matching iptables rule. This way the load on the CPU is minimal when the firewall is processing incoming connection requests.
- Calculates optimized ipset parameters when creating new ipsets, to try and hit the sweet spot for both performance and memory consumption. Typically consumes very little memory (just a couple MB for a very large list) with minimal performance impact.
- Creating new ipsets is done efficiently, so normally it takes less than a second for a very large list (depending on the CPU of course).
- Only performs necessary actions. For example, if a list is up-to-date and already active in the firewall, it won't be re-validated and re-applied to the firewall until the data timestamp changes.
- Scripts are only active for a short time when invoked either directly by the user or by a cron job (once after a reboot and then periodically for an auto-update).
- List parsing and validation are implemented through efficient regex processing, so this is very quick (a fraction of a second for parsing and a few milliseconds for validation, for a very large list, depending on the CPU).

**Ease of use**:
- Installation normally only takes a few seconds and requires only 2 parameters: country code(s) to block and geolbocking mode (whitelist/blacklist).
- Uninstallation takes about a second. It completely removes the suite, removes geoblocking firewall rules and restores pre-install firewall policies. No restart is required.
- Pre-installation, provides a utility to check whether specific ip addresses you might want to blacklist or whitelist are indeed included in the list fetched from the registry.
- Post-installation, provides a command to check on current geoblocking status so you don't have to run a few separate utilities and compare their output manually.
- Post-installation, provides a utility for the user to manage and change geoblocking config (adding or removing country codes, changing the cron schedule etc).
- All that is well documented, read **TL;DR** for more info.
- If an error or invalid input is encountered, provides useful feedback to help you solve the issue.
- Lots of comments in the code, in case you want to change something in it or learn how the scripts are working.

_I created this project for running on my own server, and it's been doing its job since the early releases, reducing the bot scans/attacks (which I'd been seeing a lot in the logs) to virtually zero. As I wanted it to be useful to other people as well, I implemented many reliability features which should make it unlikely that the scripts will misbehave on systems other than my own. But of course, use at your own risk. Before publishing a new release, I run the code through shellcheck to test for potential issues, and test the scripts on my server._

## **TL;DR**

_Recommended to read the NOTES section below._

**To install:**
1) Install pre-requisites. On Debian, Ubuntu and derivatives run: ```sudo apt install ipset jq wget``` (on other distributions, use their built-in package manager. Note that I only test on Debian, Ubuntu and Mint).
2) Download the latest realease: https://github.com/blunderful-scripts/geoblocker-bash/releases
3) Extract all scripts included in the release into the same folder somewhere in your home directory and cd into that directory in your terminal
4) _Optional: read (4a, 4b) below._ 
5) run ```sudo bash geoblocker-bash-install -m <whitelist|blacklist> -c <"country_codes">``` _(examples below)_
6) That's it! By default, subnet lists will be updated daily at 4am - you can verify that automatic updates work by running ```sudo cat /var/log/syslog | grep geoblocker-bash``` on the next day (change syslog path if necessary, according to the location assigned by your distro).

_Optional 4th step:_

4a) If intended use is whitelist and you want to install geoblocker-bash on a remote machine, run the check-ip-in-registry.sh script before installation to make sure that your local public ip addresses are included in the whitelist fetched from the internet registry, so you do not get locked out of your remote server. check-ip-in-registry.sh has an additional pre-requisite: grepcidr. Install it with ```sudo apt install grepcidr```.
- example (for US): ```bash check-ip-in-registry.sh -c US -i <"ip_address ... ip_address">``` (if checking multiple ip addresses, use double quotation marks)

4b) If intended use is a blacklist and you know in advance some of the ip addresses you want to block, use check-ip-in-registry.sh script before installation to verify that those ip addresses are included in the list fetched from the registry. The syntax is the same as above.

_Examples for running the -install script:_
- example (whitelist Germany and block all other countries): ```sudo bash geoblocker-bash-install -m whitelist -c DE```
- example (blacklist Germany and Netherlands and allow all other countries): ```sudo bash geoblocker-bash-install -m blacklist -c "DE NL"```

(when specifying multiple countries, put the list in double quotes)


  
**To check current geoblocking status:**
- run ```sudo geoblocker-bash status```

**To change configuration:**

run ```sudo geoblocker-bash <action> [-c <"country_codes">] | [-s <"cron_schedule">|disable]```

where 'action' is either 'add', 'remove' or 'schedule'.
- example (to add subnet lists for Germany and Netherlands): ```sudo geoblocker-bash add -c "DE NL"```
- example (to remove the subnet list for Germany): ```sudo geoblocker-bash remove -c DE```

 To disable/enable/change the autoupdate schedule, use the '-s' option followed by either cron schedule expression in doulbe quotes, or 'disable':
 ```sudo geoblocker-bash schedule -s <"cron_schdedule_expression">|disable```
- example (to enable or change periodic cron job schedule): ```sudo geoblocker-bash schedule -s "1 4 * * *"```
- example (to disable lists autoupdate): ```sudo geoblocker-bash schedule -s disable```
 
**To uninstall:**
- run ```sudo geoblocker-bash-uninstall```

**To switch mode (from whitelist to blacklist or the opposite):**
- simply re-install

## **Pre-requisites**:
(if a pre-requisite is missing, the -install script will tell you which)
- bash v4.0 or later (should be included with any relatively modern linux distribution)
- Linux with systemd (tested on Debian, Ubuntu and Mint, should work on any Debian derivative, may work or may require slight modifications to work on other distributions)
- iptables - firewall management utility (nftables support will likely get implemented later)
- standard GNU utilities including awk, sed, grep, bc
- for persistence and autoupdate functionality, requires the cron service to be enabled

additional mandatory pre-requisites: to install, run ```sudo apt install ipset wget jq```

optional: the check-ip-in-registry.sh script requires grepcidr. install it with ```sudo apt install grepcidr```

## **Notes**
For some helpful notes about using this suite, read [NOTES.md](/NOTES.md).

## **In detail**
For more detailed description of each script, read [DETAILS.md](/DETAILS.md).

## **Data safety**
For notes about data safety (mostly intended for security nerds), read [DATASAFETY.md](/DATASAFETY.md).

## **Extra notes**

- Most scripts display "usage" when called with the "-h" option. You can find out about some additional options specific to each script by running it with that option.
- The fetch script can be modified to get the lists from another source, for example from ipdeny.com. I purposefully avoided that and instead implemented fetching from the official regional Internet registries which AFAIK are the 1st party for these lists and as such, a more trustworthy source (although I have nothing against ipdeny.com)
