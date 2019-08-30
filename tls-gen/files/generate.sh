#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

# Log given message and exit with code 1.
fail() {
  echo >&2 "$1"
  exit 1
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME=`basename "$0"`


USAGE="Usage:
  ${SCRIPT_NAME} COMMAND [NAME_VALUE_PAIRS]
  ${SCRIPT_NAME} basic PASSWORD=bunnies DAYS_OF_VALIDITY=365

  See https://github.com/michaelklishin/tls-gen for more information about the Generation Scripts

Commands:
  basic
    - generates basic self signed certificates.
    - the following values can be defined:
    	- CN
    	- SERVER_ALT_NAME
    	- NUMBER_OF_PRIVATE_KEY_BITS
    	- DAYS_OF_VALIDITY
    	- ECC_CURVE
    	- USE_ECC
    	- PASSWORD
"

# Print given message and the usage and exit with code 1.
failWithUsage() {
  echo -e "Error: $1" >&2
  echo
  echo -e "${USAGE}" >&2
  exit 1
}

# Print given message and given usage text and exit with code 1.
failWithCommandUsage() {
  echo -e "Error: $1" >&2
  echo
  echo -e "$2" >&2
  exit 1
}

run-basic() {
	cd /tls-gen/basic
	make $@
	make verify
	make info
	ls -l /tls-gen/basic/result
  cp -Rp /tls-gen/basic/result/* /tls-result
}

run-verify() {
  cd /tls-gen/basic
  mkdir -p ./result
  cp -Rp /tls-result/* /tls-gen/basic/result || true
  make verify
  make info
  ls -l /tls-gen/basic/result
}


# Parse global arguments and command.
# Command specific arguments will be parsed in run-COMMAND method.
export COMMAND=""
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      echo
      echo -e "${USAGE}"
      exit 0
      ;;
    *)
      test -z "${COMMAND}" || failWithUsage "Unexpected argument: '$1'"
      # first positional argument is the COMMAND
      COMMAND="$1"
      shift
      break
      ;;
  esac
  shift # past argument key
done
test -n "${COMMAND}" || failWithUsage "Missing COMMAND argument."


# Run command.
case "${COMMAND}" in
  basic) run-basic "$@";;
  verify) run-verify;;
  *)
    failWithUsage "Unknown command: '${COMMAND}'"
    ;;
esac

