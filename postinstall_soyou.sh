#!/bin/bash

# put everything into a function so we can easily get all output in a log
main () {
echo "###### `date` ######"

ROTATIONAL=`cat /sys/block/sda/queue/rotational`
if [[ $ROTATIONAL -eq 1 ]]; then
    echo "Server has standard ROTATIONAL drives"
    RAIDDEVICE=/dev/md4
else
    echo "Server has SSD drives"
    RAIDDEVICE=/dev/md3
    echo "Trimming /root"
    fstrim -v /
fi

if [[ `mount | grep spare` ]]; then
    echo "Unmouting temporary data space created by OVH installer"
    umount /tmp/spare || exit 1
fi
if [[ ! -b /dev/md3 ]]; then
    for DRIVE in sda sdb sdc
    do
        echo "Processind /dev/${DRIVE}"
	parted /dev/${DRIVE} unit s -- mkpart primary 21178368 -1
    done
    sleep 1
    partprobe
    for DRIVE in sda sdb sdc
    do
        if [[ -b /dev/${DRIVE} ]]; then
            echo "Cleaning potential old RAID superblock on /dev/${DRIVE}3"
            mdadm --misc --zero-superblock /dev/${DRIVE}3
        fi
    done
    if [[ -b /dev/sdc ]]; then
        echo "Found /dev/sdc block device. Assuming 3 SSD drives are present."
        echo "Creating RAID 5 device"
        yes | mdadm --create -f --assume-clean --verbose /dev/md3 --level=5 --raid-devices=3 /dev/sda3 /dev/sdb3 /dev/sdc3
    else
        echo "Creating RAID 1 device"
        partprobe
        yes | mdadm --create -f --assume-clean --verbose /dev/md3 --level=1 --raid-devices=2 /dev/sda3 /dev/sdb3
    fi
fi

UUID=`mdadm --detail /dev/md3 | grep UUID | awk '{print $3}'`
echo "ARRAY /dev/md3 UUID=$UUID" >> /etc/mdadm/mdadm.conf
update-initramfs -u

echo "Setting short hostname in /etc/hostname"
echo `hostname -s` > /etc/hostname

echo "Adding SSH key"
wget https://gist.githubusercontent.com/brunoleon/e3c12faf0f8aab27b3cd71aff84f0174/raw/9a5e3410667c98740157f4b3415a5a2bc70b467d/gistfile1.txt -O /root/.ssh/authorized_keys
}

main 2>&1 | tee -a /var/log/post_install.log
exit 0
