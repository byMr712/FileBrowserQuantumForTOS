#TOS_KERNEL=$(uname -r)
MOUNT=/bin/mount
UMOUNT=/bin/umount
 len=${#depend[*]}  # it returns the dependay length
 

function V() # $1-a $2-op $3-$b
# Compare a and b as version strings. Rules:
# R1: a and b : dot-separated sequence of items. Items are numeric. The last item can optionally end with letters, i.e., 2.5 or 2.5a.
# R2: Zeros are automatically inserted to compare the same number of items, i.e., 1.0 < 1.0.1 means 1.0.0 < 1.0.1 => yes.
# R3: op can be '=' '==' '!=' '<' '<=' '>' '>=' (lexicographic).
# R4: Unrestricted number of digits of any item, i.e., 3.0003 > 3.0000004.
# R5: Unrestricted number of items.
{
  local a=$1 op=$2 b=$3 al=${1##*.} bl=${3##*.}
  while [[ $al =~ ^[[:digit:]] ]]; do al=${al:1}; done
  while [[ $bl =~ ^[[:digit:]] ]]; do bl=${bl:1}; done
  local ai=${a%$al} bi=${b%$bl}


  local ap=${ai//[[:digit:]]} bp=${bi//[[:digit:]]}
  ap=${ap//./.0} bp=${bp//./.0}
  
  local w=1 fmt=$a.$b x IFS=.
  for x in $fmt; do [ ${#x} -gt $w ] && w=${#x}; done
  fmt=${*//[^.]}; fmt=${fmt//./%${w}s}
  printf -v a $fmt $ai$bp; printf -v a "%s-%${w}s" $a $al
  printf -v b $fmt $bi$ap; printf -v b "%s-%${w}s" $b $bl
  case $op in
    '<='|'>=' ) [ "$a" ${op:0:1} "$b" ] || [ "$a" = "$b" ] ;;
    * )         [ "$a" $op "$b" ] ;;
  esac
}

log_success_msg()
  {
    echo " SUCCESS! $@" >> $LOGFILE 2>&1
  }
log_failure_msg()
  {
    echo " ERROR! $@" >> $LOGFILE 2>&1
  }


init_config_folder(){
	LOGFILE=/usr/local/${MOD_NAME}/${MOD_NAME}_start.log
	if [ -f $LOGFILE ];then
     if [ $(($(stat -c %s $LOGFILE)/1024)) -gt 1000 ]; then
      rm -f "$LOGFILE" > /dev/null 2>&1
     fi
    fi

	ROOTUSER=`id -un`

   	if [ ! -d /usr/local/@APP_CONFIG ];then
	mkdir -p /usr/local/@APP_CONFIG	 
	fi
	
	if [ "$(stat --format '%a' "/usr/local/@APP_CONFIG")" != "755" ];then
     chmod 755 /usr/local/@APP_CONFIG
    fi
	
	MODCONFIGHOME="/home/$ROOTUSER/MOD_CONFIG"
	MODCONFIG="/usr/local/@APP_CONFIG"
	[ ! -d $MODCONFIGHOME ] && mkdir -p $MODCONFIGHOME
	
	for i in {1..3}
	do
		if [ ! -z "$($MOUNT | grep /usr/local/@APP_CONFIG | grep /dev/md9)" ];then
		   $UMOUNT /usr/local/@APP_CONFIG
        fi
	done
		
	if [ -z "$($MOUNT | grep /usr/local/@APP_CONFIG)" ];then
    $MOUNT --bind $MODCONFIGHOME /usr/local/@APP_CONFIG
    fi
	
	if [ -z "$($MOUNT | grep /usr/local/@APP_CONFIG | grep /dev/mapper)" ];then
    echo "$(date +"%d/%m/%y %T") not possible to mount correctly the config folder" >> $LOGFILE 2>&1
	exit 1
    fi
}

checkdep(){
	i=0
	while [ $i -lt $len ]
		do
		APP=`echo ${depend[$i]} | awk -F "=" '{printf$1}'`	
		VER=`echo ${depend[$i]} | awk -F "=" '{printf$2}'`
		
		if [ ! -z $APP ];then 
		
			if [ -f /usr/local/$APP/config.ini ];then
				INSVER=`awk -F ':' '{a=1}a==1&&$1~/"version"/{print $2;exit}' /usr/local/$APP/config.ini | cut -d'"' -f 2`
				else
				echo "$APP app is not installed"
				exit 1
			fi
		fi
		if [ ! -z $VER ];then 
		 if V $INSVER '>=' $VER ; then
			echo "" > /dev/null 2>&1
			else
			echo "you must install $APP at least version $VER"
			exit 1
		 fi
		fi
		i=$((i+1))  
	 done
echo "All dependencies apps are installed"
}

GetHomeVolume(){
	VOLCONF=$(DEV=$(df-json | grep -E '(^|\s)/home($|\s)' | grep /dev/map | awk '{print $1}') && $MOUNT | grep $DEV | grep -E '(^|\s)/Volume.($|\s)' | awk '{print $3}')
	#VOLCONF=${name:1}
}

get_vol_name(){
	GetHomeVolume
	ROOTUSER=`id -un`
	echo -e "<?php\n\$SUPERUSER = '$ROOTUSER';\n\$WEBPATH = '$ROOTFOLDER';\n?>" > /usr/local/${MOD_NAME}/bin/config.inc.php
	[ -z $VOLCONF ]  && echo "$(date +"%d/%m/%y %T") No volume found, will exit" >> $LOGFILE 2>&1 && exit 1 || echo "$(date +"%d/%m/%y %T") Will use $VOLCONF to store config files"  >> $LOGFILE 2>&1
}

init_cert(){
	CERT_PATH=/etc/ssl/certs
	CERTFILE=$CERT_PATH/cacert.pem
	
	
if [[ $(find "$CERTFILE" -mtime +30 -print) ]]; then
	ter_curl -k --etag-compare $CERT_PATH/etag.txt --etag-save $CERT_PATH/etag.txt -o $CERT_PATH/cacert.pem --remote-name https://curl.se/ca/cacert.pem > /dev/null 2>&1
fi

if [ ! -f $CERTFILE ];then
    wget --no-check-certificate https://curl.haxx.se/ca/cacert.pem -O $CERTFILE > /dev/null 2>&1
fi

	ln -sf /etc/ssl/certs/cacert.pem /etc/ssl/certs/ca-certificates.crt
	ln -sf /etc/ssl/certs/cacert.pem /etc/ssl/certs/ca-bundle.crt
	
	if [ -d /usr/local/${MOD_NAME}/sys/ssl ];then
	  [ ! -L /usr/local/${MOD_NAME}/sys/ssl/cert.pem ] && ln -sf /etc/ssl/certs/cacert.pem /usr/local/${MOD_NAME}/sys/ssl/cert.pem > /dev/null 2>&1
    fi
}

GetTOSVersion(){
TOSMVERS=$(cat /usr/lib/version | cut -d '_' -f 3 | cut -d '.' -f 1)

}

AddUser(){
	local username=$1
	local addgroupname=$2
	id "$username" &> /dev/null
    [ $? -ne 0 ] && useradd -U -M -c "TOS App User" "$username" -G "allusers"
	
	if [ ! -z $addgroupname ];then	
	 if [ $(getent group $addgroupname) ]; then
		 id "$username" | grep "($addgroupname)" >/dev/null
		 [ $? -ne 0 ] && usermod -aG $addgroupname "$username"
		 else
		 groupadd $addgroupname && usermod -aG $addgroupname "$username"
	 fi
	fi
}

AddConfigFolder(){

GetTOSVersion

echo "$(date +"%d/%m/%y %T") We are on TOS version "$TOSMVERS""

if [ "$TOSMVERS" -lt "7" ]; then


	MODCONFIGPATH=/usr/local/@APP_CONFIG/${MOD_NAME}
	MODCONFIGPATHHOME=$MODCONFIGHOME/${MOD_NAME}
	
  if ([ -d $MODCONFIGPATH ] && [ ! -L $MODCONFIGPATH ]);then
    echo "$(date +"%d/%m/%y %T ")Config folder exist at $MODCONFIGPATH"
  else
	if [ -L $MODCONFIGPATH ];then
	  OLDPATH="$(readlink -- "$MODCONFIGPATH")"
	  if [ -d $OLDPATH ];then
	  echo "$(date +"%d/%m/%y %T ") Config found at $OLDPATH, will be moved to $MODCONFIGPATHHOME" 
	    rm -f $MODCONFIGPATH
		cp -af $OLDPATH/. $MODCONFIGPATH
		rm -rf $OLDPATH
	  else
		rm -f $MODCONFIGPATH
		mkdir -p $MODCONFIGPATH
	  fi
	elif [[ -d "/Volume1/MOD_CONFIG/${MOD_NAME}" && ! -L "/Volume1/MOD_CONFIG/${MOD_NAME}" ]];then
	  echo "$(date +"%d/%m/%y %T") Config found at /Volume1/MOD_CONFIG/${MOD_NAME}, will be moved to $MODCONFIGPATHHOME"
	  mv /Volume1/MOD_CONFIG/${MOD_NAME} $MODCONFIG
	elif [ -L "/Volume1/MOD_CONFIG/${MOD_NAME}" ];then
	  OLDPATH="$(readlink -- "/Volume1/MOD_CONFIG/${MOD_NAME}")"
	  rm -f "/Volume1/MOD_CONFIG/${MOD_NAME}"
	  if [ -d $OLDPATH ];then
	   echo "$(date +"%d/%m/%y %T") Config found at $OLDPATH, will be moved to $MODCONFIGPATH" 
       mv $OLDPATH $MODCONFIGPATH
	  fi
	elif [ -L "/Volume2/MOD_CONFIG/${MOD_NAME}" ];then
	  OLDPATH="$(readlink -- "/Volume2/MOD_CONFIG/${MOD_NAME}")"
	  rm -f "/Volume2/MOD_CONFIG/${MOD_NAME}"
	  if [ -d $OLDPATH ];then
	   echo "$(date +"%d/%m/%y %T") Config found at $OLDPATH, will be moved to $MODCONFIGPATH" 
       mv $OLDPATH $MODCONFIGPATH
	  fi
	elif [[ -d "/usr/local/${MOD_NAME}/config" && ! -L "/usr/local/${MOD_NAME}/config" ]];then
	  echo "$(date +"%d/%m/%y %T") Config found at /usr/local/${MOD_NAME}/config, will be moved to $MODCONFIGPATH"
	  mv "/usr/local/${MOD_NAME}/config" $MODCONFIGPATH
	else
	   echo "$(date +"%d/%m/%y %T") Config folder will be created $MODCONFIGPATH"
	   mkdir -p $MODCONFIGPATH
	fi
  fi
  
  if [ ! -L /usr/local/${MOD_NAME}/config ];then
   echo "$(date +"%d/%m/%y %T") config symlink doesn't exist, will be created"
	[[ -d "/usr/local/${MOD_NAME}/config" && ! -L "/usr/local/${MOD_NAME}/config" ]] && mv /usr/local/${MOD_NAME}/config /usr/local/${MOD_NAME}/config_old
    ln -sf $MODCONFIGPATH /usr/local/${MOD_NAME}/config
  elif [ "$(readlink -- "/usr/local/${MOD_NAME}/config")" != "$MODCONFIGPATH" ]; then
    rm -f /usr/local/${MOD_NAME}/config
    ln -sf $MODCONFIGPATH /usr/local/${MOD_NAME}/config
  fi
  
  if [ ! -L $MODCONFIGPATH/${MOD_NAME}_start.log ];then
   ln -sf $LOGFILE $MODCONFIGPATH/${MOD_NAME}_start.log
  fi 
fi
  
if [ "$TOSMVERS" -eq "7" ]; then
 MODCONFIGPATH=/usr/local/${MOD_NAME}/config
 MODCONFIGPATHHOME=$MODCONFIGHOME/${MOD_NAME}
	if [ -L $MODCONFIGPATH ];then
	 rm -f $MODCONFIGPATH
	  if [ -d $MODCONFIGHOME/${MOD_NAME} ]; then
	   mv $MODCONFIGHOME/${MOD_NAME} $MODCONFIGPATH
	  fi
	fi
	[ ! -d $MODCONFIGPATH ] && mkdir -p $MODCONFIGPATH
	
	[ ! -L $MODCONFIGHOME/${MOD_NAME} ] && ln -sf $MODCONFIGPATH $MODCONFIGHOME/${MOD_NAME}
    
fi

}

AddDataFolder(){
	foldername=$1
	username=$2
	DATAPATHFULL="$(ter_share_add -name "$foldername" -owner "$username")"
	if [ -z $DATAPATHFULL ];then
		if [ -z $MAIN_VOLUME ];then
			echo "$(date +"%d/%m/%y %T") TOS utility to create share folder is not working and main volume is not detected. Will exit now!!!"
			exit 1
		else
			echo "$(date +"%d/%m/%y %T") TOS utility to create share folder is not working, fall back to main volume"
			DATAPATHFULL=$MAIN_VOLUME/$foldername
			mkdir -p $DATAPATHFULL && chown $USER:$GROUP $DATAPATHFULL
		fi
	fi	
	DATAVOL=$(echo "$DATAPATHFULL" | awk -F"/" '{print $2}')

}


get_main_volume() {
    local result=""
    for item in $(df-json | egrep "/Volume[0-9]+$" | awk '{print $8}'); do
        check_main_raid $item
        [ $? -ne 0 ] && continue
        result=$item
        break
    done
    [ -z $result ]  && echo "$(date +"%d/%m/%y %T") Main volume cannot be detected" || echo "$(date +"%d/%m/%y %T") The main volume is $result"
	MAIN_VOLUME=$result
}

check_main_raid() {
    local mntpoint=$1
    local addr=$(cat $mntpoint/.main.inc 2>/dev/null)
    if [ "$addr" = $(get_default_addr) ]; then
        return 0
    fi
    return 1
}

get_default_addr() {
    echo $(ter_defaultmac)
}

parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=%s\n", "'$prefix'",vn, $2, $3);
      }
   }'
}


verify_yaml(){

	export $(parse_yaml $MODCONFIGPATH/variables.yaml)
	if [ $? -eq 0 ]; then
    echo "variable file is OK !"
	parse_yaml $MODCONFIGPATH/variables.yaml
      else
    echo "variable file has errors, will exit now"
	parse_yaml $MODCONFIGPATH/variables.yaml
	exit 1
      fi
}