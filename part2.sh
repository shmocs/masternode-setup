#!/bin/bash

# Args: $1    $2    $3    $4    $5        $6
#       alias ip    key   txid  tx_index  consent
# example: ./part2.sh mn1 207.145.65.77 5JJaWW...4nrjej4 8b703r5...edddgdr4 0 yes

# When called by AsGard - consent is already provided according to Terms&Conditions
# When run as individual setup - ask for the permission
report_consent=$6

confFile=~/.snowgem/snowgem.conf
#confFile="file.txt"
#mnFile=~/.snowgem/masternode.conf
#mnFile="mn.txt"

# Asgard common script
mncommon="/root/oneclick/mn-common.sh"

# Include Asgard common script
source $mncommon

killall -9 snowgemd

cd ~
if [ ! -d ~/.snowgem ]; then
  mkdir .snowgem
fi

rm $confFile
#rm $mnFile

if [ ! -f $confFile ]; then
  touch $confFile
  #touch $mnFile

  #write data
  rpcuser=$(gpw 1 30)
  echo "rpcuser="$rpcuser >> $confFile
  rpcpassword=$(gpw 1 30)
  echo "rpcpassword="$rpcpassword >> $confFile
  echo "addnode=explorer.snowgem.org" >> $confFile
  echo "addnode=insight.snowgem.org" >> $confFile
  echo "addnode=dnsseed1.snowgem.org" >> $confFile
  echo "addnode=dnsseed2.snowgem.org" >> $confFile
  echo "addnode=dnsseed3.snowgem.org" >> $confFile
  echo "rpcport=16112" >> $confFile
  echo "port=16113" >> $confFile
  echo "listen=1" >> $confFile
  echo "server=1" >> $confFile
  echo "txindex=1" >> $confFile
  if echo $2 | grep ":16113" ; then
    echo "masternodeaddr=[$2]" >> $confFile
    echo "externalip=[$2]" >> $confFile
  else
    echo "masternodeaddr=[$2]:16113" >> $confFile
    echo "externalip=[$2]:16113" >> $confFile
  fi
  echo "masternodeprivkey="$3 >> $confFile
  echo "masternode=1" >> $confFile

  #if echo $2 | grep ":16113" ; then
  #  echo $1 $2 $3 $4 $5 >> $mnFile
  #else
  #  echo $1 $2":16113" $3 $4 $5 >> $mnFile
  #fi
fi

if [ -d ~/.snowgem-params ]; then
  rm ~/.snowgem-params -r
fi

if [ -d ~/snowgem-wallet ]; then
  rm ./snowgem-wallet -r
fi

chmod +x ~/masternode-setup/fetch-params.sh

cd ~

report_asgard_progress 'Fetching params ...' 70

./masternode-setup/fetch-params.sh

wget -N https://github.com/Snowgem/Snowgem/releases/download/v3000456-20190726/snowgem-ubuntu16.04-3000456-20190728.zip -O ~/binary.zip
unzip -o ~/binary.zip -d ~

report_asgard_progress 'Downloading chain data ...' 80

#if [ ! -d ~/.snowgem/blocks ]; then
#  wget -N https://github.com/Snowgem/Data/releases/download/0.0.1/blockchain_snowgem_index.zip.sf-part1 -O ~/bc.sf-part1
#  report_asgard_progress 'Downloading chain data ...' 82
#  wget -N https://github.com/Snowgem/Data/releases/download/0.0.1/blockchain_snowgem_index.zip.sf-part2 -O ~/bc.sf-part2
#  report_asgard_progress 'Downloading chain data ...' 84
#  wget -N https://github.com/Snowgem/Data/releases/download/0.0.1/blockchain_snowgem_index.zip.sf-part3 -O ~/bc.sf-part3
#  report_asgard_progress 'Downloading chain data ...' 86
#  wget -N https://github.com/Snowgem/Data/releases/download/0.0.1/blockchain_snowgem_index.zip.sf-part4 -O ~/bc.sf-part4
#  cd ~
#  cat *.*part* > blockchain.zip
#  rm ~/bc.sf-part1
#  rm ~/bc.sf-part2
#  rm ~/bc.sf-part3
#  rm ~/bc.sf-part4
#  report_asgard_progress 'Unpacking data ...' 88
#  unzip -o ~/blockchain.zip -d ~/.snowgem
#  rm ~/blockchain.zip
#fi

if [ ! -d ~/.snowgem/blocks ]; then
  wget -N https://files.equihub.pro/snowgem/blockchain_index.zip
  cd ~
  report_asgard_progress 'Unpacking data ...' 88
  unzip -o ~/blockchain_index.zip -d ~/.snowgem
  rm ~/blockchain_index.zip
fi

chmod +x ~/snowgemd ~/snowgem-cli

#start

report_asgard_progress 'Starting services ...' 90

./snowgemd -daemon
systemctl enable --now snowgem.service
sleep 5
x=1
echo "Wait for starting"
sleep 15
while true ; do
    echo "Wallet is opening, please wait. This step will take few minutes ($x)"
    sleep 1
    x=$(( $x + 1 ))
    ./snowgem-cli getinfo &> text.txt
    line=$(tail -n 1 text.txt)
    if [[ $line == *"..."* ]]; then
        echo $line
    fi
    if [[ $(tail -n 1 text.txt) == *"sure server is running"* ]]; then
        echo "Cannot start wallet, please contact us on Discord(https://discord.gg/7a7XRZr) for help"
        break
    elif [[ $(head -n 20 text.txt) == *"version"*  ]]; then
        echo "Checking masternode status"
        while true ; do
            echo "Please wait ($x)"
            sleep 1
            x=$(( $x + 1 ))
            ./snowgem-cli masternodedebug &> text.txt
            line=$(head -n 1 text.txt)
            echo $line
            if [[ $line == *"not yet activated"* ]]; then
                ./snowgem-cli masternodedebug
                break
            fi
        done
        ./snowgem-cli getinfo
        ./snowgem-cli masternodedebug
        break
    fi
done

report=0
if [ "$report_consent" == "yes" ] ; then
    report=1
else
    echo -n "Agree with reporting MN ip+version to AsGard to help providing better stats for the network? [y/n] "; read yn
    case $yn in
        y|Y|YES|yes|Yes)
            report=1
            ;;
    esac
fi

if [ "$report" -eq 1 ] ; then
    bash ~/masternode-setup/report-version.sh
fi
