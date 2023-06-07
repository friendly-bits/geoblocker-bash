#!/bin/bash

# validate_cron_schedule.sh

#    Checks a cron schedule expression to ensure that it's formatted properly.  Expects standard cron notation of
#       min hr dom mon dow
#    where min is 0-59, hr 0-23, dom is 1-31, mon is 1-12 (or names) and dow is 0-7 (or names).  Fields can have ranges (a-e), lists
#    separated by commas (a,c,z), or an asterisk. Note that the step value notation of Vixie cron is not supported (e.g., 2-6/2).
#
#    Based on prior "verifycron" script circulating on the internets
#    This is a simplified version, adapted to receive one cron schedule expression in an argument.

me=$(basename "$0")

#### USAGE

usage() {
    cat <<EOF

    Checks a cron schedule expression to ensure that it's formatted properly.  Expects standard cron notation of
       min hr dom mon dow
    where min is 0-59, hr 0-23, dom is 1-31, mon is 1-12 (or names) and dow is 0-7 (or names).  Fields can have ranges (a-e), lists
    separated by commas (a,c,z), or an asterisk. Note that the step value notation of Vixie cron is not supported (e.g., 2-6/2).

    Usage: $me -x "expression" [-h]

    Options:
    -x "expression"    : crontab schedule expression ***in double quotes***
    				example: "0 4 * * 6"
				format: min hr dom mon dow
    -h                 : This help

EOF
}

#### Parse arguments

while getopts "x:h" opt; do
	case $opt in
	x) sourceline=$OPTARG;;
	h) usage; exit 0;;
	\?) usage; exit 1;;
	esac
done
shift $((OPTIND -1))


#### Functions

validateNum() {
# returns 0 if valid, 1 if not. Specify number, minvalue and maxvalue as args
	num="$1"; min="$2"; max="$3"
	if [ -z "$num" ]; then
		return 1
	elif [ "$num" = '*' ] ; then
		return 0
	elif [ -n "$(echo $num | sed 's/[[:digit:]]//g')" ] ; then
		return 1
	elif [ "$num" -lt "$min" ] || [ "$num" -gt "$max" ] ; then
		return 1
	else
		return 0
	fi
}

validateDay() {
# returns 0 if a valid dayname, 1 otherwise
	case $(echo "$1" | tr '[:upper:]' '[:lower:]') in
		sun|mon|tue|wed|thu|fri|sat) return 0 ;;
		'*') return 0    ;; # special case - it's an "*"
		*) return 1 ;;
	esac
}

validateMon() {
# returns 0 if a valid month name, 1 otherwise
	case $(echo "$1" | tr '[:upper:]' '[:lower:]') in
		jan|feb|mar|apr|may|jun|jul|aug) return 0;;
		sep|oct|nov|dec) return 0;;
		'*') return 0;; # special case, it's an "*"
		*) return 1;;
	esac
}

validateName() {
# returns 0 if 2nd argument is a valid value of corresponding category (month or day of week)
# returns 1 otherwise
# the category is provided in the 1st argument
	fieldCategory="$1"
	fieldvalue="$2"
	case "$fieldCategory" in
		"month") validateMon "$fieldvalue"; return $?;;
		"day of week") validateDay "$fieldvalue"; return $?;;
		*) return 1;;
	esac
}



