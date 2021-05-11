#!/bin/bash


echo "Expects that you sourced corresponding file."

srcDir=$1

dryRun=0

#sTime=$(date +"%Y-%m-%d-%H:%M:%S")
restTime=$(date +"%Y-%m-%d") ## During DEBUG/DEV

if [[ ! -v OS_AUTH_URL ]]; then
    echo "Missing openstack variables."
    exit;
fi

notCreatedUsers=""

restoreDoms () {
    echo "Domains "

    domains=$(cat ${srcDir}/domains.csv | grep -v 'Juju' | grep 'True' |awk -F',' '{print $2}' | tr -d '"' )  
    domainsString=$(cat "${srcDir}/domains.csv" | grep -v 'Juju' | grep 'True' |awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ' )  
    echo "Domains = $domainsString"

    tmpFile=$(mktemp)
    for dom in $domains; do
	echo -n " ${dom}"
	openstack domain show ${dom} &> $tmpFile
	if [[ "$dryRun" -eq 0 ]]; then
	    if [[ $(grep 'No domain' $tmpFile) ]]; then
		openstack domain create --enable ${dom}
	    else
		echo "${dom} exists already".
	    fi
	else
	    echo "  => Dry run. "
	    if [[ $(grep 'No domain' $tmpFile) ]]; then
		echo "openstack domain create --enable ${dom}"
	    else
		echo "${dom} exists already".
	    fi	
	fi	
    done
    echo " "
    rm $tmpFile
}


restoreProjects(){
    echo "Projects"

    routers=$(cat "${srcDir}/projects.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    routersString=$(cat "${srcDir}/projects.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Projects = $routersString"

    tmpFile=$(mktemp)
    for proj in $routers; do
	if [[ $(grep 'Created by Juju' ${srcDir}/projects/${proj}.yaml) ]]; then
	    projStr=$(grep ${proj} ${srcDir/projects.csv} | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
	    echo "Proj (${projStr}) was a default project, should already be present."
	else
	    projdomainid=$(grep 'domain_id:' ${srcDir}/projects/${proj}.yaml | awk '{print $2}')
	    projname=$(grep 'name:' ${srcDir}/projects/${proj}.yaml | awk '{print $2}')
	    projdescr=$(grep 'description:' ${srcDir}/projects/${proj}.yaml | awk -F':' '{print $2}')
	    oldDomainName=$(grep ${projdomainid} ${srcDir}/domains.csv | awk -F',' '{print $2}' | tr -d '"')

	    openstack project show --domain ${oldDomainName} ${dom} &> $tmpFile
	    echo "$projname - $oldDomainName - $projdescr"
	    if [[ "$dryRun" -eq 0 ]]; then
		if [[ $(grep 'No project' $tmpFile) ]]; then
		    openstack project create --domain ${oldDomainName} --description ${projdescr} --parent ${oldDomainName} ${projname}
		else
		    echo "$projname - $oldDomainName already exists."
		fi
	    else
		echo "  => Dry run. "
		if [[ $(grep 'No project' $tmpFile) ]]; then
		    echo "openstack project create --domain ${oldDomainName} --description ${projdescr} --parent ${oldDomainName} ${projname}"
		else
		    echo "$projname - $oldDomainName already exists."
		fi   
	    fi
	fi
	
    done
    rm $tmpFile

}


restoreUsers(){
    echo "Users"
    domains=$(cat ${srcDir}/domains.csv | grep -v 'Juju' | grep 'True' |awk -F',' '{print $2}' | tr -d '"' )  
    tmpFile=$(mktemp)
    
    for dom in $domains; do
	
	echo "Users for domain; ${dom}, ${srcDir}/domain/${dom}/user_*.yaml "
	for USER in ${srcDir}/domain/${dom}/user_*.yaml; do
	    echo "USER = $USER "
	    olddefproj=$(grep 'default_project_id:' ${USER} | awk '{print $2}')
	    username=$(grep 'name:' ${USER} | awk '{print $2}')
	    userdescr=$(grep 'description:' ${USER} | awk -F':' '{print $2}')
	    useremail=$(grep 'email:' ${USER} | awk -F':' '{print $2}')

	    openstack user show --domain ${dom} ${username} &> $tmpFile


	    if [[ "$dryRun" -eq 0 ]]; then
		if [[ "$olddefproj" ]]; then
		    if [[ $(grep 'No user ' $tmpFile) ]]; then
			openstack user create --domain ${dom} --project ${oldProjName} --email ${useremail} --description ${userdescr}  --password ${useremail} ${username}
		    else
			echo "$username ($dom) exists."
		    fi
		else
		    if [[ $(grep 'No project' $tmpFile) ]]; then
			openstack user create --domain ${dom} --email ${useremail} --description ${userdescr}  --password ${useremail} ${username}
		    else
			echo "$username ($dom) exists."
		    fi	
		fi
	    else
		echo " => Dry run."
		if [[ "$olddefproj" ]]; then
		    if [[ $(grep 'No project' $tmpFile) ]]; then
			echo "openstack user create --domain ${dom} --project ${oldProjName} --email ${useremail} --description ${userdescr}  --password ${useremail} ${username}"
		    else
			echo "$username ($dom) exists."
		    fi	
		else
		    if [[ $(grep 'No project' $tmpFile) ]]; then
			echo "openstack user create --domain ${dom} --email ${useremail} --description ${userdescr}  --password ${useremail} ${username}"
		    else
			echo "$username ($dom) exists."
		    fi
		fi
	    fi

	    
	done	
    done

    rm $tmpFile
}


restoreNetworks() {
    echo "Networks"

    networks=$(cat "$savelocation/networks.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    networksString=$(cat "$savelocation/networks.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Networks = $networksString"
    tmpFile=$(mktemp)
    // END OF DAY 
    for netfile in ${srcDir}/networks/$networks; do
	
	netName=$(grep 'name:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')
	netDescr=$(grep 'description:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')
	netShare=$(grep 'shared:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')
	netRouterExt=$(grep 'router:external:' "${netfile}" | awk -F':' '{print $3}' | tr -d ' ')
	netProjID=$(grep 'project_id:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')
	
	if [[ "$netRouterExt" == *"External"* ]]; then
	    echo "This is an external network, it has been replaced. "
	else
	    oldProjName=$(grep ${netProjID} ${srcDir}/projects.csv | awk -F',' '{print $2}' | tr -d '"' )
	    oldDomainID=$(grep 'domain_id:' ${srcDir}/projects/${oldDomainID}.yaml | awk -F':' '{print $2}' | tr -d ' ')
	    oldDomainName=$(grep ${oldDomainOD} ${srcDir}/domains.csv | awk -F',' '{print $2}' | tr -d '"')

	    
	    if [[ "$dryRun" -eq 0 ]]; then
		openstack network create --no-share --project ${oldProjName} --project-domain ${oldDomainName} --description ${netDescr} ${netName}
	    else
		echo " => Dry run."
		echo "openstack network create --no-share --project ${oldProjName} --project-domain ${oldDomainName} --description ${netDescr} ${netName}"
	    fi
	fi

    done

}


restoreSubnets() {
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

restoreRouters(){
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



restoreSecGroups(){
    echo "Security Groups"
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
		   alreadyRestoreed=$(echo -e "${vmname} * ${proj}\n${alreadyRestoreed}")

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

			   restoreedVMS=$(echo -e "${vmname} * ${proj}\n${restoreedVMS}")
			   
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


restoreFlavor() {
    echo "Flavor --- Not restoring, replaced with new naming scheme."

    
    return
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

restoreVolume(){
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


restoreImages(){
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

restoreKeypair() {
    echo "Keypairs"

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
#restoreUserDoms, restoreNetworks, restoreSubnets, restoreRouters, restoreSecGroups,
#saveVMs, restoreFlavor, restoreVolume, restoreImages, restoreKeypair, buildOpenrc

echo "Starting"


restoreDoms
restoreProjects
restoreUsers

#restoreKeypair

#restoreFlavor

#restoreImages
#restoreVolumes

#restoreNetworks
#restoreSubnets
#restoreRouters
#restoreSecGroups

#restoreVMs




echo "Not created users"
echo $notCreatedUsers


echo "Ending"
