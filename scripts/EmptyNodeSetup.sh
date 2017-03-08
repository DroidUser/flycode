#!/bin/bash
#source ~/.bashrc
export app_path=http://54.221.70.148:8081/artifactory/infoworks-release/io/infoworks/release/1.9.1-azure/infoworks-1.9.1-azure.tar.gz
export app_name=infoworks
export iw_home=/opt/${app_name}
export configured_status_file=configured
export username=infoworks-user
export password=welcome
create_user(){

	echo "[$(date +"%m-%d-%Y %T")] Creating user $username"
	{
		#check whether the cmd is run by root
		if [ $(whoami) = "root" ]; then
			egrep "^$username" /etc/passwd >/dev/null
			if [ $? -eq 0 ]; then
				echo "$username exists!"
			else
				pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
				useradd -m -p $pass $username
				[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
			fi
			usermod -aG sudo $username || echo "Could not give sudo permission to $username"
			
		else
			echo "Only root may add a user to the system"
			return 1
		fi

	} || {
		echo 'Could not add user $username' && return 1
	}
}

extract(){

	echo "Extracting infoworks package $1"
	if [ -f $1 ] ; then
	 case $1 in
	     *.tar.gz)    tar -xzf $1 ;;
	     *.zip)       unzip $1 -d ${app_name} ;;
	     *)           echo "'$1' cannot be extracted" ;;
	 esac
	else
	 echo "'$1' is not a valid file"
	fi
}

download_app(){

	echo "[$(date +"%m-%d-%Y %T")] Started downloading application from "${app_path}
	{
		eval cd /opt/ && wget ${app_path} && {
			for i in `ls -a`; do
				if [[ ($app_path =~ .*$i.*) && -f $i ]]; then
					extract $i;
				fi
			done
		} || return 1;

		eval chown -R $username:$username ${app_name} || echo "Could not change ownership of infoworks package"

	} || {
		echo "Could not download the package" && return 1
	}
}

_get_namenode_hostname(){

    return_var=$1
    default=$2

    haClusterName=`hdfs getconf -confKey dfs.nameservices`

    if [ $? -ne 0 -o -z "$haClusterName" ]; then
        echo "Unable to fetch HA ClusterName"
        exit 1
    fi

    nameNodeIdString=`hdfs getconf -confKey dfs.ha.namenodes.$haClusterName`


    for nameNodeId in `echo $nameNodeIdString | tr "," " "`
    do
        status=`hdfs haadmin -getServiceState $nameNodeId`
        if [ $status = "active" ]; then
            nameNode=`hdfs getconf -confKey dfs.namenode.https-address.$haClusterName.$nameNodeId`
            IFS=':' read -ra $return_var<<< "$nameNode"
            if [ "${!return_var}" == "" ]; then
                    eval $return_var="'$default'"
            fi

        fi
    done
}
export -f _get_namenode_hostname


_get_hive_server_hostname(){
    return_var=$1
    default=$2

    _get_namenode_hostname hive_var $default

    $return_var="hive2://$hive_var:10000"

    if [ "${!return_var}" == "" ]; then
        eval $return_var="hive2://'$default':10000"
    fi
}
export -f _get_hive_server_hostname


_get_spark_server_hostname(){
    return_var=$1
    default=$2

    _get_namenode_hostname spark_var $default

    $return_var="spark://$spark_var:7077"

    if [ "${!return_var}" == "" ]; then
        eval $return_var="spark://'$default':7077"
    fi
}
export -f _get_spark_server_hostname


deploy_app(){

	echo "[$(date +"%m-%d-%Y %T")] Started deployment"i
        _get_namenode_hostname namenode_hostname `hostname -f`
	hiveserver_hostname="hive2://$namenode_hostname:10000"
	sparkmaster_hostname="spark://$namenode_hostname:7077"

	expect <<-EOF
	spawn su -c "$iw_home/bin/start.sh all" -s /bin/sh $username

	expect "HDP installed"
	sleep 1
	send "\n"

	expect "namenode"
        sleep 1
	send $namenode_hostname\n

	expect "Enter the path for infoworks hdfs home"
        sleep 1
	send "\n"

	expect "HiveServer2"
        sleep 1
	send $hiveserver_hostname\n

	expect "username"
        sleep 1
	send "\n"

	expect "password"
        sleep 1
	send "\n"

	expect "hive schema"
        sleep 1
	send "\n"

	expect "Spark master"
        sleep 1
	send $sparkmaster_hostname\n

	expect "Infoworks UI"
        sleep 1
	send "\n"

	interact
	EOF
	if [ "$?" != "0" ]; then
		return 1;
	fi
}
export -f deploy_app
#install expect tool for interactive mode to input paramenters
apt-get --assume-yes install expect
#[ $? != "0" ] && echo "Could not install 'expect' plugin" && exit 
eval create_user && download_app && deploy_app && [ -f $configured_status_file ] && echo "Application deployed successfully"  || echo "Deployment failed"
