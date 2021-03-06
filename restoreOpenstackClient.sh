#!/bin/bash


echo "Expects that you sourced corresponding file."

srcDir=$1

dryRun=1

#sTime=$(date +"%Y-%m-%d-%H:%M:%S")
restTime=$(date +"%Y-%m-%d") ## During DEBUG/DEV

if [[ ! -v OS_AUTH_URL ]]; then
    echo "Missing openstack variables."
    exit;
fi

notCreatedUsers=""

echo "Reading support lib."
#source supportlib.sh
source /usr/local/src/parse_yaml.sh


restoreDoms () {
    echo "<Domains> "

    domains=$(cat ${srcDir}/domains.csv | grep -v 'Juju' | grep 'True' |awk -F',' '{print $2}' | tr -d '"' )  
    domainsString=$(cat "${srcDir}/domains.csv" | grep -v 'Juju' | grep 'True' |awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ' )  
    echo "$domainsString"
    echo ""
    
    tmpFile=$(mktemp)
    for dom in $domains; do
	echo -n "${dom}"
	openstack domain show ${dom} &> $tmpFile
	if [[ "$dryRun" -eq 0 ]]; then
	    if [[ $(grep 'No domain' $tmpFile) ]]; then
		openstack domain create --enable ${dom}
	    else
		echo " exists already".
	    fi
	else
	    echo "  => Dry run. "
	    if [[ $(grep 'No domain' $tmpFile) ]]; then
		echo "openstack domain create --enable ${dom}"
	    else
		echo " exists already".
	    fi	
	fi	
    done
    echo " "
    rm $tmpFile
}


restoreProjects(){
    echo "<Projects>"

    routers=$(cat "${srcDir}/projects.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    routersString=$(cat "${srcDir}/projects.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "$routersString"
    echo ""

    tmpFile=$(mktemp)
    for proj in $routers; do
	projname=$(grep 'name:' ${srcDir}/projects/${proj}.yaml | awk '{print $2}' )
	projdomainid=$(grep 'domain_id:' ${srcDir}/projects/${proj}.yaml | awk '{print $2}')
	projdescr=$(grep 'description:' ${srcDir}/projects/${proj}.yaml | awk -F':' '{print $2}' | sed -r 's/\\xE4/ä/g' | sed -r 's/\\xF6/ö/' )
	oldDomainName=$(grep ${projdomainid} ${srcDir}/domains.csv | awk -F',' '{print $2}' | tr -d '"')
	
	if [[ $(grep 'Created by Juju' ${srcDir}/projects/${proj}.yaml) ]]; then
	    echo "${projname} was a default project, should already be present (${oldDomainName})."
	else
	    openstack project show --domain ${oldDomainName} ${projname} &> $tmpFile
	    echo -n "$projname - $oldDomainName - $projdescr "
	    if [[ "$dryRun" -eq 0 ]]; then
		if [[ $(grep 'No project' $tmpFile) ]]; then
		    echo ">openstack project create --domain ${oldDomainName} --description ${projdescr}  ${projname} "
		    openstack project create --domain ${oldDomainName} --description ${projdescr} ${projname}
		else
		    echo " already exists. "
		fi
	    else
		echo "  => Dry run. "
		if [[ $(grep 'No project' $tmpFile) ]]; then
		    echo "openstack project create --domain ${oldDomainName} --description ${projdescr} ${projname}"
		else
		    echo " already exists."
		fi   
	    fi
	fi	
    done
    rm $tmpFile

}


restoreUsers(){
    echo "<Users>"
    domains=$(cat ${srcDir}/domains.csv | grep -v 'Juju' | grep 'True' |awk -F',' '{print $2}' | tr -d '"' )  
    tmpFile=$(mktemp)
    echo ""
    for dom in $domains; do
	
	echo ">Users for domain; ${dom}, ${srcDir}/domain/${dom}/user_*.yaml "
	for USER in ${srcDir}/domain/${dom}/user_*.yaml; do
	    echo ">>$USER "
	    olddefproj=$(grep 'default_project_id:' ${USER} | awk '{print $2}')
	    username=$(grep 'name:' ${USER} | awk '{print $2}')
	    userdescr=$(grep 'description:' ${USER} | awk -F':' '{print $2}')
	    useremail=$(grep 'email:' ${USER} | awk -F':' '{print $2}')

	    

	    
	    openstack user show --domain ${dom} ${username} &> $tmpFile

	    echo -n "${username} (${dom})  |${userdescr}| "
	    if [[ "$dryRun" -eq 0 ]]; then
		if [[ "$olddefproj" ]]; then
		    oldProjName=$(grep ${olddefproj} ${srcDir}/projects.csv | awk -F',' '{print $2}' | sed -r 's/\"//g' )
		    if [[ $(grep 'No user ' $tmpFile) ]]; then
			echo ">openstack user create --domain ${dom} --project ${oldProjName} --email ${useremail} --description \"${userdescr}\"  --password ${useremail} ${username}"
			openstack user create --domain ${dom} --project ${oldProjName} --email ${useremail} --description "${userdescr}"  --password ${useremail} ${username}
		    else
			echo "$username ($dom) exists."
		    fi
		else
		    if [[ $(grep 'No user' $tmpFile) ]]; then
			echo "openstack user create --domain ${dom} --email ${useremail} --description \"${userdescr}\"  --password ${useremail} ${username}"
			openstack user create --domain ${dom} --email ${useremail} --description "${userdescr}"  --password ${useremail} ${username}
		    else
			echo " exists."
		    fi	
		fi
	    else
		echo " => Dry run."
		if [[ "$olddefproj" ]]; then
		    oldProjName=$(grep ${olddefproj} ${srcDir}/projects.csv | awk -F',' '{print $2}' | sed -r 's/\"//g' )
		    if [[ $(grep 'No user' $tmpFile) ]]; then
			echo "openstack user create --domain ${dom} --project ${oldProjName} --email ${useremail} --description ${userdescr}  --password ${useremail} ${username}"
		    else
			echo " exists."
		    fi	
		else
		    if [[ $(grep 'No user' $tmpFile) ]]; then
			echo "openstack user create --domain ${dom} --email ${useremail} --description ${userdescr}  --password ${useremail} ${username}"
		    else
			echo " exists."
		    fi
		fi
	    fi

	    
	done	
    done

    rm $tmpFile
}


restoreNetworks() {
    echo "<Networks>"

    networks=$(cat "${srcDir}/networks.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    networksString=$(cat "${srcDir}/networks.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "$networksString"
    echo ""
    tmpFile=$(mktemp)

    for netfile in ${srcDir}/networks/network_*.yaml; do
	echo "netfile = ${netfile} "
	netName=$(grep 'name:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')
	netDescr=$(grep 'description:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')
	netShare=$(grep 'shared:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')
	netRouterExt=$(grep 'router:external:' "${netfile}" | awk -F':' '{print $3}' | tr -d ' ')
	netProjID=$(grep 'project_id:' "${netfile}" | awk -F':' '{print $2}' | tr -d ' ')

	openstack network show  ${netName} &> $tmpFile
	
	if [[ "$netRouterExt" == *"External"* ]]; then
	    echo "This is an external network, it has been replaced. "
	else
	    oldProjName=$(grep ${netProjID} ${srcDir}/projects.csv | awk -F',' '{print $2}' | tr -d '"' )
	    oldDomainID=$(grep 'domain_id' ${srcDir}/projects/${netProjID}.yaml | awk -F':' '{print $2}' | tr -d '"' )
	    oldDomainName=$(grep ${oldDomainID} ${srcDir}/domains.csv | awk -F',' '{print $2}' | tr -d '"')

	    
	    echo -n "${netName} (${oldDomainName}) |${netDescr}| <${netProjID}>" 
	    if [[ "$dryRun" -eq 0 ]]; then
		 if [[ $(grep 'No Network' $tmpFile) ]]; then
		     echo ">openstack network create --no-share --project ${oldProjName} --project-domain ${oldDomainName} --description ${netDescr} ${netName}"
		     openstack network create --no-share --project ${oldProjName} --project-domain ${oldDomainName} --description ${netDescr} ${netName}
		 else
		     echo " exists."
		 fi
	    else
		echo " => Dry run."
		 if [[ $(grep 'No Network' $tmpFile) ]]; then
		     echo "openstack network create --no-share --project ${oldProjName} --project-domain ${oldDomainName} --description ${netDescr} ${netName}"
		 else
		     echo " exists."
		 fi
	    fi
	fi

    done
    rm $tmpFile
}


restoreSubnets() {
    echo "<Subnetworks>"


    tmpFile=$(mktemp)


    subnetworks=$(cat "${srcDir}/subnets.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    subnetworksString=$(cat "${srcDir}/subnets.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "$subnetworksString"

    for snet in ${srcDir}/subnets/subnet_*.yaml; do

	eval $(parse_yaml $snet "SUBN_")
	snetName=${SUBN_name}
	
	echo "Subnet ID = ${SUBN_id} => $snetName "

	oldProjName=$(grep ${SUBN_project_id} ${srcDir}/projects.csv | awk -F',' '{print $2}' | tr -d '"' )
	oldDomainID=$(grep 'domain_id' ${srcDir}/projects/${SUBN_project_id}.yaml | awk -F':' '{print $2}' | tr -d '"' )
	oldDomainName=$(grep ${oldDomainID} ${srcDir}/domains.csv | awk -F',' '{print $2}' | tr -d '"')

	oldNetworkName=$(grep ${SUBN_network_id} ${srcDir}/networks.csv | awk -F',' '{print $2}' | tr -d '"')

	dhcpString=""
	if [[ "${SUBN_enable_dhcp}" == "true" ]]; then
	    dhcpString="--dhcp"
	else
	    dhcpString="--no-dhcp"
	fi

	tagString=""
	for TAG in ${SUBN_tags}; do
	    tagString=$(echo "--tag $TAG $tagString")
	done

	HOSTROUTES=""
	if [[ ${SUBN_host_routes} ]]; then
	    echo "Routes present. Do something. "

	fi

	IP6RA=""
	IP6AM=""

	if [[ "${SUBN_ipv6_address_mode}" != *"null"* ]]; then
	    echo "IPV6 AM"
	    IP6AM="--ipv6-address-mode ${SUBN_ipv6_address_mode}"
	fi

	if [[ "${SUBN_ipv6_ra_mode}" != *"null"*  ]]; then
	    echo "IPV6 RM "
	    IP6RA="--ipv6-ra-mode ${SUBN_ipv6_ra_mode}"
	fi

	AP=""
	APstart=$(echo "${SUBN_allocation_pools}" | awk -F'-' '{print "start="$1}')
	APend=$(echo "${SUBN_allocation_pools}" | awk -F'-' '{print "end="$2}')
	AP=$(echo "$APstart,$APend")
	

	openstack subnet show ${snetName} &>$tmpFile

	echo "${snetName} (${oldProjName}) |$HOSTROUTES.$IPV6RA.$IP6AM.$AP|"
	if [[ "$dryRun" -eq 0 ]]; then
	    if [[ $(grep 'No Subnet' $tmpFile) ]]; then
		echo ">openstack subnet create --allocation-pool $AP --subnet-range ${SUBN_cidr} --description \"${SUBN_description}\"--dns-nameserver \"${SUBN_dns_nameservers}\" ${dhcpString} --gateway ${SUBN_gateway_ip} $HOSTROUTES --ip-version ${SUBN_ip_version} $IP6RA $IP6AM --network ${oldNetworkName} --project ${oldProjName} --project-domain ${oldDomainName} $tagString ${snetName} "
		
		openstack subnet create --allocation-pool $AP --subnet-range ${SUBN_cidr} --description "${SUBN_description}"\
			  --dns-nameserver "${SUBN_dns_nameservers}" ${dhcpString} --gateway ${SUBN_gateway_ip} \
			  $HOSTROUTES --ip-version ${SUBN_ip_version} $IP6RA $IP6AM \
			  --network ${oldNetworkName} --project ${oldProjName} \
			  --project-domain ${oldDomainName} $tagString ${snetName}
	    else
		echo " exists."
	    fi
	else
	    if [[ $(grep 'No Subnet' $tmpFile) ]]; then
		echo "openstack subnet create --allocation-pool $AP --subnet-range ${SUBN_cidr} --description '${SUBN_description}'"\
			  "--dns-nameserver '${SUBN_dns_nameservers}' ${dhcpString} --gateway ${SUBN_gateway_ip} ${snetName} " \
			  "$HOSTROUTES --ip-version ${SUBN_ip_version} $IP6RA $IP6AM " \
			  "--network ${oldNetworkName} --project ${oldProjName}" \
			  "--project-domain ${oldDomainName} $tagString ${snetName} "
	    else
		echo " exists."
	    fi
	fi
    done
    rm $tmpFile
}

restoreRouters(){
    echo "<Routers>"

    tmpFile=$(mktemp)
   
    routers=$(cat "${srcDir}/routers.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    routersString=$(cat "${srcDir}/routers.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "$routersString"

    renamedNetworks=""
    renamedRouters=""
    renamedRoutersID=""    
    renamedSubnets=""
    for router in ${srcDir}/routers/*.yaml; do

	eval $(parse_yaml $router "RT_")
	rtName=${RT_name}
	
	echo -n "Router ID = ${RT_id} => $rtName "

	if [[ "${rtName}" == "whiterouter" ]]; then
	    renamedRouters=$(echo "${renamedRouters} ${rtName}")
	    renamedRoutersID=$(echo "${renamedRoutersID} ${RT_id}")
	    rtName=$(echo "provider-router")
	    echo " (renaming) ${rtName} ."

	else
	    echo "."
	fi
	
	
	oldProjName=$(grep ${RT_project_id} ${srcDir}/projects.csv | awk -F',' '{print $2}' | tr -d '"' )
	oldDomainID=$(grep 'domain_id' ${srcDir}/projects/${RT_project_id}.yaml | awk -F':' '{print $2}' | tr -d '"' )
	oldDomainName=$(grep ${oldDomainID} ${srcDir}/domains.csv | awk -F',' '{print $2}' | tr -d '"')

	openstack router show $rtName &> $tmpFile

	distString=""
	if [[ "${RT_distributed}" == *"true"* ]]; then
	    distString="--distributed"
	else
	    distString="--centralized"
	fi
	distString="" ## Override v2.0/routers seems to not accept --distributed
	
	
	echo "${rtName} (${oldProjName}) |$HOSTROUTES.$IPV6RA.$IP6AM.$AP|"
	if [[ "$dryRun" -eq 0 ]]; then
	    if [[ $(grep 'No Router' $tmpFile) ]]; then
		echo ">openstack router create $distString --description \"${RT_description}\" --project ${oldProjName} --project-domain ${oldDomainName} ${rtName}"

		openstack router create $distString --description \"${RT_description}\" --project ${oldProjName} --project-domain ${oldDomainName} ${rtName}
		
		metaData=$(cat $router | awk "/external_gateway_info/{flag=1;print $1;next}/}'/{flag=0;print $1}flag" | sed "s/external_gateway_info: '//" |  tr '\n' ' ' | tr ',' '\n'| sed 's/^{"/"/g' | sed "s/}'//g")
		##This requires work to be _GENERIC_ 

		network_id=$(echo $metaData | grep 'network_id' | awk -F':' '{print $2}' | tr -d ' "' | sed 's/external_fixed_ips//g')
		subnet_id=$(echo $metaData | grep 'external_fixed_ip' | awk -F':' '{print $4}' | tr -d ' "' | sed 's/ip_address//g' )
		enable_snat=$(echo $metaData | grep 'enable_snat' | awk -F':' '{print $2}' | sed 's/external_fixed_ips//g' | tr -d '"')

		echo "metaData"
		echo "|$metaData|"
		echo "network_id = ${network_id} "
		echo "subnet_id = ${subnet_id} "
		echo "enable_snat = ${enable_snat} "

		
		snatString=""
		if [[ "${enable_snat}" == "true" ]]; then
		    snatString="--enable-snat"
		else
		    snatString="--disable-snat"
		fi

		networkName=""
		network_OldName=$(grep ${network_id} ${srcDir}/networks.csv | awk -F',' '{print $2}' | tr -d '" ')
		
		if [[ "${network_OldName}" == *"External-PublicNetwork"* ]]; then
		    networkName="ext_net"
		    renamedNetworks=$(echo "${renamedNetworks} ${network_OldName}")
		else
		    networkName=${network_OldName}
		fi
		
		echo ">openstack router set --external-gateway ${networkName} ${snatString} ${rtName}"
		openstack router set --external-gateway ${networkName} ${snatString} ${rtName}

		#This is the external subnet. Is it needed???
		# addsubnet=0;
		# if [[ -f ${srcDir}/subnets/subnet_${subnet_id}.yaml ]]; then
		#     subnetName=$(grep '^name' ${srcDir}/subnets/subnet_${subnet_id}.yaml | awk -F':' '{ print $2 }' )
		#     addsubnet=1;
		# else
		#     echo -e "\nMissing subnet description file, ${subnet_id}.\n"
		#     echo -e "${srcDir}/subnets/subnet_${subnet_id}.yaml \n";
		#     addsubnet=0;
		# fi
		# if [[ "${subnetName}" == *"ext_white_subnet"* ]]; then
		#     echo " (rename subnet)"
		#     renamedSubnets=$(echo "${renamedSubnets} ${subnetName}")
		#     subnetName=$(echo "ext");
		# fi
		
		# echo "subnetName = |${subnetName}|"		
		# if [[ $addsubnet -eq 1 ]]; then
		#     echo ">openstack router add subnet ${rtName} ${subnetName}"
		#     openstack router add subnet ${rtName} ${subnetName}
		# fi

		## Working on subnets to attach
		metaData=$(cat $router | awk "/interfaces_info/{flag=1;print $1;next}/}]'/{flag=0;print $1}flag" | awk "/interfaces_info/{flag=1;print $1;next}/}]'/{flag=0;print $1}flag" | sed "s/interfaces_info: '//" |  tr '\n' ' ' | tr ',' '\n'| sed 's/^{"/"/g' | sed "s/}'//g" | tr -d "[]{}'" | grep 'subnet_id' | tr -d '" ' | awk -F':' '{print $2}'  | uniq )

		echo "Adding subnets"
		echo "${metaData} "
		for info in "${metaData}"; do
		    if [[ -f ${srcDir}/subnets/subnet_${info}.yaml ]]; then
			subnetName=$(grep '^name' ${srcDir}/subnets/subnet_${info}.yaml | awk -F':' '{ print $2 }' )
			addsubnet=1;
		    else
			echo -e "\nMissing subnet description file, ${subnet_id}.\n"
			echo -e "${srcDir}/subnets/subnet_${subnet_id}.yaml \n";
			addsubnet=0;
		    fi
		    echo "subnetName = |${subnetName}|"
		
		    if [[ $addsubnet -eq 1 ]]; then
			echo ">openstack router add subnet ${rtName} ${subnetName}"
			openstack router add subnet ${rtName} ${subnetName}
		    fi
		done



		
	    else
		echo " exists."
	    fi
	else
	    if [[ $(grep 'No Router' $tmpFile) ]]; then
		echo "openstack router create $distString --description \"${RT_description}\" --project ${oldProjName} --project-domain ${oldDomainName} ${rtName}"
		
		
		metaData=$(cat $router | awk "/external_gateway_info/{flag=1;print $1;next}/}'/{flag=0;print $1}flag" | sed "s/external_gateway_info: '//" |  tr '\n' ' ' | tr ',' '\n'| sed 's/^{"/"/g' | sed "s/}'//g")
		##This requires work to be _GENERIC_ 

		network_id=$(echo $metaData | grep 'network_id' | awk -F':' '{print $2}' | tr -d ' "')
		subnet_id=$(echo $metaData | grep 'external_fixed_ip' | awk -F':' '{print $4}' | tr -d ' "' | sed 's/ip_address//g' )
		enable_snat=$(echo $metaData | grep 'enable_snat' | awk -F':' '{print $2}')
		
#		echo "|$metaData|"
#		echo "network_id = ${network_id} "
#		echo "subnet_id = ${subnet_id} "
#		echo "enable_snat = ${enable_snat} "

		
		snatString=""
		if [[ "${enable_snat}" == "true" ]]; then
		    snatString="--enable-snat"
		else
		    snatString="--disable-snat"
		fi

		networkName=""
		network_OldName=$(grep ${network_id} ${srcDir}/networks.csv | awk -F'|' '{print $2}' | tr -d ' ')
		
		if [[ "${network_OldName}" == "External-PublicNetwork" ]]; then
		    networkName="ext_net"
		    renamedNetworks=$(echo "${renamedNetworks} ${network_OldName}")
		else
		    networkName=${network_OldName}
		fi
		
		echo "openstack router set --external-gateway ${networkName} ${snatString} ${rtName}"
		#This is the external subnet. Is it needed???
		# addsubnet=0;
		# if [[ -f ${srcDir}/subnets/subnet_${subnet_id}.yaml ]]; then
		#     subnetName=$(grep '^name' ${srcDir}/subnets/subnet_${subnet_id}.yaml | awk -F':' '{ print $2 }' )
		#     addsubnet=1;
		# else
		#     echo -e "\nMissing subnet description file, ${subnet_id}.\n"
		#     echo -e "${srcDir}/subnets/subnet_${subnet_id}.yaml \n";
		#     addsubnet=0;
		# fi
		# if [[ "${subnetName}" == *"ext_white_subnet"* ]]; then
		#     echo " (rename subnet)"
		#     renamedSubnets=$(echo "${renamedSubnets} ${subnetName}")
		#     subnetName=$(echo "ext");
		# fi
		
		# echo "subnetName = |${subnetName}|"
		
		# if [[ $addsubnet -eq 1 ]]; then
		#     echo "openstack router add subnet ${rtName} ${subnetName}"
		# fi

		## Working on subnets to attach
		metaData=$(cat $router | awk "/interfaces_info/{flag=1;print $1;next}/}]'/{flag=0;print $1}flag" | awk "/interfaces_info/{flag=1;print $1;next}/}]'/{flag=0;print $1}flag" | sed "s/interfaces_info: '//" |  tr '\n' ' ' | tr ',' '\n'| sed 's/^{"/"/g' | sed "s/}'//g" | tr -d "[]{}'" | grep 'subnet_id' | tr -d '" ' | awk -F':' '{print $2}'  | uniq )

		echo "Adding subnets"
		echo "${metaData} "
		for info in "${metaData}"; do
		    if [[ -f ${srcDir}/subnets/subnet_${info}.yaml ]]; then
			subnetName=$(grep '^name' ${srcDir}/subnets/subnet_${info}.yaml | awk -F':' '{ print $2 }' )
			addsubnet=1;
		    else
			echo -e "\nMissing subnet description file, ${subnet_id}.\n"
			echo -e "${srcDir}/subnets/subnet_${subnet_id}.yaml \n";
			addsubnet=0;
		    fi
		    echo "subnetName = |${subnetName}|"
		
		    if [[ $addsubnet -eq 1 ]]; then
			echo "openstack router add subnet ${rtName} ${subnetName}"
		    fi
		done

		
	    else
		echo " exists."
	    fi
	fi	


	echo "  --next--"
    done


    
    echo "Renamed Routers :>"
    echo "$renamedRouters"
    echo "Renamed Networks :>"
    echo "$renamedNetworks"
    echo "Renamed Subnets :>"
    echo "$renamedSubnets"


    echo "Fixing the subnets attached to the routers that were renamed and existed."
    echo "These are the IDs: | $renamedRoutersID |"

    for routerID in "$renamedRoutersID"; do
	routerID=$(echo "$routerID" | tr -d ' ');
	echo "Working on ${srcDir}/routers/${routerID}.yaml"
	router=$(echo "${srcDir}/routers/${routerID}.yaml")
#	eval $(parse_yaml $router "RT_") ## Not needed as we only have ONE provider router. If multiple, it be different.
	rtName=$(echo "provider-router")
	
	echo "Router ID = ${RT_id} => $rtName "
	echo " routerID = $routerID "
	
    	## Working on subnets to attach
	metaData=$(cat $router | awk "/interfaces_info/{flag=1;print $1;next}/}]'/{flag=0;print $1}flag" | awk "/interfaces_info/{flag=1;print $1;next}/}]'/{flag=0;print $1}flag" | sed "s/interfaces_info: '//" |  tr '\n' ' ' | tr ',' '\n'| sed 's/^{"/"/g' | sed "s/}'//g" | tr -d "[]{}'" | grep 'subnet_id' | tr -d '" ' | awk -F':' '{print $2}'  | sort | uniq | tr '\n' ' ')
	
	echo "Adding subnets to $rtName"
	echo "${metaData} "
	for info in ${metaData}; do
	    addsubnet=0;
	    echo -n "$info"
	    if [[ -f ${srcDir}/subnets/subnet_${info}.yaml ]]; then
		subnetName=$(grep '^name' ${srcDir}/subnets/subnet_${info}.yaml | awk -F':' '{ print $2 }' )
		addsubnet=1;
	    else
		echo -e "\nMissing subnet description file, ${subnet_id}."
		echo -e "${srcDir}/subnets/subnet_${subnet_id}.yaml \n";
		addsubnet=0;
	    fi
	    echo -n " => ${subnetName}"
	    
	    if [[ $addsubnet -eq 1 ]]; then
		echo " adding."
		if [[ "$dryRun" -eq 0 ]]; then
		    echo ">openstack router add subnet ${rtName} ${subnetName}"
		    openstack router add subnet ${rtName} ${subnetName}
		else
		    echo "openstack router add subnet ${rtName} ${subnetName}"
		fi
	    fi
	done
    done
}



restoreSecGroups(){
    echo "Security Groups"


    sg=$(cat "${srcDir}/security_group.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgString=$(cat "${srcDir}/security_group.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
    echo "Security Groups = $sgString "

    tmpFile=$(mktemp)
    
    echo " processing "
    for SGROUP in ${srcDir}/security_groups/*.yaml; do

	echo "$SGROUP"
	echo ""
	eval $(parse_yaml $SGROUP "SG_")

	projectID=$(echo ${SG_project_id})
	oldProjName=$(grep ${projectID} ${srcDir}/projects.csv | awk -F',' '{print $2}' | tr -d '"' )
	if [[ "$dryRun" -eq 0 ]]; then

	    ##CHECK IF SECURIT GROUP + PROJECT exists. 
	    echo ">openstack security group create --project ${oldProjName} --tag autorestored -f yaml ${SG_name} | tee $tmpFile"
	    openstack security group create --project ${oldProjName} --tag autorestored -f yaml ${SG_name} | tee $tmpFile
	    
	    
	else
	    echo "openstack security group create --project ${oldProjName} --tag autorestored -f yaml ${SG_name} | tee $tmpFile"
	fi
	
	sgid=$(grep 'id:' $tmpFile | head -1 | awk -F':' '{print $2}' | tr -d ' ' )
	if [[ -z "$sgid" ]]; then
	    sgid="[DRYRUN]"
	fi
	
	rules=$(echo "${SG_rules}" | sed 's/created_at/\nRULE/g' )

	echo -e "$rules" | while read i; do
	    if [[ -z "$i" ]]; then 
#		echo "(empty)"
		continue;
	    fi
	    perLine=$(echo "$i" | tr ',' '\n')
#	    echo -e "=> $perLine"
	    direction=$(echo -e "$perLine" | grep 'direction' | awk -F'=' '{print $2}' | tr -d "'")
	    ethertype=$(echo -e "$perLine" | grep 'ethertype' | awk -F'=' '{print $2}' | tr -d "'")
	    portrangemax=$(echo -e "$perLine" | grep 'port_range_max' | awk -F'=' '{print $2}' | tr -d "'")
	    portrangemin=$(echo -e "$perLine" | grep 'port_range_min' | awk -F'=' '{print $2}' | tr -d "'")
	    protocol=$(echo -e "$perLine" | grep 'protocol' | awk -F'=' '{print $2}' | tr -d "'")
	    remoteipprefix=$(echo -e "$perLine" | grep 'remote_ip_prefix' | awk -F'=' '{print $2}' | tr -d "'")

#	    echo "direction = $direction"
#	    echo "ethertype = $ethertype "
#	    echo "prmax= $portrangemax"
#	    echo "prmin= $portrangemin"
#	    echo "Protocol = |$protocol|"
#	    echo "rpprfix = $remoteipprefix"
	    
	    dirString=""
	    if [[ "$direction" == *"egress"* ]]; then
		dirString="--egress"
	    else
		dirString="--ingress"
	    fi
	    
	    if [[ ! -z "$protocol" ]]; then
		if [[ "$dryRun" -eq 0 ]]; then
		    echo ">openstack security group rule create $dirString --project ${oldProjName} --protocol ${protocol} --dst-port \"${protrangemin}:${portrangemax}\" --remote-ip ${remoteipprefix} $sgid"
		    openstack security group rule create $dirString --project ${oldProjName} --protocol ${protocol} --dst-port \"${protrangemin}:${portrangemax}\" --remote-ip ${remoteipprefix} $sgid
		else
		    echo "openstack security group rule create $dirString --project ${oldProjName} --protocol ${protocol} --dst-port \"${protrangemin}:${portrangemax}\" --remote-ip ${remoteipprefix} $sgid"
		fi
		
	    else
		echo "Probably std. rule, not adding."
	    fi
	    
	done

	
	echo "-----------------"
	echo ""
    done

#    rm $tmpFile

}


saveVMs() {
    echo "VMs"

    mkdir -p ${srcDir}/vms
    mkdir -p $vmlocation/instance_disks
    
    sg=$(cat "${srcDir}/vm.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgString=$(cat "${srcDir}/vm.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
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
	   
	   projStr=$(grep $proj "${srcDir}/vm.csv" | awk -F',' '{print $2}' | tr -d '"')
	   #    echo "VM: $proj ($projStr) "
	   openstack server show -f yaml $proj > ${srcDir}/vms/$proj.yaml
	   vmname=$(grep name: ${srcDir}/vms/$proj.yaml | grep -v 'key_name' | grep -v 'OS-EXT' | awk '{print $2}')
	   vmstatus=$(grep status: ${srcDir}/vms/$proj.yaml)
	   volumes=$(grep volumes: ${srcDir}/vms/$proj.yaml)

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
		   echo "We already have a copy of that disk in ${srcDir}/instance_disks/${proj}.vdi"
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
#    mkdir -p ${srcDir}/instance_disks/
#
#    for cn in ${cnodes}; do
#	juju scp $cn:/tmp/instances/* ${srcDir}/instance_disks
#    done

}


restoreFlavor() {
    echo "Flavor --- Not restoring, replaced with new naming scheme."

    
    return
    openstack flavor list -f csv > ${srcDir}/flavor.csv

    sg=$(cat "${srcDir}/flavor.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgStr=$(cat "${srcDir}/flavor.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr -d '\n')
    echo "Flavors: $sgStr "
    echo "------------------------"

    mkdir -p ${srcDir}/flavor/
    for proj in $sg; do
        projStr=$(grep $proj "${srcDir}/flavor.csv" | awk -F',' '{print $2}' | tr -d '"')
        echo "SGR: $proj ($projStr)" 
        openstack flavor show -f yaml $proj > ${srcDir}/flavor/$proj.yaml
    done
}

restoreVolume(){
    echo "Volumes"
    # ## KOLLA UPP!!! 

    openstack volume list -f csv --all > ${srcDir}/volume.csv

    sg=$(cat "${srcDir}/volume.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgStr=$(cat "${srcDir}/volume.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr -d '\n')
    echo "Volume: $sgStr "
    echo "------------------------"

    mkdir -p ${srcDir}/volume/
    for proj in $sg; do
	projStr=$(grep $proj "${srcDir}/volume.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "Vol: $proj ($projStr)" 
	openstack volume show -f yaml $proj > ${srcDir}/volume/$proj.yaml

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
    cat ${srcDir}/image.csv

    #${srcDir}/images.csv
    #${srcDir}/image/
    #${srcDir}/image_folder/
    
    
    
    sg=$(cat "${srcDir}/image.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    sgStr=$(cat "${srcDir}/image.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr -d '\n')
    echo "Image: $sgStr "
    echo "------------------------"


    for proj in ${srcDir}/image/*.yaml; do

	projStr=$(grep $proj "${srcDir}/image.csv" | awk -F',' '{print $2}' | tr -d '"')
	echo "Image: $proj ($projStr)" 


	echo "openstack image add project --project-domain <image> <project>"
	
    done

}

restoreKeypair() {
    echo "Keypairs"
    echo "Will not restore keypairs, as we do not have them."
    
    return 
    domains=$(cat "${srcDir}/domains.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
    domainsString=$(cat "${srcDir}/domains.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')

    for dom in $domains; do
	domStr=$(grep $dom "${srcDir}/domains.csv" | awk -F',' '{print $2}' | tr -d '"' | tr ' ' '_')
	echo "Domain: $domStr ($dom)"
	
	
	users=$(openstack user list -f csv --domain $dom | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
	usersString=$(openstack user list -f csv --domain $dom | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
	echo "users = $usersString "

	for usr in $users; do
 	    usrStr=$(grep $usr "${srcDir}/domain/$domStr/users.csv" | awk -F',' '{print $2}' | tr -d '"')

	    mkdir -p ${srcDir}/keypair/$domStr/$usr
	    nova keypair-list --user $usr  > ${srcDir}/keypair/$domStr/kp_$usr.csv
	    
	    kpl=$(nova keypair-list --user $usr | sed 1,3d | grep '|' | awk '{print $2}')
	    echo "keypairs for $dom/$usr ($usrStr)"
	    echo "$kpl"
	    echo "------"
	    for keyid in $kpl; do
		echo -e "\t$keyid "
		nova keypair-show --user $usr $keyid  > ${srcDir}/keypair/$domStr/$usr/kp_$keyid.yaml
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
	domStr=$(grep $dom "${srcDir}/domains.csv" | awk -F',' '{print $2}' | tr -d '"'| tr ' ' '_')
	echo "Domain: $domStr ($dom)"
	openstack user list -f csv --domain $dom > ${srcDir}/domain/$domStr/users.csv
	users=$(cat "${srcDir}/domain/$domStr/users.csv" | sed 1,1d | awk -F',' '{print $1}' | tr -d '"')
	usersString=$(cat "${srcDir}/domain/$domStr/users.csv" | sed 1,1d | awk -F',' '{print $2}' | tr -d '"' | tr '\n' ' ')
	echo "users = $usersString "

	for usr in $users; do
	    usrStr=$(grep $usr "${srcDir}/domain/$domStr/users.csv" | awk -F',' '{print $2}' | tr -d '"')
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


#restoreDoms
#restoreProjects
#restoreUsers

#restoreKeypair

#restoreNetworks
#restoreSubnets
#restoreRouters
restoreSecGroups

#restoreFlavor

#restoreImages
#restoreVolumes



#restoreVMs




echo "Not created users"
echo $notCreatedUsers


echo "Ending"
