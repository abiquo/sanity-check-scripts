#!/bin/bash

############################
### Script Configuration ###
############################

AIM_CONF=/etc/openwsman/openwsman.conf

################################
### End script configuration ###
################################

LANG="C"

function check_proc() {
    echo -ne "Checking ${1}...\t"
    PID=`ps -e | grep ${1} | awk '{print $1}'`
    if [[ -n ${PID} ]]; then
	echo -n "OK (pid ${PID}, "
        PORT=`netstat -putan 2>/dev/null | grep ${1} | grep "LISTEN" | awk '{print $4}' | cut -d: -f2`
        if [[ -n ${PORT} ]]; then
	    echo "listening at ${PORT})"
        else
            echo "not listening)"
        fi
    else
        echo "MISSING"
    fi
}

function check_aim() {
    echo -ne "Checking AIM...\t"

    if ! [[ -f ${1} ]]; then
        echo "MISSING CONFIG" 
    else
        echo -ne "\n  Remote repository...\t\t"
        REMOTE_REPO=`grep "remoteRepository" ${1} | awk -F= '{print $2}' | tr -d " "`
        MOUNT=`mount | grep ${REMOTE_REPO}`
        if [[ -n ${MOUNT} ]]; then
            echo "OK (at ${REMOTE_REPO})"
        else
            echo "MISSING"
        fi

        echo -ne "  Destination repository...\t"
        DEST_REPO=`grep "destinationRepository" ${1} | awk -F= '{print $2}' | tr -d " "`
        if [[ -d ${DEST_REPO} ]]; then
            echo "OK (at ${DEST_REPO})"
        else
	    echo "MISSING"
	fi
    fi
}

function check_file() {
    echo -ne "  Checking ${2}...\t"
    if [[ -e ${1} ]]; then
        echo "OK (${1})"
    else
        echo "MISSING"
    fi
}

function check_vagent() {
    echo -ne "  Checking vagent...\t"
    if [[ -f ${1} ]]; then
        LIBVIRT_URI=`grep -v ^# ${1} | grep "libvirt_uri" | awk -F= '{print $2}' | tr -d " "`
        if [[ -n ${LIBVIRT_URI} ]]; then
            if [[ "${LIBVIRT_URI}" == ${2} ]]; then
                echo "OK (libvirt_uri = ${2})"
            else
                echo "ERROR (libvirt_uri should be ${2})"
            fi
        else
            echo "MISSING"
        fi
    else
        echo "MISSING"
   fi 
}

function check_firewall() {
    echo "Checking firewall..."
    FWCONFIG=`chkconfig --list | grep iptables | awk '{print $2,$3,$4,$5,$6,$7}'`
    DEFAULTRL=`grep "initdefault" /etc/inittab | grep -v "^#" | cut -d: -f2`
    CURRENTRL=`runlevel | awk '{print $2}'`
    echo -ne "  Firewall status:\t"
    if [[ -n `echo ${FWCONFIG} | grep "${CURRENTRL}:off"` ]]; then
        echo -n "DISABLED, "
    else
        echo -n "ENABLED, "
    fi
    HAS_RULES=`iptables -nL | grep -iv ^chain | grep -iv ^target | grep -v ^$`
    if [[ -n ${HAS_RULES} ]]; then
        echo "active rules found!"
    else
        echo "no active rules"
    fi
    echo -e "  Runlevel config:\tcurrent = ${CURRENTRL}, default = ${DEFAULTRL}"
    echo -e "  Firewall activation:\t${FWCONFIG}"
    echo -ne "  SELinux status:\t"
    if [[ $(ls -A /selinux) ]]; then
        echo "ENABLED"
    else
        echo "DISABLED"
    fi
}

function check_bridge() {
    echo -ne "Checking bridge...\t"
    HASBRIDGE=`brctl show | grep ^${1}`
    if [[ -n ${HASBRIDGE} ]]; then
        echo -n "OK (${1} "
        IFACE=`find /sys/class/net/${1}/brif -iname "*eth*" -exec basename {} \;`
        if [[ -n ${IFACE} ]]; then
            echo "attached to ${IFACE})"
        else
            echo "not attached to an interface)"
        fi
    else
        echo "MISSING"
    fi
}

check_proc "openwsmand"
check_proc "libvirtd"
check_bridge "br0"
check_firewall
check_aim "${AIM_CONF}"

if [[ $# -gt 0 ]]; then
    if [[ "${1}" == "kvm" ]]; then
        echo "Checking KVM configuration..."
        check_vagent "${AIM_CONF}" "qemu+unix:///system"
        check_file /usr/bin/qemu-kvm "emulator"
        check_file /usr/bin/qemu-kvm "loader"
    elif [[ "${1}" == "xen" ]]; then
        echo "Checking XEN configuration..."
        check_vagent "${AIM_CONF}" "xen+unix:///"
	check_file /usr/lib64/xen/bin/qemu-dm "emulator"
	check_file /usr/lib/xen/boot/hvmloader "loader"
    fi
fi