validateField() {
# validates a field (part) of the cron schedule (either month, day of month, day of week, hour or minute)
# supports month (Jan-Dec) and day-of-week (Sun-Sat) names
# supports comma-separated values (example: 1,10,16 for hours) and dash-separated ranges of values (example: Wed-Sat)
# returns 0 if the string passes validation, returns 1 otherwise
	fieldName="$1"
	fieldString="$2"
	minvalue="$3"
	maxvalue="$4"

	segmentsnum_field=0
	asterisknum_field_field=0

	# field strings should not start or end with a dash
	if [ "${fieldString:0:1}" = "-" ] || [ "${fieldString: -1}" = "-" ]; then
		echo "Invalid input \"$fieldString\" for field $fieldName : it starts or ends with \"-\"." >&2
		errors="$((errors + 1))"
		return 1
	fi

	# field strings should not start or end with a comma
	if [ "${fieldString:0:1}" = "," ] || [ "${fieldString: -1}" = "," ]; then
		echo "Invalid input \"$fieldString\" for field $fieldName : it starts or ends with \",\"." >&2
		errors="$((errors + 1))"
		return 1
	fi

	# split the input field by commas (if any) and store resulting slices in the slices[] array 
	IFS="," read -ra slices <<< "$fieldString"
	
	for slice in "${slices[@]}"; do
		segmentsnum=0
		# split the slice by dashes (if any) and store resulting segments in the segments[] array 
		IFS="-", read -ra segments <<< "$slice"
		for segment in "${segments[@]}"; do
			# try validating the segment as a number (or as an asterisk)
			if ! validateNum "$segment" "$minvalue" "$maxvalue" ; then
				# if that fails, try validating the segment as a name (or as an asterisk)
				if ! validateName "$fieldName" "$segment"; then
					# if that fails, the segment is invalid - return 1 and exit the function
					echo "Invalid value \"$segment\" in field: $fieldName." >&2
					errors="$((errors + 1))"
					return 1
				fi
			fi

			# segment validation was successful
			
			# segmentsnum is used to count dash-separated segments in a slice
			segmentsnum="$((segmentsnum + 1))"
			# segmentsnum_field is used to count all segments in a field
			segmentsnum_field="$((segmentsnum_field + 1))"
			if [ "$segment" = "*" ]; then
				# count asterisks for later verification that the field containing it doesn't contain any additional segments
				asterisknum_field="$((asterisknum_field + 1))"
			fi
		done

		# it doesn't make sense to have more than two dash-separated segments in a slice
		if [ "$segmentsnum" -gt 2 ]; then
			echo "Invalid value \"$slice\" in $fieldName \"$fieldString\"." >&2
			errors="$((errors + 1))"
			return 1
		fi
	done

	# if a field contains an asterisk then there should be only one segment, otherwise the field is invalid
	if [ "$asterisknum_field" -gt 0 ] && [ "$segmentsnum_field" -gt 1 ]; then
		echo "Invalid $fieldName \"$fieldString\"" >&2
		errors="$((errors + 1))"
		return 1
	fi
}

echo ""


#### Initialize variables

errors=0
exitstatus=0


#### Basic sanity check for input arguments

# separate the input by spaces and store results in variables
read -r min hour dom mon dow extra <<< "$sourceline"

# if $extra is not empty then too many arguments have been passed
if [ -n "$extra" ]; then
	usage
	echo ""
	echo "Error: Too many fields in schedule expression! I don't know what to do with \"$extra\"!" >&2
	echo "Use double braces around your expression!" >&2
	echo "You entered: \"$sourceline\"" >&2
	echo "Valid example: \"0 4 * * 6\"" >&2
	echo ""
	exit 1;
fi

# if some arguments are missing
if [ -z "$min" ] || [ -z "$hour" ] || [ -z "$dom" ] || [ -z "$mon" ] || [ -z "$dow" ]; then
	usage
	echo ""
	echo "Not enough fields in schedule expression!"
	echo "This script requires crontab schedule line as an argument!" >&2
	echo "Use double braces around your expression!" >&2
	echo "You entered: \"$sourceline\"" >&2
	echo "Valid example: \"0 4 * * 6\"" >&2
	echo ""
	exit 1
fi


#### Main

echo "Validating cron schedule \"$sourceline\" ..."

# minute check
validateField "minute" "$min" "0" "60"

# hour check
validateField "hour" "$hour" "0" "24"

# day of month check
validateField "day of month" "$dom" "1" "31"

# month check
validateField "month" "$mon" "1" "12"

# day of week check
validateField "day of week" "$dow" "1" "7"

if [ "$errors" -gt 0 ] ; then
	exitstatus=1
	echo ""
	echo "You entered: \"$sourceline\"" >&2
	echo "Valid example: \"0 4 * * 6\"" >&2
else
	echo "Successfully validated cron schedule."
fi
echo ""

exit $exitstatus
