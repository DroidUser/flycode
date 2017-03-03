#! /bin/bash
echo "Empty node setup"
TMPFOLDER=/tmp/hue

rm -rf $TMPFOLDER
mkdir -p $TMPFOLDER
echo "Downloading Hue tar file"
wget https://s3.amazonaws.com/infoworks-setup/tmp/infoworks-testing.tar.gz -P $TMPFOLDER
#sudo echo "Empty node setup" > /opt/welcome-su.txt
#sudo apt-get install subversion
