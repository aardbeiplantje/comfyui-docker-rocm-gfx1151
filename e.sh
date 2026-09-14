#!/bin/bash
if [ "$1" = "" ]; then
    set -- bash -i
fi
exec "$@"
