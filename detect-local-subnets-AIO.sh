#!/bin/sh
# shellcheck disable=SC2181,SC2031,SC2030

# detect-local-subnets-AIO.sh

# Unix shell script which uses standard utilities to detect local area ipv4 and ipv6 subnets, regardless of the device it's running on (router or host)
# Some heuristics are employed which are likely to work on Linux but for other Unixes, testing is recommended

# by default, outputs all found local ip addresses, and aggregated subnets
# to output only aggregated subnets (and no other text), run with the '-s' argument
# to only check a specific family (inet or inet6), run with the '-f <family>' argument


#### Initial setup

#debug=true
export LC_ALL=C
me=$(basename "$0")

## Simple args parsing
args=""
for arg in "$@"; do
	if [ "$arg" = "-s" ]; then subnets_only="true"
	elif [ "$arg" = "-f" ]; then family_arg="check"
	elif [ "$family_arg" = "check" ]; then family_arg="$arg"
	else args="$args $arg"
	fi
done

set -- "$args"


## Functions

# converts given ip address into hex number
ip_to_hex() {
	ip="$1"
	family="$2"
	[ -z "$ip" ] && { echo "ip_to_hex(): Error: received an empty ip address." >&2; return 1; }
	[ -z "$family" ] && { echo "ip_to_hex(): Error: received an empty value for ip family." >&2; return 1; }

	case "$family" in
		inet )
			split_ip="$(printf "%s" "$ip" | tr '.' ' ')"
			for ip in $split_ip; do
				printf "%02x" "$ip"
			done
		;;
		inet6 )
			expand_ipv6 "$ip"
		;;
		* ) echo "ip_to_hex(): Error: invalid family '$family'" >&2; return 1 ;;
	esac
}

# expands given ipv6 address into hex number
expand_ipv6() {
	addr="$1"
	[ -z "$addr" ] && { echo "expand_ipv6(): Error: received an empty string." >&2; return 1; }

	# prepend 0 if we start with :
	printf "%s" "$addr" | grep "^:" >/dev/null 2>/dev/null && addr="0${addr}"

	# expand ::
	if printf "%s" "$addr" | grep "::" >/dev/null 2>/dev/null; then
		# count colons
		colons="$(printf "%s" "$addr" | tr -cd ':')"
		# repeat :0 for every missing colon
		expanded_zeroes="$(for i in $(seq $((9-${#colons})) ); do printf "%s" ':0'; done)";
		# replace '::'
		addr=$(printf "%s" "$addr" | sed "s/::/$expanded_zeroes/")
	fi

	# replace colons with whitespaces
	quads=$(printf "%s" "$addr" | tr ':' ' ')

	# pad with 0's and merge
	for quad in $quads; do
		printf "%04x" "0x$quad" || \
					{ echo "expand_ipv6(): Error: failed to convert quad '0x$quad'." >&2; return 1; }
	done
}

# returns a compressed ipv6 address in the format recommended by RFC5952
# expects a fully expanded and merged ipv6 address as input (no colons)
compress_ipv6 () {
	ip=""
	# add leading colon
	quads_merged="${1}"
	[ -z "$quads_merged" ] && { echo "compress_ipv6(): Error: received an empty string." >&2; return 1; }

	# split into whitespace-separated quads
	quads="$(printf "%s" "$quads_merged" | sed 's/.\{4\}/& /g')"
	# remove extra leading 0's in each quad, remove whitespaces, add colons
	for quad in $quads; do
		ip="${ip}$(printf "%x:" "0x$quad")" || \
					{ echo "compress_ipv6(): Error: failed to convert quad '0x$quad'." >&2; return 1; }
	done

	# remove trailing colon, add leading colon
	ip=":${ip%?}"

	# compress 0's across neighbor chunks
	for zero_chain in ":0:0:0:0:0:0:0:0" ":0:0:0:0:0:0:0" ":0:0:0:0:0:0" ":0:0:0:0:0" ":0:0:0:0" ":0:0:0" ":0:0"
	do
		case "$ip" in
			*$zero_chain* )
				ip="$(printf "%s" "$ip" | sed -e "s/$zero_chain/::/" -e 's/:::/::/')"
				break
		esac
	done

	# trim leading colon if it's not a double colon
	case "$ip" in
		::*) ;;
		:*) ip="${ip#:}"
	esac
	printf "%s" "$ip"
}

