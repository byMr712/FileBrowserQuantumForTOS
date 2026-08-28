MOUNT=/bin/mount
UMOUNT=/bin/umount
len=${#depend[*]}

function V() # $1-a $2-op $3-$b
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
  echo " SUCCESS! $*" >> "$LOGFILE" 2>&1
}

log_failure_msg()
{
  echo " ERROR! $*" >> "$LOGFILE" 2>&1
}

init_config_folder(){
	LOGFILE="/usr/local/${MOD_NAME}/${MOD_NAME}_start.log"
	if [ -f "$LOGFILE" ]; then
		if [ $(($(stat -c %s "$LOGFILE" 2>/dev/null || echo 0)/1024)) -gt 1000 ]; then
			truncate -s 0 "$LOGFILE" 2>/dev/null || : > "$LOGFILE"
		fi
	fi

	ROOTUSER=$(id -un)

	if [ ! -d /usr/local/@APP_CONFIG ]; then
		mkdir -p /usr/local/@APP_CONFIG
	fi
	
	if [ "$(stat --format '%a' "/usr/local/@APP_CONFIG" 2>/dev/null)" != "755" ]; then
		chmod 755 /usr/local/@APP_CONFIG 2>/dev/null
	fi
	
	MODCONFIGHOME="/home/$ROOTUSER/MOD_CONFIG"
	MODCONFIG="/usr/local/@APP_CONFIG"
	[ ! -d "$MODCONFIGHOME" ] && mkdir -p "$MODCONFIGHOME"
	
	for i in {1..3}; do
		if [ -n "$($MOUNT | grep /usr/local/@APP_CONFIG | grep /dev/md9)" ]; then
			$UMOUNT /usr/local/@APP_CONFIG 2>/dev/null
		fi
	done
		
	if [ -z "$($MOUNT | grep /usr/local/@APP_CONFIG)" ]; then
		$MOUNT --bind "$MODCONFIGHOME" /usr/local/@APP_CONFIG 2>/dev/null
	fi
}

checkdep(){
	i=0
	while [ $i -lt $len ]; do
		[ -z "${depend[$i]}" ] && { i=$((i+1)); continue; }
		APP=$(echo "${depend[$i]}" | awk -F "=" '{printf$1}')
		VER=$(echo "${depend[$i]}" | awk -F "=" '{printf$2}')
		
		if [ -n "$APP" ]; then 
			if [ -f "/usr/local/$APP/config.ini" ]; then
				INSVER=$(awk -F ':' '{a=1}a==1&&$1~/"version"/{print $2;exit}' "/usr/local/$APP/config.ini" | cut -d'"' -f 2)
			else
				echo "$APP app is not installed"
				exit 1
			fi
		fi
		if [ -n "$VER" ]; then 
			if ! V "$INSVER" '>=' "$VER"; then
				echo "you must install $APP at least version $VER"
				exit 1
			fi
		fi
		i=$((i+1))  
	done
	echo "All dependencies apps are installed"
}

GetHomeVolume(){
	VOLCONF=$(DEV=$(df-json 2>/dev/null | grep -E '(^|\s)/home($|\s)' | awk '{print $1}') && $MOUNT | grep "$DEV" | grep -E '(^|\s)/Volume.($|\s)' | awk '{print $3}' | head -n 1)
	if [ -z "$VOLCONF" ]; then
		VOLCONF="/Volume1"
	fi
}

get_vol_name(){
	GetHomeVolume
	ROOTUSER=$(id -un)
	ROOTFOLDER="/usr/local/${MOD_NAME}"
	echo -e "<?php\n\$SUPERUSER = '$ROOTUSER';\n\$WEBPATH = '$ROOTFOLDER';\n?>" > "/usr/local/${MOD_NAME}/bin/config.inc.php"
	if [ -z "$VOLCONF" ]; then
		echo "$(date +"%d/%m/%y %T") No volume found, fallback to /Volume1" >> "$LOGFILE" 2>&1
		VOLCONF="/Volume1"
	else
		echo "$(date +"%d/%m/%y %T") Will use $VOLCONF to store config files" >> "$LOGFILE" 2>&1
	fi
}

init_cert(){
	CERT_PATH=/etc/ssl/certs
	if [ -d "/usr/local/${MOD_NAME}/sys/ssl" ]; then
		if [ ! -L "/usr/local/${MOD_NAME}/sys/ssl/cert.pem" ] && [ -f "$CERT_PATH/cacert.pem" ]; then
			ln -sf "$CERT_PATH/cacert.pem" "/usr/local/${MOD_NAME}/sys/ssl/cert.pem" > /dev/null 2>&1
		elif [ ! -L "/usr/local/${MOD_NAME}/sys/ssl/cert.pem" ] && [ -f "$CERT_PATH/ca-certificates.crt" ]; then
			ln -sf "$CERT_PATH/ca-certificates.crt" "/usr/local/${MOD_NAME}/sys/ssl/cert.pem" > /dev/null 2>&1
		fi
	fi
}

GetTOSVersion(){
	if [ -f /usr/lib/version ]; then
		TOSMVERS=$(cat /usr/lib/version | cut -d '_' -f 3 | cut -d '.' -f 1)
	else
		TOSMVERS="6"
	fi
}

