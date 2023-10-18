# geoblocker-bash
Geoip blocker for Linux aiming for efficiency, reliability and ease of use. Front-end implemented in Bash and the back-end utilizes iptables (nftables support will get implemented eventually).

Intended use case is a computer that needs to be publicly accessible only in a certain country or countries (whitelist), or should not be accessible from certain countries (blacklist).

Should work on every modern'ish desktop/server Linux distribution, doesn't matter which hardware (and even works on embedded to some degree).
 
## Features
_(for installation instructions, skip to the [**TL;DR**](#tldr) section)_

Basic functionality is automatic download of complete ipv4 subnet lists for user-specified countries, then using these lists to create either a whitelist or a blacklist (selected during installation) in the firewall. Besides the basics, there are additional useful features (continue reading to find out which).

ip lists are fetched from the official regional registries (selected automatically based on the country). Currently supports ARIN (American Registry for Internet Numbers) and RIPE (Regional Internet registry for Europe, the Middle East and parts of Central Asia). RIPE stores ip lists for countries in other regions as well, so currently this can be used for any country in the world.

All configuration changes required for geoblocking to work are automatically applied to the firewall during installation.

Implements optional (enabled by default) persistence of geoblocking across system reboots and automatic updates of the ip lists.

**Reliability**:
- Downloaded ip lists go through validation process, which safeguards against application of corrupted or incomplete lists to the firewall.

<details> <summary>Read more:</summary>

- All scripts perform extensive error detection and handling, so if something goes wrong, chances for bad consequences are rather low. I estimate that somewhere between 60% and 80% of the code is error checking and error handling, so *a lot* of effort has been put into ensuring reliability.
- Automatic backup of the firewall state before any changes or updates (optional, enabled by default).
- The *backup script also has a restore command. In case an error occurs while applying changes to the firewall (which normally should never happen), or if you mess something up in the firewall, you can use it to restore the firewall to its previous state.
- If a user accidentally requests an action that is about to block their own country (which can happen both in blacklist mode and in whitelist mode), the *manage script will warn them and wait for their input before proceeding.
</details>

**Efficiency**:
- When creating whitelists/blacklists, utilizes the 'ipset' utility , which makes the firewall much more efficient than applying a large amount of individual rules. This way the load on the CPU is minimal when the firewall is processing incoming connection requests.

<details><summary>Read more:</summary>
  
- When creating new ipsets, calculates optimized ipset parameters in order to maximize performance and minimize memory consumption.
- Creating new ipsets is done efficiently, so normally it takes less than a second for a very large list (depending on the CPU of course).
- Only performs necessary actions. For example, if a list is up-to-date and already active in the firewall, it won't be re-validated and re-applied to the firewall until the data timestamp changes.
- List parsing and validation are implemented through efficient regex processing, so this is very quick: a fraction of a second for parsing and a few milliseconds for validation, for a very large list (at least on x86 CPU).
- The scripts perform most operations (such as parsing and validating ip lists, or processing backups) in memory to avoid unnecessary disk access. So they should be plenty fast even with a slow storage device.
- Scripts are only active for a short time when invoked either directly by the user or by a cron job (once after a reboot and then periodically for an auto-update - both cron jobs are optional and enabled by default).

</details>

**Ease of use**:
- Installation normally takes a few seconds.

<details><summary>Read more:</summary>
  
- Uninstallation normally takes about a second. It completely removes the suite, removes geoblocking firewall rules and restores pre-install firewall policies. No restart is required.
- Sane settings applied during installation by default, but also lots of command-line options for advanced users.
- Pre-installation, provides a utility _(check-ip-in-registry.sh)_ to check whether specific ip addresses you might want to blacklist or whitelist are indeed included in the list fetched from the registry.
- Post-installation, provides a utility (symlinked to _'geoblocker-bash'_) for the user to manage and change geoblocking config (adding or removing country codes, changing the cron schedule etc).
- Post-installation, provides a command _('geoblocker-bash status')_ to check geoblocking rules, active ipsets, and whether there are any issues.
- All that is well documented, read **TL;DR** and **NOTES** for more info. There is also the DETAILS.md file which describes each script and its options more in depth.
- Lots of comments in the code, in case you want to change something in it or learn how the scripts are working.
- Besides extensive documentation, each script displays detailed 'usage' info when executed with the '-h' option.
- Validates all user input, so if you make a mistake, it is unlikely that you break something - the scripts will just say that the input makes no sense and usually tell you what's wrong with it.
</details>

## **TL;DR**

_Recommended to read the [NOTES.md](/NOTES.md) file._

**To install:**

**1)** Install pre-requisites. Use your distro's package manager to install ```ipset jq wget```.

**2)** Download the latest realease: https://github.com/blunderful-scripts/geoblocker-bash/releases