# formats merged hex number as an ipv4 or ipv6 address
format_ip() {
	ip_hex="$1"
	family="$2"
	[ -z "$ip_hex" ] && { echo "format_ip(): Error: received empty value instead of ip_hex." >&2; return 1; }
	[ -z "$family" ] && { echo "format_ip(): Error: received empty value for ip family." >&2; return 1; }
	case "$family" in
		inet )
			# split into 4 octets
			octets="$(printf "%s" "$ip_hex" | sed 's/.\{2\}/&\ /g')"
			# convert from hex to dec, remove spaces, add delimiting '.'
			ip=""
			for octet in $octets; do
				ip="${ip}$(printf "%d." 0x"$octet")" || { echo "format_ip(): Error: failed to convert octet '0x$octet' to decimal." >&2; return 1; }
			done
			# remove trailing '.'
			ip="${ip%?}"
			printf "%s" "$ip"
			return 0
		;;
		inet6 )
			# convert from expanded and merged number into compressed colon-delimited ip
			ip="$(compress_ipv6 "$ip_hex")" || return 1
			printf "%s" "$ip"
			return 0
		;;
		* ) echo "format_ip(): Error: invalid family '$family'" >&2; return 1
	esac
}

# generates a mask represented as a hex number
generate_mask()
{
	# CIDR bits
	maskbits="$1"

	# address length (32 bits for ipv4, 128 bits for ipv6)
	mask_len="$2"

	[ -z "$maskbits" ] && { echo "generate_mask(): Error: received empty value instead of mask bits." >&2; return 1; }
	[ -z "$mask_len" ] && { echo "generate_mask(): Error: received empty value instead of mask length." >&2; return 1; }

	mask_bytes=$((mask_len/8))

	mask="" bytes_done=0 i=0 sum=0 cur=128
	octets='' frac=''

	octets=$((maskbits / 8))
	frac=$((maskbits % 8))
	while [ ${octets} -gt 0 ]; do
		mask="${mask}ff"
		octets=$((octets - 1))
		bytes_done=$((bytes_done + 1))
	done

	if [ $bytes_done -lt $mask_bytes ]; then
		while [ $i -lt $frac ]; do
			sum=$((sum + cur))
			cur=$((cur / 2))
			i=$((i + 1))
		done
		mask="$mask$(printf "%02x" $sum)"
		bytes_done=$((bytes_done + 1))

		while [ $bytes_done -lt $mask_bytes ]; do
			mask="${mask}00"
			bytes_done=$((bytes_done + 1))
		done
	fi

	printf "%s\n" "$mask"
}


# validates an ipv4 or ipv6 address
# if 'ip route get' command is working correctly, validates the address through it
# then performs regex validation
validate_ip () {
	addr="$1"; addr_regex="$2"
	[ -z "$addr" ] && { echo "validate_ip(): Error:- received an empty ip address." >&2; return 1; }
	[ -z "$addr_regex" ] && { echo "validate_ip: Error: address regex has not been specified." >&2; return 1; }

	if [ -z "$ip_route_get_disable" ]; then
		# using the 'ip route get' command to put the address through kernel's validation
		# it normally returns 0 if the ip address is correct and it has a route, 1 if the address is invalid
		# 2 if validation successful but for some reason it doesn't want to check the route ('permission denied')
		for address in $addr; do
			ip route get "$address" >/dev/null 2>/dev/null; rv=$?
			[ $rv -eq 1 ] && { echo "validate_ip(): Error: ip address'$address' failed kernel validation." >&2; return 1; }
		done
	fi

	# regex validation
	printf "%s\n" "$addr" | tr ' ' "\n" | grep -E "^$addr_regex$" > /dev/null || \
		{ echo "validate_ip(): Error: failed to validate addresses '$addr' with regex." >&2; return 1; }
	return 0
}

