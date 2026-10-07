#!/bin/bash
# Trust the lab Root CA (copied to /tmp by the preceding file provisioner).
set -euo pipefail
install -m 0644 -o root -g root /tmp/sentania-lab-root-2.crt /etc/pki/ca-trust/source/anchors/sentania-lab-root-2.crt
update-ca-trust extract
rm -f /tmp/sentania-lab-root-2.crt
