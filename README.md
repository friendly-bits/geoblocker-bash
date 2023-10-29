# geoblocker-bash
Geoip blocker for Linux focusing on reliability, compatibility, efficiency and ease of use. Suite of Bash scripts which utilizes the 'iptables' firewall management utility (nftables support will get implemented eventually).

Should work on every modern'ish desktop/server Linux distribution, doesn't matter which hardware. Works on embedded, as long as it has the pre-requisites. For OpenWRT and similar distributions, read the [OPENWRT.md](/OPENWRT.md) file.

Currently only supports ipv4 but ipv6 support is likely coming (you can speed it up by opening an issue requesting it).
 
## Features
_(for installation instructions, skip to the [**Installation**](#Installation) section)_

* Basic functionality is automatic download of complete ipv4 subnet lists for user-specified countries, then using these lists to create either a whitelist or a blacklist (selected during installation) in the firewall. Besides the basics, there are additional useful features (continue reading to find out which).

* ip lists are fetched from the official regional registries (selected automatically based on the country). Currently supports ARIN (American Registry for Internet Numbers) and RIPE (Regional Internet registry for Europe, the Middle East and parts of Central Asia). RIPE stores ip lists for countries in other regions as well, so currently this can be used for any country in the world.

* All configuration changes required for geoblocking to work are automatically applied to the firewall during installation.

* Implements optional (enabled by default) persistence of geoblocking across system reboots and automatic updates of the ip lists.

**Reliability**:
- Does not depend on 3rd parties for supplying the ip lists (while most other similar projects do), which has reliability and security implications.
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
- The scripts perform all heavy-lifting operations (such as parsing and validating ip lists, or processing backups) in memory to avoid unnecessary storage device access. So they should be plenty fast even with a slow storage device. At the expense of some memory (which only matters for embedded systems - in my testing, OpenWRT router with 128MB of memory handles this easily).
- Scripts are only active for a short time when invoked either directly by the user or by a cron job (once after a reboot and then periodically for an auto-update - both cron jobs are optional and enabled by default).

</details>

**Ease of use**:
- Detailed installation and usage guides (check the [**Installation**](#Installation) and [**Usage**](#Usage) sections)
- Installation is easy, doesn't require many complex command line arguments and normally takes a few seconds.
- After installation (provided you have all the [**Pre-requisites**](#Pre-requisites)), geoblocking will be already active for the specified countries and you don't have to do anything else for it to work.

<details><summary>Read more:</summary>

- Has only 2 non-standard dependencies (_ipset_ and _jq_) which should be available from any modern'ish Linux distribution's package manager.
- Comes with an *uninstall script. Uninstallation normally takes about a second. It completely removes the suite, removes geoblocking firewall rules and restores pre-install firewall policies. No restart is required.
- Sane settings are applied during installation by default, but also lots of command-line options for advanced users or for special corner cases.
- Pre-installation, provides a utility _(check-ip-in-registry.sh)_ to check whether specific ip addresses you might want to blacklist or whitelist are indeed included in the list fetched from the registry.
- Post-installation, provides a utility (symlinked to _'geoblocker-bash'_) for the user to manage and change geoblocking config (adding or removing country codes, changing the cron schedule etc).
- Post-installation, provides a command _('geoblocker-bash status')_ to check geoblocking rules, active ipsets, autoupdate and persistence cron jobs, and whether there are any issues.
- All that is well documented, read **INSTALLAION**, **NOTES** and **DETAILS** sections for more info.
- Lots of comments in the code, in case you want to change something in it or learn how the scripts are working.
- Besides extensive documentation, each script displays detailed 'usage' info when executed with the '-h' option.
- Validates all user input, so if you make a mistake, it is unlikely that you break something - the scripts will just say that the input makes no sense and usually tell you what's wrong with it.
</details>

**Compatibility**:
- Since the code is written in Bash, the suite is basically compatible with everything Linux (as long as it has the pre-requisites)

<details> <summary>Read more:</summary>
 
 - Embedded hardware-oriented distributions (like OpenWRT) generally tend to use trimmed-down versions of standard utilities by default, so these may need to upgrade to full versions or at least less-trimmed-down versions of some utilities. For more info on OpenWRT compatibiliy, read the [OPENWRT.md](/OPENWRT.md) file.
 - Some (mostly commercial) distros have their own firewall management utilities and even implement their own firewall persistence across reboots. The suite should work on these, too, provided they use iptables as the back-end, but you probably should disable the cron-based persistence solution (more info in the [Pre-requisites](#Pre-requisites) section).
</details>

## **Installation**

_Recommended to read the [NOTES.md](/NOTES.md) file._

**To install:**

**1)** Install pre-requisites. Use your distro's package manager to install ```ipset``` and ```jq``` (also needs ```wget``` or ```curl``` but you probably have one of these installed already). For examples for most popular distros, check out the [Pre-requisites](#Pre-requisites) section.

**2)** Download the latest realease: https://github.com/blunderful-scripts/geoblocker-bash/releases

**3)** Extract all files included in the release into the same folder somewhere in your home directory and ```cd``` into that directory in your terminal

_<details><summary>4) Optional:</summary>_

- If intended use is whitelist and you want to install geoblocker-bash on a remote machine, you can run the ```check-ip-in-registry.sh``` script before Installation to make sure that your public ip addresses are included in the ip list fetched from the internet registry.

_Example: (for US):_ ```bash check-ip-in-registry.sh -c US -i "8.8.8.8 8.8.4.4"``` _(if checking multiple ip addresses, use double quotes)_

- If intended use is blacklist and you know in advance some of the ip addresses you want to block, you can use check-ip-in-registry.sh script to verify that those ip addresses are included in the list fetched from the registry. The syntax is the same as above.

**Note**: check-ip-in-registry.sh has an additional pre-requisite: grepcidr. Install it with your distro's package manager.

</details>

**5)** run ```sudo bash geoblocker-bash-install -m <whitelist|blacklist> -c <"country_codes">```. The *install script will gracefully fail if it detects that you are missing some pre-requisites and tell you which.
_<details><summary>Examples:</summary>_

- example (whitelist Germany and block all other countries): ```sudo bash geoblocker-bash-install -m whitelist -c DE```
- example (blacklist Germany and Netherlands and allow all other countries): ```sudo bash geoblocker-bash-install -m blacklist -c "DE NL"```

(when specifying multiple countries, put the list in double quotes)
</details>

- **NOTE**: If your distro (or you) have enabled automatic iptables and ipsets persistence, you can skip the built-in cron-based persistence feature by adding the ```-n``` (for no-persistence) option when running the -install script.

<details><summary>**Verifying persistence**</summary>

Generally automatic persistence of iptables and ipsets is not enabled for Debian or Ubuntu-based desktop distros by default (and probalby for most others). This is why the suite creates a cron job to re-apply geoblocking upon reboot. The easiest way to make sure whether your particular distro has firewall persistence enabled without the cron job is running the -install script with the ```-n``` option (for no-persistence) like so:

```sudo bash geoblocker-bash-install -m <whitelist|blacklist> -c <"country_codes"> -n```

then rebooting the computer, waiting 30 seconds and then running ```sudo geoblocker-bash status```. If it complains about incoherency between the config file and the firewall state then your distro and you have not enabled persistence. In that case, install again without the ```-n``` option to enable cron-based persistence, reboot again and test again (should not complain now). Installation normally takes just a few seconds, so it's not a big deal.

</details>

**6)** That's it! By default, ip lists will be updated daily at 4am - you can verify that automatic updates work by running ```sudo cat /var/log/syslog | grep geoblocker-bash``` on the next day (change syslog path if necessary, according to the location assigned by your distro).

## **Usage**
Generally, once the installation completes, you don't have to do anything else for geoblocking to work. But I implemented some tools to change geoblocking settings and check geoblocking state.

**To check current geoblocking status:** run ```sudo geoblocker-bash status```

**To add or remove ip lists for countries:** run ```sudo geoblocker-bash <action> [-c <"country_codes">]```

where 'action' is either ```add``` or ```remove```.

_<details><summary>Examples:</summary>_
- example (to add ip lists for Germany and Netherlands): ```sudo geoblocker-bash add -c "DE NL"```
- example (to remove the ip list for Germany): ```sudo geoblocker-bash remove -c DE```
</details>

 **To enable or change the autoupdate schedule**, use the ```-s``` option followed by the cron schedule expression in doulbe quotes:

```sudo geoblocker-bash schedule -s <"cron_schdedule_expression">```

 _<details><summary>Example</summary>_

```sudo geoblocker-bash schedule -s "1 4 * * *"```

</details>

**To disable ip lists autoupdates**, use the '-s' option followed by the word ```disable```: ```sudo geoblocker-bash schedule -s disable```
 
**To uninstall:** run ```sudo geoblocker-bash-uninstall```

**To switch mode (from whitelist to blacklist or the opposite):** simply re-install

## **Pre-requisites**:
(if a pre-requisite is missing, the -install script will tell you which)
- bash v4.0 or higher (should be included with any relatively modern linux distribution)
- Linux. Tested on Debian-like systems and occasionally on [OPENWRT](/OPENWRT.md), should work on any desktop/server distribution and possibly on some embedded distributions (pleasee let me know if you have a particular one you want to use it on).
- iptables - firewall management utility (nftables support will likely get implemented later)
- standard (mostly GNU) utilities including awk, sed, grep, bc, comm, ps which are included with every server/desktop linux distro. For embedded (like OpenWRT), may require some of the GNU coreutils full (or less trimmed-down) versions and possibly additional packages.
- for persistence and autoupdate functionality, requires the cron service to be enabled

additional mandatory pre-requisites: ```ipset jq``` (also needs ```wget``` or ```curl``` but you probably have one of these installed already)

_<details><summary>Examples for popular distributions</summary>_

**Debian, Ubuntu, Linux Mint** and any other Debian/Ubuntu derivative: ```sudo apt install ipset jq```

**Arch**: (you need to have the Extra repository enabled) ```sudo pacman -S ipset jq```

**Fedora**: Update the database with ```sudo dnf makecache --refresh```. Next, install the dependencies with ```sudo dnf -y install ipset jq```

**OpenSUSE**: you may (?) need to add repositories to install jq and ipset as explained here:

https://software.opensuse.org/download/package?package=jq&project=utilities
https://software.opensuse.org/download/package?package=ipset&project=security%3Anetfilter

then run ```sudo zypper install ipset jq```

(if you have verified information, please le me know)


**RHEL/CentOS**: you need the EPEL Repository for ```jq```. I'm not an expert on RHEL and CentOS, so you'll need to figure some things out by yourself (and please let me know if you do so I update this guide), including how to add that repository to your specific OS version. Once the repo is added, run ```sudo yum update -y```. Next, install the dependencies with ```sudo yum install jq ipset```. I suspect it will then work as is but you may (?) need to also make some config changes, epsecially if using a specialized firewall management utility such as 'scf' which may preserve the iptables and ipsets between reboots (so you would probably want to disable the suite's cron-based persistence feature). Anyway, I'd recommend after installing the suite, reboot your computer, wait 30 seconds and then run ```sudo geoblocker-bash status``` and see if it reports any issues.

**OpenWRT**: Read the [OPENWRT.md](/OPENWRT.md) file.
</details>


**Optional**: the _check-ip-in-registry.sh_ script requires grepcidr. install it with ```sudo apt install grepcidr``` on Debian and derivatives. For other distros, look it up.

## **Notes**
For some helpful notes about using this suite, read [NOTES.md](/NOTES.md).

## **In detail**
For more detailed description of each script, read [DETAILS.md](/DETAILS.md).

## **Data safety**
For notes about data safety (mostly intended for security nerds), read [DATASAFETY.md](/DATASAFETY.md).

## **OpenWRT**
For compatibility with OpenWRT, read [OPENWRT.md](/OPENWRT.md). Help needed!

## **Last but not least**

- I have put much work into this project. If you use it and like it, please consider giving it a star on Github.
- I would appreciate a report of whether it works or doesn't work on your system (please specify which), or if you find a bug. If you have an interesting idea or suggestion for improvement, you are welcome to suggest as well. You can use the "Discussions" and "Issues" tabs for that.