# tests whether 'ip route get' command works for ip validation
test_ip_route_get() {
	family="$1"
	case "$family" in
		inet ) legal_addr="127.0.0.1"; illegal_addr="127.0.0.256" ;;
		inet6 ) legal_addr="::1"; illegal_addr=":a:1" ;;
		* ) echo "test_ip_route_get(): Error: invalid family '$family'" >&2; return 1 ;;
	esac
	legal_exp_addr="2001:4567:1212:00b2:0000:0000:0000:0000"
	illegal_exp_addr="2001:4567:1212:00b2:0T00:0000:0000:0000"
	rv_legal=0; rv_illegal=1; rv_legal_exp=0; rv_illegal_exp=1

	# test with a legal ip
	ip route get "$legal_addr" >/dev/null 2>/dev/null; [ $? -ne 0 ] && rv_legal=1
 	# test with an illegal ip
	ip route get "$illegal_addr" >/dev/null 2>/dev/null; [ $? -ne 1 ] && rv_illegal=0
	# test with a legal expanded ip
	ip route get "$legal_exp_addr" >/dev/null 2>/dev/null; rv=$?; if [ $rv -ne 0 ] && [ $rv -ne 2 ]; then rv_legal_exp=1; fi
	# test with an illegal expanded ip
	ip route get "$illegal_exp_addr" >/dev/null 2>/dev/null; [ $? -ne 1 ] && rv_illegal_exp=0

	# combine the results
	rv=$(( rv_legal || rv_legal_exp || ! rv_illegal || ! rv_illegal_exp ))

	if [ $rv -ne 0 ]; then
		echo "$me: Note: command 'ip route get' is not working as expected (or at all) on this device." >&2
		echo "$me: Disabling validation using the 'ip route get' command. Less reliable regex validation will be used instead." >&2
		echo >&2
		ip_route_get_disable=true
	fi
	unset legal_addr illegal_addr legal_exp_addr illegal_exp_addr rv_legal rv_illegal rv_legal_exp rv_illegal_exp
}

# performs bitwise AND on the ip address and the mask
# after optimizations, mostly just copies bits or generates 0's
bitwise_and() {
	ip_hex="$1"; mask_hex="$2"; maskbits="$3"; mask_len="$4"

	# chunk length in bits
	chunk_len=32

	# characters representing each chunk
	char_num=$((chunk_len / 4))

	bits_processed=0
	for i in $(seq 1 $(( mask_len / chunk_len )) ); do
		chunk_start=$((1 + (i - 1)*char_num))
		chunk_end=$((i*char_num))

		ip_chunk="$(printf "%s" "$ip_hex" | cut -c${chunk_start}-${chunk_end} )"

		bits_processed=$((bits_processed + chunk_len))

		# shellcheck disable=SC2086
		# skip calculation where we can simply copy the bits
		if [ $bits_processed -le $maskbits ]; then
			printf "%s" "$ip_chunk"
		else
			mask_chunk="$(printf "%s" "$mask_hex" | cut -c${chunk_start}-${chunk_end} )"
			ip_chunk=$(printf "%0${char_num}x" $(( 0x$ip_chunk & 0x$mask_chunk )) ) || \
				{ echo "bitwise_and(): Error: failed to calculate '0x$ip_chunk & 0x$mask_chunk'."; return 1; }
			printf "%s" "$ip_chunk"
		fi


		# shellcheck disable=SC2086
		# if we processed $maskbits bits already, no need to calculate further - just append 0's
		if [ $bits_processed -ge $maskbits ]; then
			bytes_missing=$(( (mask_len - bits_processed)/8 ))
			# shellcheck disable=SC2034
			# repeat 0 for every missing character
			for b in $(seq 1 $bytes_missing); do printf "%s" '00'; done
			break
		fi
	done
}


