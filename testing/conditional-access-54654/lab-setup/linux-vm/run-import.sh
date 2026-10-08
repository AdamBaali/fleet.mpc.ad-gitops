#!/bin/bash
{
  echo "== whoami: $(whoami)"
  echo "== homes:"; ls -la /home
  /opt/company/import-certificate-to-browsers.sh; echo "== import exit=$?"
  echo "== nssdb (user lab):"; runuser -u lab -- certutil -L -d sql:/home/lab/.pki/nssdb
  echo "== firefox profiles:"; ls -d /home/lab/.mozilla/firefox/*/ /home/lab/snap/firefox/common/.mozilla/firefox/*/ 2>&1
  echo "== firefox installed:"; which firefox; snap list firefox 2>&1 | tail -2
  echo "== chrome/chromium:"; which google-chrome chromium chromium-browser 2>&1
} > /tmp/import.out 2>&1
