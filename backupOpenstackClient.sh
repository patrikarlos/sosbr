#!/bin/bash


echo "Expects that you sourced corresponding file."
snapshot=1

#sTime=$(date +"%Y-%m-%d-%H:%M:%S")
sTime=$(date +"%Y-%m-%d") ## During DEBUG/DEV

savelocation=/mnt/KM/backup/openstack/$sTime
vmlocation=/mnt/KM/backup/openstack/$sTime
cephVMS=""
backedVMS=""
alreadyBacked=""

mkdir -p $savelocation
mkdir -p $vmlocation

if [[ ! -v OS_AUTH_URL ]]; then
    echo "Missing openstack variables."
    exit;
fi

ueS=""
userDomain=""
ignoreInstance=""
    # "df2dfccb-da28-41b3-9495-fa03d55b7661 7edfc0f0-b688-4cca-b3d2-c0639b642243"

backUserDoms () {
    echo "Domains & Users"
    openstack domain list -f csv > $savelocation/domains.csv

    domains=$(cat "$savelocation/domains.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    domainsString=$(cat "$savelocation/domains.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Domains = $domainsString"

    userEmails=""
    userDomain=""

    for dom in $domains; do
	domStr=$(grep $dom "$savelocation/domains.csv" | awk -F',' '{print $2}' | tr -d '"'| tr ' ' '_')
	echo "Domain: $domStr ($dom)"
	mkdir -p "$savelocation/domain/$domStr"
	openstack user list -f csv --domain $dom > $savelocation/domain/$domStr/users.csv
	users=$(cat "$savelocation/domain/$domStr/users.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
	usersString=$(cat "$savelocation/domain/$domStr/users.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
	echo "users = $usersString "

	for usr in $users; do
	    usrStr=$(grep $usr "$savelocation/domain/$domStr/users.csv" | awk -F',' '{print $2}' | tr -d '"')
	    echo -n "$usrStr ($usr) "
	    openstack user show -f yaml $usr > $savelocation/domain/$domStr/user_$usrStr_$usr.yaml
	    uemail=$(openstack user show -f yaml $usr | grep 'email:' | awk '{print $2}')
	    userEmails=$(echo -e "$uemail\n$userEmails")
	    userDomain=$(echo -e "$uemail - $domStr ($dom)\n$userDomain");
	done
	echo " "
    done
    echo " "

    ueS=$(echo -e "$userEmails" | sort | uniq | grep -v 'juju@localhost' )
    userDomain=$(echo -e "$userDomain" | sort | uniq | grep -v 'juju@localhost' )

    echo "userEmails = $ueS "
}

backNetworks() {
    echo "Networks"
    openstack network list -f csv > $savelocation/networks.csv

    networks=$(cat "$savelocation/networks.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    networksString=$(cat "$savelocation/networks.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Networks = $networksString"
    mkdir -p $savelocation/networks/

    for net in $networks; do
	netStr=$(grep $net "$savelocation/networks.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "Network: $netStr ($net)"
	openstack network show -f yaml $net > $savelocation/networks/network_$net.yaml
    done

}


backSubnets() {
    echo "Subnetworks"
    openstack subnet list -f csv > $savelocation/subnets.csv

    mkdir -p $savelocation/subnets/

    subnetworks=$(cat "$savelocation/subnets.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    subnetworksString=$(cat "$savelocation/subnets.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Subnetworks = $subnetworksString"

    for snet in $subnetworks; do
	netStr=$(grep $snet "$savelocation/subnets.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "Subnetwork: $netStr ($snet)"
	openstack subnet show -f yaml $snet > $savelocation/subnets/subnet_$snet.yaml
    done
}

backRouters(){
    echo "Routers"

    openstack router list -f csv > $savelocation/routers.csv

    routers=$(cat "$savelocation/routers.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    routersString=$(cat "$savelocation/routers.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Routers = $routersString"
    mkdir -p $savelocation/routers/

    for rt in $routers; do
	netStr=$(grep $rt "$savelocation/routers.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "Router: $netStr ($rt)"
	openstack router show -f yaml $rt > $savelocation/routers/$rt.yaml
    done
}


backProjects(){
    echo "Projects"
    ## NOTE FIX ANY locale chars in the description and project name, so they are stored properly and dont cause issues when restoring
    ## åäöÅÄÖ ' " etc.. 
    
    openstack project list -f csv > $savelocation/projects.csv

    routers=$(cat "$savelocation/projects.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    routersString=$(cat "$savelocation/projects.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Projects = $routersString"
    mkdir -p $savelocation/projects/

    for proj in $routers; do
        projStr=$(grep $proj "$savelocation/projects.csv" | awk -F',' '{print $2}' | tr -d '"')
        echo "Project: $projStr ($proj)"
        openstack project show -f yaml $proj > $savelocation/projects/$proj.yaml
    done

}

backSecGroups(){
    echo "Security Groups"

    ## BACKUP RULES separately!!
    openstack security group list -f csv > $savelocation/security_group.csv

    sg=$(cat "$savelocation/security_group.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgString=$(cat "$savelocation/security_group.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Security Groups = $sgString / $sg"
    mkdir -p $savelocation/security_groups/

    echo " processing "
    for proj in $sg; do
	projStr=$(grep $proj "$savelocation/security_group.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "SG: $projStr ($proj)"
	openstack security group show -f yaml $proj >  $savelocation/security_groups/$proj.yaml
    done


    echo "Security Groups - Rules"
    openstack security group rule list -f csv > $savelocation/security_group_rules.csv

    sg=$(cat "$savelocation/security_group_rules.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    echo "Security Groups - Rules "
    echo "$sg"
    echo "------------------------"

    mkdir -p $savelocation/security_group_rules/
    for proj in $sg; do
	echo "SGR: $proj " 
	openstack security group rule show -f yaml $proj > $savelocation/security_group_rules/$proj.yaml
    done
}


saveVMs() {
    echo "VMs"
    openstack server list --all -f csv > $savelocation/vm.csv
    mkdir -p $savelocation/vms
    mkdir -p $vmlocation/instance_disks
    
    sg=$(cat "$savelocation/vm.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgString=$(cat "$savelocation/vm.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "VM = $sgString"
    echo " "


    tmpfile=$(mktemp)
    tmpfile2=$(mktemp)

    for proj in $sg; do
	ign=$(echo "$ignoreInstance" | grep "$proj")
	if [[ ! -z "$ign" ]]; then
	   echo "Will ignore this instance, its a part of the Migration project"
	   continue;
	fi
	   
	   projStr=$(grep $proj "$savelocation/vm.csv" | awk -F',' '{print $2}' | tr -d '"')
	   #    echo "VM: $proj ($projStr) "
	   openstack server show -f yaml $proj > $savelocation/vms/$proj.yaml
	   vmname=$(grep name: $savelocation/vms/$proj.yaml | grep -v 'key_name' | grep -v 'OS-EXT' | awk '{print $2}')
	   vmstatus=$(grep status: $savelocation/vms/$proj.yaml)
	   volumes=$(grep volumes: $savelocation/vms/$proj.yaml)

	   if [[ -z $volumes ]]; then
	       echo "$vmname - $vmstatus - volumes: N/A"
	   else
	       echo "$vmname - $vmstatus - volumes: $volumes"
	   fi

	   

	   if [[ $snapshot ]]; then
	       echo "Triggering a snapshot of VM.";
	       imName=$(echo "$projStr-$sTime" | tr " " "_")
	       echo "=> VM $proj - $vmname ; "
	       #	openstack server image create --name $imName $proj;	
	       
	       data=$(openstack server show $proj -f yaml)
	       computeNodeName=$(echo "$data" | grep 'OS-EXT-SRV-ATTR:hypervisor_hostname' | awk '{print $2}'| awk -F'.' '{print $1}')
	       computeNode=$(juju status | grep "$computeNodeName" | awk '{print $1}')
	       instName=$(echo "$data" | grep 'OS-EXT-SRV-ATTR:instance_name' | awk '{print $2}' )

	       
	       echo "computeNode=$computeNode / $computeNodeName  instName =$instName"
	       #	echo "DATA------------"
	       #	echo "$data"
	       #	echo "------------DATA"


	       if [ -s $vmlocation/instance_disks/${proj}.vdi ]; then
		   echo "We already have a copy of that disk in $savelocation/instance_disks/${proj}.vdi"
		   alreadyBacked=$(echo -e "${vmname} * ${proj}\n${alreadyBacked}")

	       else

		   juju ssh ${computeNode} "ls -la /tmp/instances/${proj}.vdi}" > $tmpfile
		   grep -v 'cannot access' $tmpfile > $tmpfile2

		   if [ ! -s $tmpfile2 ]; then
		       echo "create /tmp/instances: 	juju ssh $computeNode sudo mkdir -p /tmp/instances/"
		       juju ssh ${computeNode} sudo mkdir -p /tmp/instances/
		       echo "suspend instance; 	juju ssh $computeNode sudo virsh suspend $instName"
		       juju ssh ${computeNode} sudo virsh suspend ${instName}
		       echo "dumpxml: 	juju ssh $computeNode sudo virsh dumpxml $instName > /tmp/instances/${proj}_dumpxml.xml"
		       juju ssh ${computeNode} sudo "virsh dumpxml ${instName} > /tmp/instances/${proj}_dumpxml.xml"

		       juju ssh ${computeNode} sudo grep ceph /tmp/instances/${proj}_dumpxml.xml > $tmpfile
		       if [ -s $tmpfile ]; then
			   echo "Instance uses ceph, will not snapshot it."
			   echo "It requires special treatment."
			   cephVMS=$(echo -e "${vmname} * ${proj}\n${cephVMS}")
		       else
			   echo "Std storage. Snapping it."
			   
			   echo "cp disk : 	juju ssh $computeNode sudo cp /var/lib/nova/instances/$proj/disk /tmp/instances/${proj}.raw"
			   juju ssh ${computeNode} sudo cp /var/lib/nova/instances/${proj}/disk /tmp/instances/${proj}.raw

			   echo "Convert : 	juju ssh $computeNode sudo qemu-img convert -O vdi /tmp/instances/${proj}.raw /tmp/instances/${proj}.vdi"

			   juju ssh ${computeNode} sudo qemu-img convert -O vdi /tmp/instances/${proj}.raw /tmp/instances/${proj}.vdi

			   echo "Remove raw file: 	juju ssh ${computeNode} sudo rm /tmp/instances/${proj}.raw"
			   juju ssh ${computeNode} sudo rm /tmp/instances/${proj}.raw

			   echo "Copy files here. juju scp ${computeNode}:/tmp/instances/${proj}.vdi $vmlocation/instance_disks/${proj}.vdi"
			   juju scp ${computeNode}:/tmp/instances/${proj}.vdi $vmlocation/instance_disks/${proj}.vdi
			   juju scp ${computeNode}:/tmp/instances/${proj}_dumpxml.xml $vmlocation/instance_disks/${proj}_dumpxml.xml
			   
			   echo "Remove file on compute juju ssh ${computeNode} rm /tmp/instances/${proj}.vdi"
			   juju ssh ${computeNode} sudo rm /tmp/instances/${proj}.vdi

			   backedVMS=$(echo -e "${vmname} * ${proj}\n${backedVMS}")
			   
		       fi
		       
		       echo "Resume instance: 	juju ssh $computeNode sudo virsh resume $instName"
		       juju ssh ${computeNode} sudo virsh resume $instName
		       
		   else
		       echo "${proj} has already been snapped, on the computeNode. "
		       echo "tmpfile2 = $tmpfile2 "
		       echo "-----------"
		       cat $tmpfile2
		       echo "-----------"
		   fi
	       fi ## else (if vmlocation/instance_disks/
	   fi
	   read -t 1 -p "Abort?" abort
	   status=$?
	   if [[ $status -eq 0 ]];then
	       echo "Aborting."
	       break;
	   else
	       echo "Continuing."
	   fi

    done

#    cnodes="iDRAC-2N3FFV2 iDRAC-2HHGFV2"
#    mkdir -p $savelocation/instance_disks/
#
#    for cn in ${cnodes}; do
#	juju scp $cn:/tmp/instances/* $savelocation/instance_disks
#    done

}


backFlavor() {
    echo "Flavor"
    openstack flavor list -f csv > $savelocation/flavor.csv

    sg=$(cat "$savelocation/flavor.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgStr=$(cat "$savelocation/flavor.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr -d '\n')
    echo "Flavors: $sgStr "
    echo "------------------------"

    mkdir -p $savelocation/flavor/
    for proj in $sg; do
        projStr=$(grep $proj "$savelocation/flavor.csv" | awk -F',' '{print $2}' | tr -d '"')
        echo "SGR: $proj ($projStr)" 
        openstack flavor show -f yaml $proj > $savelocation/flavor/$proj.yaml
    done
}

backVolume(){
    echo "Volumes"
    # ## KOLLA UPP!!! 

    openstack volume list -f csv --all > $savelocation/volume.csv

    sg=$(cat "$savelocation/volume.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgStr=$(cat "$savelocation/volume.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr -d '\n')
    echo "Volume: $sgStr "
    echo "------------------------"

    mkdir -p $savelocation/volume/
    for proj in $sg; do
	projStr=$(grep $proj "$savelocation/volume.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "Vol: $proj ($projStr)" 
	openstack volume show -f yaml $proj > $savelocation/volume/$proj.yaml

	volname=$(echo "${proj}_snapshot")
	if [[ $snapshot ]]; then
	    imName=$(echo "$proj-snapshot" | tr " " "_")
	    echo -e "\tGrabbing copy, stored to $imName";
	    openstack image create --volume $proj  $imName
	fi

    done

}


backImages(){
    echo "Images"
    openstack image list -f csv > $savelocation/image.csv

    sg=$(cat "$savelocation/image.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgStr=$(cat "$savelocation/image.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr -d '\n')
    echo "Image: $sgStr "
    echo "------------------------"

    mkdir -p $savelocation/image/
    for proj in $sg; do
	projStr=$(grep $proj "$savelocation/image.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "Image: $proj ($projStr)" 
	openstack image show -f yaml $proj > $savelocation/image/$proj.yaml

	if [[ $snapshot ]]; then
	    imName=$(echo "$projStr-$sTime" | tr " " "_")
	    echo -e "\tGrabbing copy, stored to $imName";
	    echo -e "\topenstack image save --file $savelocation/image/$imName.osimg"
	fi
	
    done

}

backKeypair() {
    echo "Keypairs"

    ## Investigate or disable, cant restore anyway. 
    
    domains=$(cat "$savelocation/domains.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    domainsString=$(cat "$savelocation/domains.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')

    for dom in $domains; do
	domStr=$(grep $dom "$savelocation/domains.csv" | awk -F',' '{print $2}' | tr -d '"' | tr ' ' '_')
	echo "Domain: $domStr ($dom)"
	
	
	users=$(openstack user list -f csv --domain $dom | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
	usersString=$(openstack user list -f csv --domain $dom | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
	echo "users = $usersString "

	for usr in $users; do
 	    usrStr=$(grep $usr "$savelocation/domain/$domStr/users.csv" | awk -F',' '{print $2}' | tr -d '"')

	    mkdir -p $savelocation/keypair/$domStr/$usr
	    nova keypair-list --user $usr  > $savelocation/keypair/$domStr/kp_$usr.csv
	    
	    kpl=$(nova keypair-list --user $usr | sed 1,3d | grep '|' | awk '{print $2}')
	    echo "keypairs for $dom/$usr ($usrStr)"
	    echo "$kpl"
	    echo "------"
	    for keyid in $kpl; do
		echo -e "\t$keyid "
		nova keypair-show --user $usr $keyid  > $savelocation/keypair/$domStr/$usr/kp_$keyid.yaml
	    done

	done
	echo " "
    done
    echo " "

 }

 
buildOpenrc() {
    echo "build openrc files"

    domains="566007b49bb94d43bde4494a1cd1819d 8a585d8014f8473289ab54b8c71fe16c 60b7281de3a04c549b80101f84c5a338"

    for dom in $domains; do
	domStr=$(grep $dom "$savelocation/domains.csv" | awk -F',' '{print $2}' | tr -d '"'| tr ' ' '_')
	echo "Domain: $domStr ($dom)"
	openstack user list -f csv --domain $dom > $savelocation/domain/$domStr/users.csv
	users=$(cat "$savelocation/domain/$domStr/users.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
	usersString=$(cat "$savelocation/domain/$domStr/users.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
	echo "users = $usersString "

	for usr in $users; do
	    usrStr=$(grep $usr "$savelocation/domain/$domStr/users.csv" | awk -F',' '{print $2}' | tr -d '"')
	    echo "$usrStr ($usr) "
	    uemail=$(openstack user show -f yaml $usr | grep 'email:' | awk '{print $2}')
	    userEmails=$(echo -e "$uemail\n$userEmails")
	    userDomain=$(echo -e "$uemail - $domStr ($dom)\n$userDomain");

	    OSNAME=$(openstack user show -f yaml $usr | grep 'name:' | awk '{print $2}')
	    OSPI=$(openstack user show -f yaml $usr | grep 'default_project_id' | awk '{print $2}')

	    if [[ -z "$OSPI" ]]; then
		echo "Missing default project." 
		continue;
	    fi
	    OSPN=$(openstack project show -f yaml $OSPI | grep 'name:' | awk '{print $2}')

	    fname="${savelocation}/${domStr}_${usrStr}_openrc.sh"
	    echo "$OSNAME | $uemail -  $OSPI  - $OSPN - $domStr "
	    echo "--> $fname"
	    
	    echo -e "export OS_AUTH_URL=http://10.35.0.17:5000/v3
	    # With the addition of Keystone we have standardized on the term **project**
	    # as the entity that owns the resources. " > $fname
	    echo "export OS_PROJECT_ID=$OSPI " >> $fname
	    echo "export OS_PROJECT_NAME=$OSPN " >> $fname
	    echo "export OS_USER_DOMAIN_NAME=$domStr " >> $fname
	    echo "if [ -z \"\$OS_USER_DOMAIN_NAME\" ]; then unset OS_USER_DOMAIN_NAME; fi " >> $fname
	    echo "export OS_PROJECT_DOMAIN_ID=$dom " >> $fname
	    echo " if [ -z \"\$OS_PROJECT_DOMAIN_ID\" ]; then unset OS_PROJECT_DOMAIN_ID; fi " >> $fname
	    echo "# unset v2.0 items in case set " >> $fname
	    echo "unset OS_TENANT_ID" >> $fname
	    echo "unset OS_TENANT_NAME" >> $fname
	    echo "# In addition to the owning entity (tenant), OpenStack stores the entity" >> $fname
	    echo "# performing the action as the **user**." >> $fname
	    echo "export OS_USERNAME=$OSNAME" >> $fname
	    echo "# With Keystone you pass the keystone password." >> $fname
	    echo "#echo \"Please enter your OpenStack Password for project \$OS_PROJECT_NAME as user \$OS_USERNAME: \"" >> $fname
	    echo "read -p \"Please enter your openstack password for \$OS_PROJECT_NAME and \$OS_USERNAME\"  PASSWD " >> $fname
	    echo "export OS_PASSWORD=\$PASSWD " >> $fname
	    echo # If your configuration has multiple regions, we set that information here." >> $fname
	    echo "# OS_REGION_NAME is optional and only valid in certain environments." >> $fname
	    echo "export OS_REGION_NAME="RegionOne"" >> $fname
	    echo "# Don't leave a blank variable, unset it if it was empty " >> $fname
	    echo "if [ -z \"\$OS_REGION_NAME\" ]; then unset OS_REGION_NAME; fi" >> $fname
	    echo "export OS_INTERFACE=public" >> $fname
	    echo "export OS_IDENTITY_API_VERSION=3" >> $fname
	    
	done
	echo " "
    done

    ueS=$(echo -e "$userEmails" | sort | uniq | grep -v 'juju@localhost' )
    echo "userEmails = $ueS "
}

#
#backUserDoms, backNetworks, backSubnets, backRouters, backSecGroups,
#saveVMs, backFlavor, backVolume, backImages, backKeypair, buildOpenrc

echo "Starting"


backUserDoms
backNetworks
backSubnets
backRouters
backProjects
backSecGroups
saveVMs
backFlavor
backVolumes
backImages
backKeypair



echo "Ending"
echo "Already backed up in $vmlocation;"
echo -e "$alreadyBacked "
echo "ceph VMs (not backed up)"
echo -e "$cephVMS"
echo "backed up VMs"
echo -e "$backedVMS"
echo "Ignored VMs"
echo -e "$ignoreInstance "