aggregate_subnets() {
	family="$1"; input_subnets="$2"
	# chunk length in bits
	chunk_len=32

	# characters representing each chunk
	char_num=$((chunk_len / 4))

	# remove duplicates from input, convert to lower case
	input_subnets="$(printf "%s" "$input_subnets" | tr ' ' '\n' | sort -u | tr '\n' ' ' | awk '{print tolower($0)}')"

	validate_ip "${input_subnets%/*}" "$addr_regex" || return 1

	for subnet in $input_subnets; do
		# get mask bits
		maskbits="$(printf "%s" "$subnet" | awk -F/ '{print $2}')"
		[ -z "$maskbits" ] && { echo "$me: Error: input '$subnet' has no mask bits." >&2; return 1; }

		# chop off mask bits
		input_addr="${subnet%/*}"

		# shellcheck disable=SC2086
		# validate mask bits
		if [ "$maskbits" -lt 8 ] || [ "$maskbits" -gt $mask_len ]; then echo "$me: Error: invalid $family mask bits '$maskbits'." >&2; return 1; fi

		# convert ip address to hex
		subnet_hex="$(ip_to_hex "$input_addr" "$family")" || return 1
		# prepend mask bits
		subnets_hex="$(printf "%s\n%s" "$maskbits/$subnet_hex" "$subnets_hex")"
	done

	# sort by mask bits, remove empty lines if any
	sorted_subnets_hex="$(printf "%s\n" "$subnets_hex" | sort -n | awk -F_ '$1{print $1}')"

	while [ -n "$sorted_subnets_hex" ]; do
		## trim the 1st (largest) subnet on the list to its mask bits

		# get the subnet
		subnet1="$(printf "%s" "$sorted_subnets_hex" | head -n 1)"
		[ "$debug" ] && echo >&2
		[ "$debug" ] && echo "processing subnet: $subnet1" >&2

		# get mask bits
		maskbits="${subnet1%/*}"
		# chop off mask bits
		ip="${subnet1#*/}"

		# shellcheck disable=SC2086
		# generate mask
		mask="$(generate_mask "$maskbits" $mask_len)" || return 1
		# shellcheck disable=SC2086
		# calculate ip & mask
		ip1="$(bitwise_and "$ip" "$mask" "$maskbits" $mask_len)" || return 1

		# remove current subnet from the list
		sorted_subnets_hex="$(printf "%s" "$sorted_subnets_hex" | tail -n +2)"
		remaining_subnets_hex="$sorted_subnets_hex"

		# iterate over all remaining subnets
		while [ -n "$remaining_subnets_hex" ]; do
			subnet2_hex=$(printf "%s" "$remaining_subnets_hex" | head -n 1)
			[ "$debug" ] && echo "comparing to subnet: '$subnet2_hex'" >&2

			if [ -n "$subnet2_hex" ]; then
				# chop off mask bits
				ip2="${subnet2_hex#*/}"

				ip2_differs=""; bytes_diff=0; bits_processed=0

				for i in $(seq 1 $(( mask_len / chunk_len )) ); do
					chunk_start=$((1 + (i - 1)*char_num))
					chunk_end=$((i*char_num))
					ip1_chunk="$(printf "%s" "$ip1" | cut -c${chunk_start}-${chunk_end} )"
					ip2_chunk="$(printf "%s" "$ip2" | cut -c${chunk_start}-${chunk_end} )"
					# [ "$debug" ] && echo "ip1_chunk: '$ip1_chunk', ip2_chunk: '$ip2_chunk'" >&2
					bits_processed=$((bits_processed + chunk_len))

					# shellcheck disable=SC2086
					# only calculate where necessary
					if [ $bits_processed -gt $maskbits ]; then
						# bitwise AND on a chunk of subnet2 and corresponding chunk of mask from subnet1
						mask_chunk="$(printf "%s" "$mask" | cut -c${chunk_start}-${chunk_end} )"

						ip2_chunk=$(printf "%0${char_num}x" $(( 0x$ip2_chunk & 0x$mask_chunk )) ) || \
							{ echo "$me: Error: failed to calculate '0x$ip2_chunk & 0x$mask_chunk'."; return 1; }
					fi

					# check for difference between current chunk in subnet1 and subnet2

					bytes_diff=$((0x$ip1_chunk - 0x$ip2_chunk)) || \
								{ echo "$me: Error: failed to calculate '0x$ip1_chunk - 0x$ip2_chunk'." >&2; return 1; }
					# if there is any difference, no need to calculate further
					if [ $bytes_diff -ne 0 ]; then
						[ "$debug" ] && echo "difference found" >&2
						ip2_differs=true; break
					fi

					# if we processed $maskbits bits already, no need to calculate further
					[ "$bits_processed" -ge "$maskbits" ] && break
				done

				# if no differences found, subnet2 is encapsulated in subnet1 - remove subnet2 from the list
				if [ -z "$ip2_differs" ]; then
					[ "$debug" ] && echo "No difference found" >&2
					sorted_subnets_hex="$(printf "%s\n" "$sorted_subnets_hex" | grep -vx "$subnet2_hex")"
				fi
			fi
			remaining_subnets_hex="$(printf "%s" "$remaining_subnets_hex" | tail -n +2)"
		done

		# format from hex back to ip
		ip1="$(format_ip "$ip1" "$family")" || return 1
		if validate_ip "$ip1" "$addr_regex"; then
			# append mask bits
			subnet1="$ip1/$maskbits"
			# add current subnet to resulting list
			res_subnets="${subnet1}${newline}${res_subnets}"
		else
			return 1
		fi
	done

	printf "%s\n" "$res_subnets"
}