**3)** Extract all files included in the release into the same folder somewhere in your home directory and cd into that directory in your terminal

_<details><summary>4) Optional:</summary>_

- If intended use is whitelist and you want to install geoblocker-bash on a remote machine, you can run the check-ip-in-registry.sh script before installation to make sure that your public ip addresses are included in the ip list fetched from the internet registry.

_Example: (for US):_ ```bash check-ip-in-registry.sh -c US -i "8.8.8.8 8.8.4.4"``` _(if checking multiple ip addresses, use double quotes)_

- If intended use is blacklist and you know in advance some of the ip addresses you want to block, you can use check-ip-in-registry.sh script to verify that those ip addresses are included in the list fetched from the registry. The syntax is the same as above.

**Note**: check-ip-in-registry.sh has an additional pre-requisite: grepcidr. Install it with ```sudo apt install grepcidr```.

</details>

**5)** run ```sudo bash geoblocker-bash-install -m <whitelist|blacklist> -c <"country_codes">```

_<details><summary>Examples:</summary>_

- example (whitelist Germany and block all other countries): ```sudo bash geoblocker-bash-install -m whitelist -c DE```
- example (blacklist Germany and Netherlands and allow all other countries): ```sudo bash geoblocker-bash-install -m blacklist -c "DE NL"```

(when specifying multiple countries, put the list in double quotes)
</details>

**6)** That's it! By default, ip lists will be updated daily at 4am - you can verify that automatic updates work by running ```sudo cat /var/log/syslog | grep geoblocker-bash``` on the next day (change syslog path if necessary, according to the location assigned by your distro).

----------
**To check current geoblocking status:**
- run ```sudo geoblocker-bash status```

**To add or remove ip lists for countries:**

run ```sudo geoblocker-bash <action> [-c <"country_codes">]

where 'action' is either 'add' or 'remove'.

_<details><summary>Examples:</summary>_
- example (to add ip lists for Germany and Netherlands): ```sudo geoblocker-bash add -c "DE NL"```
- example (to remove the ip list for Germany): ```sudo geoblocker-bash remove -c DE```
</details>

 To disable/enable/change the autoupdate schedule, use the '-s' option followed by either cron schedule expression in doulbe quotes, or 'disable':
 ```sudo geoblocker-bash schedule -s <"cron_schdedule_expression">|disable```

 _<details><summary>Examples:</summary>_
- example (to enable and set periodic cron job schedule): ```sudo geoblocker-bash schedule -s "1 4 * * *"```
- example (to disable lists autoupdate): ```sudo geoblocker-bash schedule -s disable```
</details>
 
**To uninstall:**
- run ```sudo geoblocker-bash-uninstall```

**To switch mode (from whitelist to blacklist or the opposite):**
- simply re-install

## **Pre-requisites**:
(if a pre-requisite is missing, the -install script will tell you which)
- bash v4.0 or higher (should be included with any relatively modern linux distribution)
- Linux. Tested on Debian-like systems and occasionally on OpenWRT, should work on any distribution.
- iptables - firewall management utility (nftables support will likely get implemented later)
- standard (mostly GNU) utilities including awk, sed, grep, bc, comm, ps which are included with every server/desktop linux distro. For embedded (like OpenWRT), may require some of the GNU coreutils full (or less trimmed-down) versions and possibly additional packages.
- for persistence and autoupdate functionality, requires the cron service to be enabled

additional mandatory pre-requisites: ```ipset wget jq```
(will also work with curl instead of wget)

optional: the check-ip-in-registry.sh script requires grepcidr. install it with ```sudo apt install grepcidr```

## **Notes**
For some helpful notes about using this suite, read [NOTES.md](/NOTES.md).

## **In detail**
For more detailed description of each script, read [DETAILS.md](/DETAILS.md).

## **Data safety**
For notes about data safety (mostly intended for security nerds), read [DATASAFETY.md](/DATASAFETY.md).

## **Last but not least**

- I have put much work into this project. If you use it and like it, please consider giving it a star on Github.
- I would appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have an interesting idea or suggestion for improvement, you are welcome to suggest as well. You can use the "Discussions" and "Issues" tabs for that.
