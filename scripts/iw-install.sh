#!/bin/bash
#source ~/.bashrc

export p1=$1
export p2=$2
export p3=$3
export p4=$4
export p5=$5
export p6=$6

export iwSecretFile="iw-key.txt"
export edgeNodeSetup="edge-node-setup.sh"
export sparkInstall="spark-install.sh"

_timestamp(){
	date +%H:%M:%S
}

_download_file()
{
    srcurl=$1;
    destfile=$2;

    if [ -e $destfile ]; then
        return;
    fi
    echo "[$(_timestamp)]: downloading $1"
    wget -O $destfile -q $srcurl;
    echo "[$(_timestamp)]: downloaded $1 successfully"
}

_test_is_edgenode()
{
    short_hostname=`hostname -s`
    if [[ $short_hostname == edgenode* || $short_hostname == ed* ]]; then
        echo 1;
    else
        echo 0;
    fi
}

_init(){

	#download secret file
	_download_file $p6 /tmp/${iwSecretFile}

	#extract key
	value=$(</tmp/${iwSecretFile})

	#download script file using key
	_download_file 'https://iwteststorage.blob.core.windows.net/action-scripts-infoworks/'${edgeNodeSetup}'?st=2017-04-13T08%3A30%3A00Z&se=2020-04-13T08%3A30%3A00Z&sp=rl&sv=2015-12-11&sr=c&sig='${value} '/tmp/${edgeNodeSetup}'
	_download_file 'https://iwteststorage.blob.core.windows.net/action-scripts-infoworks/'${sparkInstall}'?st=2017-04-13T08%3A30%3A00Z&se=2020-04-13T08%3A30%3A00Z&sp=rl&sv=2015-12-11&sr=c&sig='${value} '/tmp/${sparkInstall}'

	#run the script
	eval /bin/bash /tmp/${sparkInstall} $1 $2 $3

	if [ _test_is_edgenode ]; then
		eval /bin/bash /tmp/${edgeNodeSetup} $1 $2 $3 $4 $5
	fi

	rm -rf /tmp/${sparkInstall}
	rm -rf /tmp/${edgeNodeSetup}
	rm -rf /tmp/${sparkInstall}
}

_init