get_local_subnets() {
# attempts to find local subnets, requires family in 1st arg

	family="$1"

	test_ip_route_get "$family" || return 1

	case "$family" in
		inet ) mask_len=32; addr_regex="$ipv4_regex"
			# get local interface names. filters by "scope link" because this should filter out WAN interfaces
			local_ifaces_ipv4="$(ip -f inet route show table local scope link | grep -i -v ' lo ' | \
				awk '{for(i=1; i<=NF; i++) if($i~/^dev$/) print $(i+1)}' | sort -u)"

			# get ipv4 addresses with mask bits, corresponding to local interfaces
			# awk prints the next string after 'inet'
			# grep validates the string as ipv4 address with mask bits
			local_addresses="$(
				for iface in $local_ifaces_ipv4; do
					ip -o -f inet addr show "$iface" | \
					awk '{for(i=1; i<=NF; i++) if($i~/^inet$/) print $(i+1)}' | grep -E "^$subnet_regex_ipv4$"
				done
			)"
		;;
		inet6 ) mask_len=128; addr_regex="$ipv6_regex"
			# get local ipv6 addresses with mask bits
			# awk prints the next string after 'inet6'
			# 1st grep filters for ULA (unique local addresses with prefix 'fdxx') and link-nocal addresses (fe80::)
			# 2nd grep validates the string as ipv6 address with mask bits
			local_addresses="$(ip -o -f inet6 addr show | awk '{for(i=1; i<=NF; i++) if($i~/^inet6$/) print $(i+1)}' | \
				grep -E -i '^fd[0-9a-f]{0,2}:|^fe80:' | grep -E -i "^$subnet_regex_ipv6$")"
		;;
		* ) echo "get_local_subnets(): invalid family '$family'." >&2; return 1 ;;
	esac

	[ -z "$subnets_only" ] && {
		echo "Local $family addresses:"
		echo "$local_addresses"
		echo
	}

	local_subnets="$(aggregate_subnets "$family" "$local_addresses")"; rv1=$?

	# removes extra whitespaces, converts to newline-delimited list
	local_subnets="$(printf "%s" "$local_subnets" | awk '{$1=$1};1' | tr ' ' '\n')"

	if [ $rv1 -eq 0 ]; then
		[ -z "$subnets_only" ] && echo "Local $family subnets (aggregated):"
		if [ -n "$local_subnets" ]; then printf "%s\n" "$local_subnets"; else echo "None found."; fi
	else
		echo "Error detecting $family subnets." >&2
	fi
	[ -z "$subnets_only" ] && echo

	return $rv1
}


## Constants
newline='
'
ipv4_regex='((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])'
ipv6_regex='([0-9a-f]{0,4}:){1,7}[0-9a-f]{0,4}:?'
maskbits_regex_ipv6='(12[0-8]|((1[0-1]|[1-9])[0-9])|[8-9])'
maskbits_regex_ipv4='(3[0-2]|([1-2][0-9])|[8-9])'
subnet_regex_ipv4="${ipv4_regex}/${maskbits_regex_ipv4}"
subnet_regex_ipv6="${ipv6_regex}/${maskbits_regex_ipv6}"


## Checks

# check dependencies
! command -v awk >/dev/null || ! command -v sed >/dev/null || ! command -v tr >/dev/null || \
! command -v grep >/dev/null || ! command -v ip >/dev/null || ! command -v cut >/dev/null && \
	{ echo "$me: Error: missing dependencies, can not proceed" >&2; exit 1; }

# test 'grep -E'
rv=0; rv1=0; rv2=0
printf "%s" "32" | grep -E "^${maskbits_regex_ipv4}$" > /dev/null; rv1=$?
printf "%s" "0" | grep -E "^${maskbits_regex_ipv4}$" > /dev/null; rv2=$?
rv=$((rv1 || ! rv2))
[ "$rv" -ne 0 ] && { echo "$me: Error: 'grep -E' command is not working correctly on this machine." >&2; exit 1; }
unset rv rv1 rv2


## Main

if [ -n "$family_arg" ]; then families="$(printf "%s" "$family_arg" | awk '{print tolower($0)}')"; else families="inet inet6"; fi

rv_global=0
for family in $families; do
	get_local_subnets "$family"; rv_global=$((rv_global + $?))
done

exit $rv_global
