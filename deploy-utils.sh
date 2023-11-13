# Build host scripts utils
deploy_utils__gen_ssh_key() {
	# Generate SSH key-pair on a build host (the machine + user running this script)
	mkdir ~/.ssh 2> /dev/null
	pushd ~/.ssh > /dev/null
	echo -e "\nn" | ssh-keygen -q -f 'id_rsa' -N '' > /dev/null
	popd > /dev/null

	# Copy public key to build directory
	cp ~/.ssh/id_rsa.pub authorized_keys
}

# Remote host scripts utils
deploy_utils__rerun_script_as_root() {
	if [[ "$(whoami)" != "root" ]] then
		echo -e "\t\tdeploy_utils_rerun_as_root(): re-run the script as root..."
		sudo -S ./run
	fi
}

deploy_utils__create_user__copy_ssh_key__set_systemd_config_dir() {
	if [[ "$1" == "" ]] then
		echo -e "\t\tdeploy_utils__create_user__copy_ssh_key__set_systemd_config_dir: username was not provided, abort"
		exit 1
	fi

	# Add new user for target service
	adduser -gecos "" --disabled-password $1 2> /dev/null

	# Setup access to remote host over SSH
	local SSH_PATH=/home/$1/.ssh
	mkdir $SSH_PATH 2> /dev/null
	cp authorized_keys $SSH_PATH
	chown -R $1:$1 $SSH_PATH
	chmod -R 700 $SSH_PATH
	chmod -R 600 $SSH_PATH/authorized_keys

	# Create systemd user config directory
	mkdir -p /home/$1/.config/systemd/user
	chown -R $1:$1 /home/$1/.config

	# This is required to start/run systemd service/socket of $1 even they are not logged in
	loginctl enable-linger $1
}

deploy_utils__systemd_root_unit__load_enable_restart() {
	if [[ "$1" == "" ]] then
		local UNIT=$(ls *.service)
	else
		local UNIT=$1
	fi

	# Load systemd service config
	cp ./$UNIT /etc/systemd/system
	echo -e "\t\tdeploy_utils__systemd_root_unit__load_enable_restart(): $UNIT: daemon-reload"
	systemctl daemon-reload

	# Enable systemd service config (start on boot)
	echo -e "\t\tdeploy_utils__systemd_root_unit__load_enable_restart(): $UNIT: enabling"
	systemctl enable $UNIT

	# (Re)start service
	echo -e "\t\tdeploy_utils__systemd_root_unit__load_enable_restart(): $UNIT: restart"
	systemctl restart $UNIT

	# Print systemd service status
	systemctl status $UNIT
}

deploy_utils__systemd_root_unit__is_outdated_or_not_active() {
	if [[ "$1" == "" ]] then
		local UNIT=$(ls *.service)
	else
		local UNIT=$1
	fi

	cmp -s ./$UNIT /etc/systemd/system/$UNIT; local UNIT_IS_DIFF=$?
	systemctl is-active --quiet $UNIT;        local UNIT_IS_ACTIVE=$?
	if [[ $UNIT_IS_DIFF != 0 || $UNIT_IS_ACTIVE != 0 ]] then
		return 0
	fi

	return 1
}

deploy_utils__systemd_nonroot_unit__load_enable_restart() {
	if [[ "$1" == "" ]] then
		local UNIT=$(ls *.service)
	else
		local UNIT=$1
	fi

	# Load systemd service config
	cp ./$UNIT ~/.config/systemd/user
	echo -e "\t\tdeploy_utils__systemd_nonroot_unit__load_enable_restart(): $UNIT: daemon-reload"
	systemctl --user daemon-reload

	# Enable systemd service config (start on boot)
	echo -e "\t\tdeploy_utils__systemd_nonroot_unit__load_enable_restart(): $UNIT: enabling"
	systemctl --user enable $UNIT
	loginctl enable-linger `whoami`

	# (Re)start service
	echo -e "\t\tdeploy_utils__systemd_nonroot_unit__load_enable_restart(): $UNIT: restart"
	systemctl --user restart $UNIT

	# Print systemd service status
	systemctl --user status $UNIT
}

deploy_utils__systemd_nonroot_unit__is_outdated_or_not_active() {
	if [[ "$1" == "" ]] then
		local UNIT=$(ls *.service)
	else
		local UNIT=$1
	fi

	cmp -s ./$UNIT ~/.config/systemd/user/$UNIT; local UNIT_IS_DIFF=$?
	systemctl --user is-active --quiet $UNIT;    local UNIT_IS_ACTIVE=$?
	if [[ $UNIT_IS_DIFF != 0 || $UNIT_IS_ACTIVE != 0 ]] then
		return 0
	fi

	return 1
}

deploy_utils__systemd_nonroot__enable_rootless_docker() {
	if [[ "$(systemctl --user is-enabled docker)" != 'enabled' ]]
	then
		echo -e "\t\tdeploy_utils__systemd_nonroot_unit__is_outdated_or_not_active(): enabling rootless docker"
		dockerd-rootless-setuptool.sh install
	fi
}

deploy_utils__is_file_diff() {
	cmp -s $1 $2; local IS_DIFF=$?
	if [[ $IS_DIFF != 0 ]] then
		return 0
	fi

	return 1
}