AddConfigFolder(){
	GetTOSVersion
	echo "$(date +"%d/%m/%y %T") We are on TOS version $TOSMVERS"

	if [ "$TOSMVERS" -lt "7" ]; then
		MODCONFIGPATH=/usr/local/@APP_CONFIG/${MOD_NAME}
		MODCONFIGPATHHOME=$MODCONFIGHOME/${MOD_NAME}
		
		if [ -d "$MODCONFIGPATH" ] && [ ! -L "$MODCONFIGPATH" ]; then
			echo "$(date +"%d/%m/%y %T ")Config folder exist at $MODCONFIGPATH"
		else
			if [ -L "$MODCONFIGPATH" ]; then
				OLDPATH="$(readlink -- "$MODCONFIGPATH")"
				if [ -d "$OLDPATH" ]; then
					echo "$(date +"%d/%m/%y %T ") Config found at $OLDPATH, will be moved to $MODCONFIGPATHHOME" 
					rm -f "$MODCONFIGPATH"
					cp -af "$OLDPATH/." "$MODCONFIGPATH"
					rm -rf "$OLDPATH"
				else
					rm -f "$MODCONFIGPATH"
					mkdir -p "$MODCONFIGPATH"
				fi
			elif [ -d "/Volume1/MOD_CONFIG/${MOD_NAME}" ] && [ ! -L "/Volume1/MOD_CONFIG/${MOD_NAME}" ]; then
				echo "$(date +"%d/%m/%y %T") Config found at /Volume1/MOD_CONFIG/${MOD_NAME}, will be moved to $MODCONFIGPATHHOME"
				mv "/Volume1/MOD_CONFIG/${MOD_NAME}" "$MODCONFIG"
			elif [ -L "/Volume1/MOD_CONFIG/${MOD_NAME}" ]; then
				OLDPATH="$(readlink -- "/Volume1/MOD_CONFIG/${MOD_NAME}")"
				rm -f "/Volume1/MOD_CONFIG/${MOD_NAME}"
				if [ -d "$OLDPATH" ]; then
					echo "$(date +"%d/%m/%y %T") Config found at $OLDPATH, will be moved to $MODCONFIGPATH" 
					mv "$OLDPATH" "$MODCONFIGPATH"
				fi
			elif [ -L "/Volume2/MOD_CONFIG/${MOD_NAME}" ]; then
				OLDPATH="$(readlink -- "/Volume2/MOD_CONFIG/${MOD_NAME}")"
				rm -f "/Volume2/MOD_CONFIG/${MOD_NAME}"
				if [ -d "$OLDPATH" ]; then
					echo "$(date +"%d/%m/%y %T") Config found at $OLDPATH, will be moved to $MODCONFIGPATH" 
					mv "$OLDPATH" "$MODCONFIGPATH"
				fi
			elif [ -d "/usr/local/${MOD_NAME}/config" ] && [ ! -L "/usr/local/${MOD_NAME}/config" ]; then
				echo "$(date +"%d/%m/%y %T") Config found at /usr/local/${MOD_NAME}/config, will be moved to $MODCONFIGPATH"
				mv "/usr/local/${MOD_NAME}/config" "$MODCONFIGPATH"
			else
				echo "$(date +"%d/%m/%y %T") Config folder will be created $MODCONFIGPATH"
				mkdir -p "$MODCONFIGPATH"
			fi
		fi
		
		if [ ! -L "/usr/local/${MOD_NAME}/config" ]; then
			echo "$(date +"%d/%m/%y %T") config symlink doesn't exist, will be created"
			[ -d "/usr/local/${MOD_NAME}/config" ] && [ ! -L "/usr/local/${MOD_NAME}/config" ] && mv "/usr/local/${MOD_NAME}/config" "/usr/local/${MOD_NAME}/config_old"
			ln -sf "$MODCONFIGPATH" "/usr/local/${MOD_NAME}/config"
		elif [ "$(readlink -- "/usr/local/${MOD_NAME}/config")" != "$MODCONFIGPATH" ]; then
			rm -f "/usr/local/${MOD_NAME}/config"
			ln -sf "$MODCONFIGPATH" "/usr/local/${MOD_NAME}/config"
		fi
		
		if [ ! -L "$MODCONFIGPATH/${MOD_NAME}_start.log" ]; then
			ln -sf "$LOGFILE" "$MODCONFIGPATH/${MOD_NAME}_start.log"
		fi 
	fi
	  
	if [ "$TOSMVERS" -ge "7" ]; then
		MODCONFIGPATH=/usr/local/${MOD_NAME}/config
		MODCONFIGPATHHOME=$MODCONFIGHOME/${MOD_NAME}
		if [ -L "$MODCONFIGPATH" ]; then
			rm -f "$MODCONFIGPATH"
			if [ -d "$MODCONFIGHOME/${MOD_NAME}" ]; then
				mv "$MODCONFIGHOME/${MOD_NAME}" "$MODCONFIGPATH"
			fi
		fi
		[ ! -d "$MODCONFIGPATH" ] && mkdir -p "$MODCONFIGPATH"
		
		[ ! -L "$MODCONFIGHOME/${MOD_NAME}" ] && ln -sf "$MODCONFIGPATH" "$MODCONFIGHOME/${MOD_NAME}"
	fi
}

get_main_volume() {
    local result=""
    for item in $(df-json 2>/dev/null | grep -E "/Volume[0-9]+$" | awk '{print $8}'); do
        check_main_raid "$item"
        [ $? -ne 0 ] && continue
        result=$item
        break
    done
    if [ -z "$result" ]; then
        result=$(df -P 2>/dev/null | grep -o '/Volume[0-9]*' | head -n 1)
    fi
    [ -z "$result" ] && result="/Volume1"
    echo "$(date +"%d/%m/%y %T") The main volume is $result"
    MAIN_VOLUME=$result
}

check_main_raid() {
    local mntpoint=$1
    local addr
    addr=$(cat "$mntpoint/.main.inc" 2>/dev/null)
    if [ -n "$addr" ] && [ "$addr" = "$(get_default_addr)" ]; then
        return 0
    fi
    return 1
}

get_default_addr() {
    echo $(ter_defaultmac 2>/dev/null)
}