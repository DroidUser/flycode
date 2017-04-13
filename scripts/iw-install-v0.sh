#!/bin/bash
#source ~/.bashrc

export p1=$1
export p2=$2
export p3=$3
export p4=$4
export p5=$5
export p6=$6

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

_init(){

	#download secret file
	_download_file $p6 secret.txt

	#extract key
	value=$(<secret.txt)
	rm -rf secret.txt
	
	echo "[$(_timestamp)]: secret=$value"
	
	#download script file using key
	_download_file https://iwteststorage.blob.core.windows.net/action-scripts-infoworks/sub_script.sh?st=2017-04-13T08%3A30%3A00Z&se=2020-04-13T08%3A30%3A00Z&sp=rl&sv=2015-12-11&sr=c&sig=${value} sub_script.sh

	#run the script
	eval /bin/bash sub_script.sh $p1 $p2 $p3 $p4 $p5
}

_init
