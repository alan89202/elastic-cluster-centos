#!/bin/bash

# Contar los discos no montados al principio
unmounted_disks=$(lsblk -dpno NAME,MOUNTPOINT | grep -c '^/dev/sd[b-z][^1-9]* $')

n=1
while [[ $unmounted_disks -gt 0 ]]; do
  echo "Checking for unmounted disks..."
  lsblk -dpno NAME,SIZE,MOUNTPOINT | while read -r dev size mountpoint; do
    if [[ -z "$mountpoint" && "$dev" != "/dev/sda" ]]; then
      if [[ $size == "30G" ]]; then
        echo "Found unmounted disk $dev, size $size. Mounting to /applogs"
        mount_point="/app/logs"
      else
        echo "Found unmounted disk $dev, size $size. Mounting to /mnt/data$n"
        mount_point="/app/data$n"
        n=$((n+1))
      fi
      parted $dev --script mklabel gpt mkpart xfspart xfs 0% 100%
      mkfs.xfs ${dev}1
      mkdir -p $mount_point
      echo "${dev}1 $mount_point xfs defaults,nofail 0 2" | tee -a /etc/fstab
      mount $mount_point
      unmounted_disks=$((unmounted_disks-1))
    fi
  done
  sleep 10
done
