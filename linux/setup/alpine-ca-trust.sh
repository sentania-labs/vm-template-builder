#!/bin/sh
# Trust the lab Root CA (copied to /tmp by the preceding file provisioner).
set -eu
install -m 0644 -o root -g root /tmp/sentania-lab-root-2.crt /usr/local/share/ca-certificates/sentania-lab-root-2.crt
update-ca-certificates
rm -f /tmp/sentania-lab-root-2.crt
