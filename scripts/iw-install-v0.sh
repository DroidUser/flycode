export k1=$1
export k2=$2
export k3=$3
export k4=$4
export username=infoworks-user
export password=$5
export saskey=$6

printf "got parameters k1=%s k2=%s k3=%s k4=%s password=%s url=%s" "$k1" "$k2" "$k3" "$k4" "$password" "$saskey"

wget "${saskey}.sh"
