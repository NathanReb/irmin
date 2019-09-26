#!/usr/bin/env bash

find . -name '*.mli' | while read mli; do
  ml=${mli%%\.mli}.ml
  if ! [[ -e $ml ]]; then
    cp "../irmin/$ml" "$ml"
    echo "copied $ml: $?"
  fi
done
