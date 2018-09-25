# set variables
AIRPORT='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'
CURRENT_DEVICE=$(networksetup -listallhardwareports | awk '$3=="Wi-Fi" {getline; print $2}')
CURRENT_MAC=$(ifconfig $CURRENT_DEVICE | grep "ether" | tr -d ' ' | tr -d '\t' | cut -c 6-42)
ORIGINAL_MAC=$(networksetup -getmacaddress $CURRENT_DEVICE | grep "Ethernet Address:" | tr -d ' ' | tr -d '\t' | cut -c 17-33)
# set functions
function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\x1B[1;37m"
    local green="\x1B[1;32m"
    local red="\x1B[1;31m"
    local nc="\x1B[0m"

    case $1 in
        start)
            # calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}-8
            # display message and position the cursor in $column column
            echo ${2}
            printf "%${column}s"

            # start spinner
            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            echo "\b"
            if [[ $2 -eq 0 ]]; then
                echo "${green}${on_success}${nc}"
            else
                echo "${red}${on_fail}${nc}"
            fi
            echo ""
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {
    # $1 : command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}

RANDOMIZE()
{
	# disconnect current wifi network
	echo ""
	start_spinner '... Disconnecting from current network ...'
	sudo $AIRPORT $CURRENT_DEVICE -z
	sleep 3
	stop_spinner $?
	# change/randomize MAC address
	while :
	do
		read -p "Enter New MAC Address (or leave blank for random): " newmac
		if [[ -z "$newmac" ]]; then
			echo ""
			start_spinner '... Randomizing MAC Address ...'
			openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | xargs sudo ifconfig $CURRENT_DEVICE ether
			openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | xargs sudo ifconfig $CURRENT_DEVICE ether
			openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | xargs sudo ifconfig $CURRENT_DEVICE ether
			sleep 1
			stop_spinner $?
			break
		# check
		elif [[ -n "$newmac" ]]; then
				echo ""
				start_spinner '... Checking MAC Address ...'
				sleep 1
				stop_spinner $?
				if [[ $newmac =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; then
					start_spinner '... Valid! Setting up ...'
					sudo ifconfig $CURRENT_DEVICE ether $newmac
					sleep 1
					stop_spinner $?
					break
					else
						echo "... INVALID! Type it again ..."
						echo ""
				fi
		fi
	done
	# turn off wifi
	start_spinner '... Turning OFF Wi-Fi ...'
	networksetup -setairportpower $CURRENT_DEVICE off
	sleep 10
	stop_spinner $?
	# turn on wifi
	start_spinner '... Turning ON Wi-Fi ...'
	networksetup -setairportpower $CURRENT_DEVICE on
	sleep 1
	stop_spinner $?
	# print new MAC
	cat << "EOF"
                            __,---,
               .---.       /__|o\  )        .-"-.      .----.""".
              /   6_6       `-\ / /        / 4 4 \    /____/ (0 )\
              \_  (__\        ,) (,        \_ v _/      `--\_    /
              //   \\        //   \\       //   \\         //   \\
             ((     ))      {(     )}     ((     ))       {{     }}
       =======""===""========""===""=======""===""=========""===""=======
        Enjoy   |||    your   |||||   new    |||     MAC     |||  address!
                 |             |||            |              '|'
                                |
EOF
	echo "Your new MAC address is: \x1B[96;1;4;5m$(ifconfig $CURRENT_DEVICE | grep "ether" | tr -d ' ' | tr -d '\t' | cut -c 6-42)\x1B[m"
	echo "##########################################"
	echo ""
	exit;
}

REVERT()
{
	# disconnect current wifi network
	echo ""
	start_spinner '... Disconnecting from current network ...'
	sudo $AIRPORT $CURRENT_DEVICE -z
	sleep 3
	stop_spinner $?
	# reverting MAC address
	start_spinner '... Reverting MAC Address ...'
	sudo ifconfig $CURRENT_DEVICE ether $ORIGINAL_MAC
	sleep 1
	stop_spinner $?
	# turn off wifi
	start_spinner '... Turning OFF Wi-Fi ...'
	networksetup -setairportpower $CURRENT_DEVICE off
	sleep 10
	stop_spinner $?
	# turn on wifi
	start_spinner '... Turning ON Wi-Fi ...'
	networksetup -setairportpower $CURRENT_DEVICE on
	sleep 1
	stop_spinner $?
	if [[ $(ifconfig $CURRENT_DEVICE | grep "ether" | tr -d ' ' | tr -d '\t' | cut -c 6-42) == $ORIGINAL_MAC ]];
	then
		cat << "EOF"
                             __,---,
               .---.        /__|o\  )        .-"-.       .----.""".
              /   6_6        `-\ / /        / 4 4 \     /____/ (0 )\
              \_  (__\         ,) (,        \_ v _/       `--\_    /
              //   \\         //   \\       //   \\          //   \\
             ((     ))       {(     )}     ((     ))        {{     }}
       =======""===""=========""===""=======""===""==========""===""=======
      Reverting |||     MAC    |||||   was    ||| successfully ||| finished!
                 |              |||            |               '|'
                                 |
EOF
		echo "MAC Address successfully reverted to: \x1B[96;1;4;5m$(echo $ORIGINAL_MAC)\x1B[m"
		echo "#######################################################"
		echo ""
		exit;
	else
		cat << "EOF"
  :                      :
  ::                    ::
  ::`.     .-""-.     .'::
  : `.`-._ : '>': _.-'.' :
  :`. `=._`'.  .''_.=' .':
   : `=._ `- '' -' _.-'.:
    :`=._`=.    .='_.=':
     `.._`.      .'_..'
       `-.:      :.-'
          :      :
          `:.__.:'
           :    :
          -'=  -'=
EOF
		echo "Reverting was NOT successful !!!"
		echo "Your MAC Address is still: \x1B[91;1;4m$(ifconfig $CURRENT_DEVICE | grep "ether" | tr -d ' ' | tr -d '\t' | cut -c 6-42)\x1B[m"
		echo "Try it again ..."
		echo ""
		exit;
	fi
}
# load
echo ""
cat << "EOF"
                            .
             WELCOME       | \/|
   (\   _       in         ) )|/|
       (/            _----. /.'.'
 .-._________..      .' @ _\  .'
 '.._______.   '.   /    (_| .')
   '._____.  /   '-/      | _.'
    '.______ (         ) ) \
      '..____ '._       )  )
         .' __.--\  , ,  // ((
         '.'     |  \/   (_.'(
                 '   \ .'   
   MAC Changer    \   (          by
                   \   '.    Strejda603
                    \ \ '.)
                     '-'-'
EOF
echo ""
echo "Current Wi-Fi Device = '$CURRENT_DEVICE'"
echo "Current Wi-Fi Mac Address = '$CURRENT_MAC'"
echo ""
# starting
while :
do
	read -n 1 -s -p "Continue? [Y/n]" response
	case $response in
		""|[yY] )
			echo ""
			start_spinner 'Starting ...'
			sleep 1
			stop_spinner $?

			# RANDOMIZE
			if [[ $CURRENT_MAC == $ORIGINAL_MAC ]]; then
				echo "Your MAC Address is: \x1B[1;38;5;27m$CURRENT_MAC\x1B[m"
				while :
				do
					read -n 1 -s -p "Would you like to change it? [Y/n]" random
					case $random in
						""|[yY] )
							RANDOMIZE
							;;
						[nN] )
							echo ""
							echo "The script will end ..."
							sleep 1
							clear
							exit;
							;;
						* )
							echo ""
							echo "Use only 'y' or 'n' !"
					esac
				done
			fi

			# REVERT
			if [[ $CURRENT_MAC != $ORIGINAL_MAC ]]; then
				echo "Your MAC Address is already changed to: \x1B[1;38;5;27m$CURRENT_MAC\x1B[m"
				while :
				do
					read -n 1 -s -p $'Would you like to R\x1B[4mE\x1B[mVERT it or R\x1B[4mA\x1B[mNDOMIZE again? [E/a] (For exit press [q])' revert
					case $revert in
						""|[eE] )
							REVERT
							;;
						[aA] )
							RANDOMIZE
							;;
						[qQ] )
							echo ""
							echo "The script will end ..."
							sleep 1
							clear
							exit;
							;;
						* )
							echo ""
							echo "Use only 'e', 'a' or 'q' !"
					esac
				done
			fi
					;;
				[nN] )
					echo ""
					echo "The script will end ..."
					sleep 1
					clear
					exit;
					;;
				* )
					echo ""
					echo "Use only 'y' or 'n' !"
			esac
		done
