#!/usr/bin/env sh

# help function
help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help            show this help message and exit"
    echo "  -d, --domain        set domain that will be used by apps. i.e if domain is set to 'myhost.com', then the apps will be available at 'app.myhost.com'"
    echo "  -v, --verbose         verbose output"
}

while [ "$1" != "" ]; do
    case $1 in
        -h | --help )           help
                                exit
                                ;;
        -d | --domain )       shift
                                DOMAIN=$1
                                ;;
        -v | --verbose )        VERBOSE=1
                                ;;
        * )                     help
                                exit 1
    esac
    shift
done

validate() {
    if [ -z "$DOMAIN" ]; then
        echo "DOMAIN is empty. Please provide a domain using -d or --domain"
        exit 1
    fi
}

verbose() {
    if [ -n "$VERBOSE" ]; then
        echo "$@"
    fi
}


main() {
  verbose "Validating input"
  validate
#
  verbose "Completed validation"

  if ! systemctl is-active --quiet sysbox; then
        echo "Sysbox may not be running. Make sure it is installed and running." >&2
  fi

  create_docker_in_docker
}

main