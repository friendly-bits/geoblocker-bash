## **OpenWRT installation, issues and possible solutions**
- I tested this suite on my OpenWRT WNDR3700-v2 router, running OpenWRT SFE r15568-b3eccbca7c, which is a snapshot from 2020, modified with patches from the SFE project.

More info about SFE patches here:
https://github.com/gwlim/openwrt-sfe-flowoffload-ath79

- This particular router has 128MB of RAM (which I upgraded from 64MB) and a slightly hacked firmware to support this RAM capacity.
- This router is quite old, so it has only 8MB of flash storage, however it turned out to be sufficient to install the additional packages. After installation and removal of the downloaded packages, I still have 40% of space to spare.

- To make the suite work on this router, I had to install some utilities that were missing, and upgrade some utilites which were installed in a trimmed-down version which wouldn't support the actions that the scripts need to perform.
- To do that, considering I'm using an older OpenWRT release, I navigated to the archive of the 21.02.0 official OpenWRT release located at

https://archive.openwrt.org/releases/21.02.0/packages/mips_24kc/packages/

(_note_ that these are packages for the specific architecture of my router but your router _likely_ has a similar package archive, as long as it's supported by OpenWRT)

(if you are using a modern unmodified version of OpenWRT, probably you can download and install directly through the LUCI interface without having to care about the specific versions)

Then I downloaded (using wget) and installed the following packages - these required to change the address from https to http because the trimmed-down wget didnt' support SSL.
- librt_1.2.4-4
- wget-ssl_1.21.1-1

(after that, I could finally download with wget from the https:// website)

- terminfo_6.2.-3
- libreadline8_8.1-1
- libncurses6 (6.4-2)
- bash_5.1-2 (bash 5.1.16 refused to work for me, probably because it's linked against the newer libraries)
- bc_1.06.95-1
- procps-ng_3.3.16-3
- procps-ng-ps_3.3.16-3
- coreutils-sleep_8.32-6
- coreutils-unlink_8.32-6
- grep_3.6-1
- librt_1.2.4-4
- jq_1.6-1
- (i _think_ I also had to install sed_4.8-3)

All that was downloaded through the commmand-line interface and installed with the opkg package manager.

I also had to make some slight modification to the code (now merged into the main branch) to work around limitations in other built-in utilites.

## Issues
After that, the suite installs and works as expected, except:
1) the persistence (reboot) cron job doesnt work with the trimmed-down version of crontab which OpenWRT ships (at least in the 2021.02 older verson) because it doesn't support the '@reboot' timing option. Installing the package from the archive reporistory didn't fix this issue.
2) the /var/lib folder which is used by the suite to store data (such as downloaded ip lists, firewall state backups and the cca2.list file which stores valid country codes, used for user input validation) is mapped to the memory and so doesn't persist across reboots, so the suite doesn't work after a reboot.
3) I had to add the /var/local/bin directory to my $PATH variable (somehow that stuck across reboots) in order to be able to call the installed scripts directly. Perhaps can be mitigated by installing the scripts into a different directory which is in $PATH to begin with.
4) The check-ip-in-registry.sh script (which is not an essential part of the suite) can't be used at all (at least on this version) because it requires the grepcidr utility which is not present in the archive and I'm too lazy to make a buildchain for compiling it from source.
5) Using the ssl-disabled version of wget is a nuicance, although not a major one.

## Solutions:
1) should be a _relatively_ easy to fix since I know that OpenWRT has some facility for firewall persistence, I just don't know how it's implemented and what's its command-line API. Perhaps someone with this knowledge could suggest a modification required for integration which would replace the cron job.
2) should be easy to fix by storing data in a persistent location (such as in /etc/ ??). If automatic backups are an issue because of storage space limitation, that function can be disaled during installation (or completely disabled in a specialized embedded version of the suite).
3) should be (probably) an easy fix
4) To fix check_ip_in_registry.sh not working, grepcidr needs to be included in the OpenWRT repositories. But then again, it's just a nice pre-install perk, not an essential part of the suite.
5) For a manual installation, the proposed fix is include ssl-enabled wget in the distribution (which may have already happened in the newer version?) I'm pretty sure that ssl-enabled wget (or curl) are also required for ip lists fetching from the regional registries (both for initial install and for auto-updates).

To sum it up, a few rather minor modifications are required for the suite to work on OpenWRT but currently I don't really need it to be running on my router so I'm not going to spend time figuring it out. If someone in the OpenWRT community wants this to work, you are welcome to provide me the info required and I'll modify the code and possibly make an OpenWRT-special version of the suite.