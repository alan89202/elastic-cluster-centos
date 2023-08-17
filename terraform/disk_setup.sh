#!/bin/bash

unmounted_disks=0
for disk in $(lsblk -dpno NAME | grep '^/dev/sd[b-z]$'); do
  partition="${disk}1"
  if ! lsblk -pno NAME | grep -q "^$partition$"; then
    unmounted_disks=$((unmounted_disks+1))
  fi
done
echo $unmounted_disks
n=1
while [[ $unmounted_disks -gt 0 ]]; do
  echo "Checking for unmounted disks..."
  for disk in $(lsblk -dpno NAME,TYPE | grep 'disk' | awk '{print $1}'); do
    partitions=$(lsblk -dpno NAME,MOUNTPOINT | grep ${disk})
    if [[ ! $partitions =~ ${disk}1 && "$disk" != "/dev/sda" ]]; then
      size=$(lsblk -dpno SIZE $disk | tr -d ' ')
      if [[ $size == "30G" ]]; then
        echo "Found unmounted disk $disk, size $size. Mounting to /app/logs"
        mount_point="/app/logs"
      else
        echo "Found unmounted disk $disk, size $size. Mounting to /app/data$n"
        mount_point="/app/data$n"
        n=$((n+1))
      fi

      parted $disk --script mklabel gpt mkpart xfspart xfs 0% 100%
      sleep 5
      until [ -e "${disk}1" ]; do
        sleep 1
      done

      mkfs.xfs ${disk}1
      mkdir -p $mount_point
      echo "${disk}1 $mount_point xfs defaults,nofail 0 2" | tee -a /etc/fstab
      mount $mount_point
      unmounted_disks=$((unmounted_disks-1))
    fi
  done
  sleep 10
done
