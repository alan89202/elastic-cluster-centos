#!/bin/bash
while [ "$(lsblk -l | grep 'sd[b-z]' | wc -l)" -lt 2 ]; do  # Cambia '2' al número de discos que esperas
  echo "Waiting for disks to be ready..."
  sleep 10
done

lsblk -l -o NAME,SIZE,MOUNTPOINT | while read -r dev size mountpoint; do
  # Skip lines that don't start with "sd"
  if [[ "$dev" != sd* ]]; then continue; fi
  # Skip the primary disk
  if [[ "$dev" == sda* ]]; then continue; fi
  # Skip if mountpoint is not empty
  if [[ -n "$mountpoint" ]]; then continue; fi
  # Remove the trailing 'G' from the size and convert to an integer
  size=${size%G}
  if [[ "$size" -eq 30 ]]; then
    mount_dir="/applogs"
  else
    mount_dir="/appdata"
  fi
  echo "Found unmounted disk /dev/$dev, size ${size}G. Mounting to $mount_dir"
  if [[ "$dev" == sd*[0-9] ]]; then
    # If the device has a partition number, assume it is already formatted
    mountpoint="/dev/$dev"
  else
    # If the device does not have a partition number, format it
    parted /dev/$dev --script mklabel gpt mkpart xfspart xfs 0% 100%
    mkfs.xfs /dev/${dev}1
    mountpoint="/dev/${dev}1"
  fi
  mkdir -p $mount_dir
  echo "$mountpoint $mount_dir xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
  sudo mount $mount_dir
done
