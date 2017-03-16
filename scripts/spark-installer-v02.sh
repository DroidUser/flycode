function download_file
{
    srcurl=$1;
    destfile=$2;
    overwrite=$3;

    if [ "$overwrite" = false ] && [ -e $destfile ]; then
        return;
    fi

    wget -O $destfile -q $srcurl;
}

function untar_file
{
    zippedfile=$1;
    unzipdir=$2;

    if [ -e $zippedfile ]; then
        tar -xf $zippedfile -C $unzipdir;
    fi
}

function test_is_headnode
{
    shorthostname=`hostname -s`
    if [[  $shorthostname == headnode* || $shorthostname == hn* ]]; then
        echo 1;
    else
        echo 0;
    fi
}

function test_is_datanode
{
    shorthostname=`hostname -s`
    if [[ $shorthostname == workernode* || $shorthostname == wn* ]]; then
        echo 1;
    else
        echo 0;
    fi
}

function test_is_zookeepernode
{
    shorthostname=`hostname -s`
    if [[ $shorthostname == zookeepernode* || $shorthostname == zk* ]]; then
        echo 1;
    else
        echo 0;
    fi
}

function test_is_first_datanode
{
    shorthostname=`hostname -s`
    if [[ $shorthostname == workernode0 || $shorthostname == wn0-* ]]; then
        echo 1;
    else
        echo 0;
    fi
}

#following functions are used to determine headnodes. 
#Returns fully qualified headnode names separated by comma by inspecting hdfs-site.xml.
#Returns empty string in case of errors.
function get_headnodes
{
    hdfssitepath=/etc/hadoop/conf/hdfs-site.xml
    nn1=$(sed -n '/<name>dfs.namenode.http-address.mycluster.nn1/,/<\/value>/p' $hdfssitepath)
    nn2=$(sed -n '/<name>dfs.namenode.http-address.mycluster.nn2/,/<\/value>/p' $hdfssitepath)

    nn1host=$(sed -n -e 's/.*<value>\(.*\)<\/value>.*/\1/p' <<< $nn1 | cut -d ':' -f 1)
    nn2host=$(sed -n -e 's/.*<value>\(.*\)<\/value>.*/\1/p' <<< $nn2 | cut -d ':' -f 1)

    nn1hostnumber=$(sed -n -e 's/hn\(.*\)-.*/\1/p' <<< $nn1host)
    nn2hostnumber=$(sed -n -e 's/hn\(.*\)-.*/\1/p' <<< $nn2host)

    #only if both headnode hostnames could be retrieved, hostnames will be returned
    #else nothing is returned
    if [[ ! -z $nn1host && ! -z $nn2host ]]
    then
        if (( $nn1hostnumber < $nn2hostnumber )); then
                        echo "$nn1host,$nn2host"
        else
                        echo "$nn2host,$nn1host"
        fi
    fi
}

function get_primary_headnode
{
        headnodes=`get_headnodes`
        echo "`(echo $headnodes | cut -d ',' -f 1)`"
}

function get_secondary_headnode
{
        headnodes=`get_headnodes`
        echo "`(echo $headnodes | cut -d ',' -f 2)`"
}

function get_primary_headnode_number
{
        primaryhn=`get_primary_headnode`
        echo "`(sed -n -e 's/hn\(.*\)-.*/\1/p' <<< $primaryhn)`"
}

function get_secondary_headnode_number
{
        secondaryhn=`get_secondary_headnode`
        echo "`(sed -n -e 's/hn\(.*\)-.*/\1/p' <<< $secondaryhn)`"
}

# Check if the current  host is headnode.
if [ `test_is_headnode` == 0 ]; then
  echo  "Spark on YARN only need to be installed on headnode, exiting ..."
  exit 0
fi

# In case Spark is installed, exit.
if [ -e /usr/hdp/current/spark ]; then
    echo "Spark is already installed, exiting ..."
    exit 0
fi

#Determine Hortonworks Data Platform version
HDP_VERSION=`ls /usr/hdp/ -I current`

# Download Spark binary to temporary location.
download_file http://d3kbcqa49mib13.cloudfront.net/spark-1.4.1-bin-hadoop2.6.tgz /tmp/spark-1.4.1-bin-hadoop2.6.tgz

# Untar the Spark binary and move it to proper location.
untar_file /tmp/spark-1.4.1-bin-hadoop2.6.tgz /usr/hdp/current
mv /usr/hdp/current/spark-1.4.1-bin-hadoop2.6 /usr/hdp/${HDP_VERSION}/spark

# Remove the temporary file downloaded.
rm -f /tmp/spark-1.4.1-bin-hadoop2.6.tgz

# Update/link files/variables necessary to make Spark work on HDInsight.

ln -s /usr/hdp/${HDP_VERSION}/spark /usr/hdp/current/spark-client
ln -s /usr/hdp/${HDP_VERSION}/spark /usr/hdp/current/spark-thriftserver
ln -s /usr/hdp/${HDP_VERSION}/spark /usr/hdp/current/spark-historyserver

ln -s /etc/hive/conf/hive-site.xml /usr/hdp/${HDP_VERSION}/spark/conf

#Assign java options to support Spark
SparkDriverJavaOpts="spark.driver.extraJavaOptions -Dhdp.version=$HDP_VERSION"
SparkYarnJavaOpts="spark.yarn.am.extraJavaOptions -Dhdp.version=$HDP_VERSION"

#Create file and update with default values
SparkDefaults="/tmp/spark-defaults.conf"
echo $SparkDriverJavaOpts >> $SparkDefaults
echo $SparkYarnJavaOpts >> $SparkDefaults
touch $SparkDefaults

#Move to final destination
mv $SparkDefaults /usr/hdp/${HDP_VERSION}/spark/conf/spark-defaults.conf
