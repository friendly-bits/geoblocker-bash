#!/bin/bash

# check_ip_in_ripe.sh
#
#
# Checks whether a given IP address belongs to a subnet found in RIPE's records for a given country
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
	exit 1
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
url="$ripe_url$country"
min_subnets_num="300"

# using Perl regex syntax because grep is faster with it than with native grep syntax
# regex compiled from 2 suggestions found here:
# https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
ip_regex='^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}'
mask_regex='(/([01]?\d\d?|2[0-4]\d|25[0-5]))$'
subnet_regex="${ip_regex}${mask_regex}"


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

# use curl or wget, depending on which one we find
if hash curl 2>/dev/null; then
	curl_or_wget="curl -s --retry 4 --fail-early --connect-timeout 7"
elif hash wget 2>/dev/null; then
	curl_or_wget="wget --tries=4 --timeout=7 -qO-"
fi

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
if ! command -v grepcidr &> /dev/null; then
	err="Error: Cannot find grepcidr. Install it with 'apt install grepcidr' or similar. Exiting"
	die "$err"
fi


#### Main

echo ""


# validate the specified ip address
validated_ipv4=$(echo "$userip" | grep -P "$ip_regex\$")

# if $validated_ipv4 is empty then validation failed
if [ -z "$validated_ipv4" ]; then
	err="\"$userip\" does not appear to be a valid ipv4 address. Exiting."
	echo ""
	die "$err"
fi

fetched_file=$(mktemp "/tmp/fetched-$country-XXXX.json")

echo -n "Fetching iplist from RIPE... "
[ $debug ] && echo "Debug: Trying: $curl_or_wget '$url'" >&2

$curl_or_wget "$url" > "$fetched_file"
rv=$?

if [ $rv -ne 0 ]; then
	echo "Failed."
	err="Error $rv trying to run $curl_or_wget $url. Exiting."
	rm "$fetched_file" &>/dev/null
	die "$err"
fi


status=$(jq -r '.status' "$fetched_file")
if [ ! "$status" = "ok" ]; then
	ripe_msg=$(jq -r -c '.messages' "$fetched_file")
	echo "Failed."
	echo "RIPE message: '$ripe_msg'."
	echo "Requested url was: '$url'"
	err="Error: could not fetch ip list from RIPE. Exiting"
	rm "$fetched_file" &>/dev/null
	die "$err"
fi

echo "Success."

## only parsing the ipv4 section at this time
family="ipv4"

parsed_file=$(mktemp "/tmp/parsed-$country-XXXX.list")
validated_file=$(mktemp "/tmp/validated-$country-XXXX.list")

echo -n "Parsing downloaded subnets... "
jq -r ".data.resources.$family | .[]" "$fetched_file" > "$parsed_file"

parsed_subnet_cnt=$(wc -l < "$parsed_file")
if [ "$parsed_subnet_cnt" -ge "$min_subnets_num" ]; then
	echo "Success."
else
	err="Error: parsed subnets count is less than $min_subnets_num. Probably a download error. Exiting."
	rm "$parsed_file" &>/dev/null
	rm "$validated_file" &>/dev/null
	rm "$fetched_file"
	die "$err"
fi

echo -n "Validating downloaded subnets... "
grep -P "$subnet_regex" "$parsed_file" > "$validated_file"

validated_subnet_cnt=$(wc -l < "$validated_file")

errorcount=$((parsed_subnet_cnt - validated_subnet_cnt))

if [ $errorcount -ne 0 ]; then
	echo "Issues found."
	echo "Warning: $errorcount subnets failed validation." >&2
	echo "Invalid subnets removed from the list." >&2
else
	if [ "$validated_subnet_cnt" -ge "$min_subnets_num" ]; then
		echo "Success."
	else
		err="Error: validated subnets count is less than $min_subnets_num. Probably a download error. Exiting."
		rm "$parsed_file" &>/dev/null
		rm "$validated_file" &>/dev/null
		rm "$fetched_file"
		die "$err"
	fi
fi

echo "Total validated subnets: $validated_subnet_cnt"
echo ""

echo "Checking $userip..."

echo "$userip" | grepcidr -f "$validated_file" &>/dev/null; rv=$?

if [ $rv -eq 0 ]; then
	echo "Result: $userip *BELONGS* to a subnet in RIPE's list for country \"$country\"."
else
	echo "Result: $userip *DOES NOT BELONG* to a subnet in RIPE's list for country \"$country\"."
fi
echo ""

# clean up temp files
rm "$fetched_file"
rm "$parsed_file"
rm "$validated_file"
echo "Done."
echo ""
exit $rv
