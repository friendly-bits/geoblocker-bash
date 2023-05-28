#!/bin/bash

# check_ip_in_ripe.sh
#
#
# Checks whether a given IP address is belongs to a subnet found in RIPE's records for a given country
#
# Based on a prior script by mivk, called get-ripe-ips.
#
# Fetches ipv4 subnets for a given country from RIPE
## See https://stat.ripe.net/docs/data_api
#
# Parses and compiles them into a plain list, and saves to a temporary file
# Goes through the fetched list from RIPE and checks whether the specified IP adress belongs to one of the subnets
#
# Requires jq - JSON processor, and grepcidr - utility that filters IPv4 and IPv6 addresses matching CIDR patterns.
## On Debian and derivatives, if you are missing jq then install both with this command:
## apt install jq grepcidr

me=$(basename "$0")

#### USAGE

usage() {
    cat <<EOF

This script:
1) Fetches ipv4 subnets for a given country from RIPE
2) Parses and compiles them into a plain list, and saves to a temporary file
3) Goes through the fetched list from RIPE and checks whether the specified IP adress belongs to one of the subnets
Requires "jq" and "grepcidr" utility. If you are on Debian or derivatives, install both with "apt install jq grepcidr".

    Usage: $me -c country -i ip [-d] [-h]

    Options:
    -c tld    : tld/country code
    -i ip     : ipv4 address you want to check

    -d        : Debug
    -h        : This help

EOF
}

#### Functions

die() {
	echo "$@" 1>&2
	echo ""
#	logger -t geoblocker_bash-fetch "$@"
	exit 1
}

validate_ipv4() {
## attempts to make sure that the argument is a valid ipv4 address

# regex compiled from 2 suggestions found here:
# https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
	ip_regex='^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}'
	mask_regex='(/([01]?\d\d?|2[0-4]\d|25[0-5]))$'
	if [ "$2" = "subnet" ]; then
		regex_pattern="${ipregex}${mask_regex}"
	else
		regex_pattern="${ipregex}\$"
	fi
	echo "$1" | grep -P $regex_pattern; rv=$?
	# outputs grep result, effectively filtering out invalid subnets

	return $rv
}

#### Parse arguments

while getopts "c:i:dh" opt; do
	case $opt in
	c) country=$OPTARG;;
	i) userip=$OPTARG;;
	d) debug=true;;
	h) usage; exit 0;;
	\?) usage; exit 1;;
	esac
done
shift $((OPTIND -1))


#### Initialize variables
ripe_url="https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix&resource="
min_size_ipv4=5000  # default is 5000 bytes


#### Checks

if [ -z "$country" ]; then
	usage
	echo ""
	err="Specify country with \"-c <country>\"!"
	die "$err"
fi

# make sure that we have an ip address to check
if [ -z "$userip" ]; then
	usage
	err="Specify the ip address you want to check with \"-i <ip>\"!"
	echo ""
	die "$err"
fi

url="$ripe_url$country"

# use curl or wget, depending on which one we find
curl_or_wget=$(if hash curl 2>/dev/null; then echo "curl -s"; elif hash wget 2>/dev/null; then echo "wget -qO-"; fi);
if [ -z "$curl_or_wget" ]; then
	err="Error: Neither curl nor wget found. Cannot download data. Exiting."
	die "$err"
fi

# check that we have jq
if ! command -v jq &> /dev/null; then
	err="Error: Cannot find the jq Json processor. Install it with 'apt install jq' or similar. Exiting"
	die "$err"
fi

# check that we have grepcidr
if ! command -v jq &> /dev/null; then
	err="Error: Cannot find grepcidr. Install it with 'apt install grepcidr' or similar. Exiting"
	die "$err"
fi


#### Main

echo ""

# validate the specified ip address
validate_ipv4 "$userip" &>/dev/null; rv=$?
if [ $rv -ne 0 ]; then
# if validation fails
	err="\"$userip\" does not appear to be a valid ipv4 address. Exiting."
	echo ""
	die "$err"
fi


# Change last ipv4 octet to 0

ripe_list=$(mktemp "/tmp/ripe-$country-XXXX.json")

echo -n "Fetching iplist from RIPE... "
[ $debug ] && echo "Debug: Trying: $curl_or_wget '$url'" >&2

$curl_or_wget "$url" > "$ripe_list"
rv=$?

if [ $rv -ne 0 ]; then
	echo "Failed."
	err="Error $rv trying to run $curl_or_wget $url. Exiting."
	die "$err"
fi


status=$(jq -r '.status' $ripe_list)
if [ ! "$status" = "ok" ]; then
	ripe_msg=$(jq -r -c '.messages' $ripe_list)
	echo "Failed."
	echo "Error: RIPE replied with status = '$status'."
	echo "The requested url was '$url'"
	echo "and the messages in their reply were: '$ripe_msg'"
	err="Error: could not fetch ip list from RIPE. Exiting"
	die "$err"
fi

echo "Success."

family="ipv4"
## only parsing the ipv4 section at this time

parsed_file=$(mktemp "/tmp/parsed-$country-XXXX.plain")

min_size="$min_size_ipv4"

errorcount=0
subnetcount=0

echo -n "Parsing and validating downloaded subnets... "
for testsubnet in `jq -r ".data.resources.$family | .[]" "$ripe_list"`; do
	validate_ipv4 "$testsubnet" "subnet" >> "$parsed_file"; rv=$?
	errorcount=$(($errorcount + $rv))
	subnetcount=$(($subnetcount + 1))
done

if [ $errorcount -ne 0 ]; then
	echo "Issues found."
	echo "Warning: encountered $errorcount errors while validating subnets in the fetched list." >&2
	echo "Invalid subnets removed from the list." >&2
else
	echo "Success."
fi

echo "Total validated ip's: $(($subnetcount - $errorcount))"
echo ""

### Check for minimum size

size=$(stat --printf %s "$parsed_file")

[ $debug ] && echo "Debug: Parsed list size: $size"

if [ ! "$size" -ge "$min_size" ]; then
	err="Error: fetched file $parsed_file size of $size bytes is smaller than minimum $min_size bytes. Probably a download error. Exiting."
	rm "$parsed_file" &>/dev/null
	rm "$ripe_list"
	die "$err"
fi

echo "Checking if $userip belongs to a subnet in the list..."

echo "$userip" | grepcidr -f "$parsed_file" &>/dev/null; rv=$?

echo ""
echo "Result:"
if [ $rv -eq 0 ]; then
	echo "NOTE: $userip *belongs* to a subnet in RIPE's list for country \"$country\"."
else
	echo "NOTE: $userip *does not* belong to a subnet in RIPE's list for country \"$country\"."
fi
echo ""

# clean up temp files
rm "$ripe_list"
rm "$parsed_file"
echo "Done."
echo ""
exit $rv
