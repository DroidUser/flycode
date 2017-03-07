#!/bin/bash
#source ~/.bashrc

app_path=https://github.com/rgupta2508/azure-hdinsight/archive/master.zip
app_name=infoworks
iw_home=/opt/${app_name}
username=infoworks-user
password=welcome@123

create_user(){

	echo "[$(date +"%m-%d-%Y %T")] Creating user $username"
	{
		#check whether the cmd is run by root
		if [ $(whoami) = "root" ]; then
			egrep "^$username" /etc/passwd >/dev/null
			if [ $? -eq 0 ]; then
				echo "$username exists!"
			else
				useradd -m -p $password $username
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

	echo "Extracting infoworks package"
	if [ -f $1 ] ; then
	 case $1 in
	     *.tar.gz)    tar xvzf $1 -C ${app_name} ;;
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
                    eval $return_var="'$default_value'"
            fi

        fi
    done
}
export -f _get_namenode_hostname


_get_hive_server_hostname(){
    return_var=$1
    default=$2

    _get_namenode_hostname $return_var $default

    $return_var="hive2://$return_var:10000"

    if [ "${!return_var}" == "" ]; then
        eval $return_var="hive2://'$default':10000"
    fi
}
export -f _get_hive_server_hostname


_get_spark_server_hostname(){
    return_var=$1
    default=$2

    _get_namenode_hostname $return_var $default

    $return_var="spark://$return_var:7077"

    if [ "${!return_var}" == "" ]; then
        eval $return_var="spark://'$default':7077"
    fi
}
export -f _get_spark_server_hostname


deploy_app(){

	echo "[$(date +"%m-%d-%Y %T")] Started deployment"
	sudo -u $username sh $iw_home/bin/start.sh all

	expect "HDP installed"
	send "\n"

	expect "namenode"
	_get_namenode_hostname namenode_hostname `hostname -f`
	send $namenode_hostname

	expect "infoworks hdfs home"
	send "\n"

	expect "HiveServer2"
	_get_hive_server_hostname hiveserver_hostname `hostname -f`
	send $hiveserver_hostname

	expect "username"
	send "\n"

	expect "password"
	send "\n"

	expect "hive schema"
	send "\n"

	expect "Spark master"
	_get_spark_server_hostname sparkmaster_hostname `hostname -f`
	send $sparkmaster_hostname

	expect "Infoworks UI"
	send "\n"

	if [ "$?" != "0" ]; then
		return 1;
	fi
}

#install expect tool for interactive mode to input paramenters
apt-get install expect
[ $? != "0" ] && echo "Could not install 'expect' plugin" && exit 
eval create_user && download_app && deploy_app && echo "Application deployed successfully"  || echo "Deployment failed"
