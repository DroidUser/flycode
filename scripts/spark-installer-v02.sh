#!/usr/bin/env bash

# Import the helper method module.
wget -O /tmp/HDInsightUtilities-v01.sh -q https://hdiconfigactions.blob.core.windows.net/linuxconfigactionmodulev01/HDInsightUtilities-v01.sh && source /tmp/HDInsightUtilities-v01.sh && rm -f /tmp/HDInsightUtilities-v01.sh

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

# Download Spark binary to temporary location.
download_file http://d3kbcqa49mib13.cloudfront.net/spark-2.0.0-bin-hadoop2.7.tgz /tmp/spark-2.0.0-bin-hadoop2.7.tgz

# Untar the Spark binary and move it to proper location.
untar_file /tmp/spark-2.0.0-bin-hadoop2.7.tgz /usr/hdp/current
mv /usr/hdp/current/spark-2.0.0-bin-hadoop2.7 /usr/hdp/current/spark

# Remove the temporary file downloaded.
rm -f /tmp/spark-2.0.0-bin-hadoop2.7.tgz

# Override necessary files to make Spark work on HDInsight.
download_file https://hdiconfigactions.blob.core.windows.net/linuxsparkconfigactionv02/spark-defaults.conf /usr/hdp/current/spark/conf/spark-defaults.conf
hdpversion=$(ls /usr/hdp | egrep ^[-.0-9]+)
sed -i "s|HDPVERSIONPLACEHOLDER|$hdpversion|g" /usr/hdp/current/spark/conf/spark-defaults.conf

# Add HADOOP environment variable into machine level configuration.
echo "HADOOP_CONF_DIR=/etc/hadoop/conf" | sudo tee -a /etc/environment
echo "YARN_CONF_DIR=/etc/hadoop/conf" | sudo tee -a /etc/environment
echo "SPARK_DIST_CLASSPATH=$(hadoop classpath)" | sudo tee -a /etc/environment
ln -s /etc/hive/conf/hive-site.xml /usr/hdp/current/spark/conf

# Updating existing symbolic links and cleanup existing spark binaries
rm -r /usr/bin/pyspark
rm -r /usr/bin/spark-class
rm -r /usr/bin/spark-shell
rm -r /usr/bin/spark-sql
rm -r /usr/bin/spark-submit
rm -rf /usr/hdp/current/spark-client

# Updating PATH with spark bin
NEWPATH=$PATH:/usr/hdp/current/spark/bin
sed -i "s|^PATH=.*|PATH=\"$NEWPATH\"|g" /etc/environment
