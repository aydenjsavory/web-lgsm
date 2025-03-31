export SCRIPTPATH="$HOME/web-lgsm"

RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[34m'
RESET='\e[0m'
# sudo chown $USER .
mkdir -p /home/root-keys/backup/root /home/root-keys/backup/usr 
mv /home/$USER/.ssh /home/root-keys/backup/usr
sudo mv /root/.ssh /home/root-keys/backup/root
sudo mv /etc /home/root-keys/backup/etc

# sudo rm -r /root/.ssh
# echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ln -s /home/root-keys/.ssh /home/$USER/
sudo ln -s /home/root-keys/.ssh /root/
sudo ln -s -f /home/root-keys/etc /etc
# sudo ln -s -f /home/root-keys/etc/passwd /etc/passwd
# sudo ln -s -f /home/root-keys/etc/shadow /etc/shadow
# sudo ln -s -f /home/root-keys/etc/group /etc/group


if [ -d "$SCRIPTPATH" ]; then
  echo -e "${GREEN}Panel Already Setup${RESET}"
fi 
if [ ! -d "$SCRIPTPATH" ]; then
  echo -e "${GREEN}Setting up the web panel${RESET}"
  mkdir $HOME
  mv /data/web-lgsm $HOME/
  cp /data/* $HOME
  export WORKDIR=$SCRIPTPATH


  #Get the web panel
  # echo "Cloneing the web panel"
  # git clone https://github.com/BlueSquare23/web-lgsm.git $SCRIPTPATH

  #Install System Dependancies
  # while IFS= read -r package; do
  #   echo "Installing $package..."
  #   sudo apt install -y "$package"
  #
  #   # Check if the installation was successful
  #   if [ $? -eq 0 ]; then
  #     # echo "$package installed successfully."
  #     echo -e "${GREEN}${package} installed successfully.${RESET}"
  #   else
  #     echo -e "${RED}Failed to install $package.${RESET}"
  #   fi
  # done < $SCRIPTPATH/apt-reqs.txt

  # echo "All packages installed."
  # echo -e "${GREEN}All packages installed.${RESET}"
  # cd $SCRIPTPATH
  # cd /data/web-lgsm/

  #Install the Python Dependancies
  echo -e "${GREEN}Setting up Python Environment${RESET}"
  cd $SCRIPTPATH
  python3 -m venv venv
  source venv/bin/activate
  sed -i 's/^host = 127.0.0.1/host = 0.0.0.0/' $SCRIPTPATH/main.conf
  pip install --upgrade pip setuptools
  echo -e "${GREEN}Installing the Python Dependencies${RESET}"
  sed 's/ *[><=~^].*//' $SCRIPTPATH/requirements.txt > $SCRIPTPATH/requirements_new
  pip install -r $SCRIPTPATH/requirements_new
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error installing requirements from requirements.txt${RESET}"
    exit 1
  fi
  # pip install -r dotenv 
  echo web_lgsm_user: $USER > $SCRIPTPATH/playbooks/vars/web_lgsm_user.yml

  echo -e "${GREEN}###### Installing NPM Requirements...${RESET}" \ 
    cd $SCRIPTPATH/app/static/js && \
    sudo npm install @xterm/xterm && \
    sudo npm install --save @xterm/addon-fit

  echo -e "${GREEN}####### Setting up Sudoers Rules...${RESET}"
  export apb="$SCRIPTPATH/venv/bin/ansible-playbook"
  export venv_python="$SCRIPTPATH/venv/bin/python"
  export ansible_connector="$SCRIPTPATH/playbooks/ansible_connector.py"
  export accpt_usernames="$SCRIPTPATH/playbooks/vars/accepted_usernames.yml"
  export web_lgsm_user_vars="$SCRIPTPATH/playbooks/vars/web_lgsm_user.yml"
  export sudoers_file="/etc/sudoers.d/$USER-$USER"                                                                                      


  # Hardcode $USER ~ current system user into accepted_users validation list and
  # web_user ansible vars files.   
  sudo echo "  - $USER" >> $accpt_usernames
  sudo echo "web_lgsm_user: $USER" > $web_lgsm_user_vars

  # Write sudoers rule for passwordless install & delete.  
  sudoers_rule="$USER ALL=(root) NOPASSWD: $venv_python $ansible_connector *"
  sudoers_rule="root ALL=(root) NOPASSWD: $venv_python $ansible_connector *"
  temp_sudoers="temp"  
  touch $temp_sudoers
  echo "$sudoers_rule" > "$temp_sudoers"
  sudo chmod 0440 "$temp_sudoers"
  sudo chown root:root "$temp_sudoers"
  sudo visudo -cf "$temp_sudoers"

  # Validate new file.
  sudo mv "$temp_sudoers" "$sudoers_file"


  # Lock playbook files down for security reasons.  
  sudo find $SCRIPTPATH/playbooks -type f -exec chmod 644 {} \;
  sudo find $SCRIPTPATH/playbooks -type d -exec chmod 755 {} \;
  sudo chmod 755 $apb $ansible_connector
  sudo chown -R root:root $apb "$SCRIPTPATH/playbooks"



  # Generate the Secret Key & SSH keys 
  touch $SCRIPTPATH/random_key
  echo $RANDOM | md5sum | head -c 20 >> $SCRIPTPATH/random_key
  echo "SECRET_KEY=$(cat $SCRIPTPATH/random_key)" > $SCRIPTPATH/.secret
  chmod 600 $SCRIPTPATH/.secret
  export SECRET_KEY=$(cat $SCRIPTPATH/.secret)

  ssh-keygen -t rsa -N '' -f /home/$USER/.ssh/id_rsa
  sed -i 's/ gameserver@.*//' /home/$USER/.ssh/id_rsa.pub
  sudo service ssh start

  chmod +x $SCRIPTPATH/scripts/entrypoint.sh

  # echo "####### Project Setup & Installation Complete!!!"
  echo -e "${GREEN}####### Project Setup & Installation Complete!!!${RESET}"

  sed -i 's|export HOME=/home/web-lgsm|#export HOME=/home/web-lgsm|' $SCRIPTPATH/scripts/entrypoint.sh
  sed -i 's|service ssh start|sudo service ssh start |' $SCRIPTPATH/scripts/entrypoint.sh
  sed -i 's|exec sudo -E -u web-lgsm /home/web-lgsm/web-lgsm.py --start|#sudo -E -u $USER ~/web-lgsm/web-lgsm.py --start|' $SCRIPTPATH/scripts/entrypoint.sh

  echo 'sudo -E ~/web-lgsm/web-lgsm.py --start|' >> $SCRIPTPATH/scripts/entrypoint.sh
  echo 'while true; do\n wait\ndone' >> $SCRIPTPATH/scripts/entrypoint.sh
  chmod +x $SCRIPTPATH/scripts/entrypoint.sh

fi

#Remove for persistant container
export SECRET_KEY=$(cat $SCRIPTPATH/.secret)

# Add the ssh keys into the containers
echo -e "${GREEN}Setting up SSH Keys${RESET}"
ssh_key=$(sudo cat /root/.ssh/id_ecdsa.pub)
ssh_key_root="$ssh_key root@$HOSTNAME"
ssh_key="$ssh_key $USER@$HOSTNAME"
echo -e "${GREEN}Using SSH Public key: $ssh_key ${RESET}"
# su root 
for user_dir in /home/*; do
  
  if sudo grep -qF "$ssh_key" "$user_dir/.ssh/authorized_keys"; then
    echo "Key already exists for user '$user_dir'. Skipping."
  else
    # Append the new key to the authorized_keys file
    # sudo echo "$ssh_key" >> "$user_dir/.ssh/authorized_keys"
    sudo tee "$user_dir/.ssh/authorized_keys" <<< "$ssh_key" > /dev/null
    sudo tee -a "$user_dir/.ssh/authorized_keys" <<< "$ssh_key_root" > /dev/null
    echo "Key added for user '$user_dir'."
  fi

echo -e "${GREEN}Done${RESET}"
done
# exit 

# sudo $SCRIPTPATH/web-lgsm.py --debug --status --verbose& 
sudo -E -u $USER $SCRIPTPATH/web-lgsm.py -d --start & 
SERVER_PID=$!
sudo service ssh start&
SSH_PID=$!

echo -e "${GREEN}####### Server Started!!!${RESET}"

wait $SERVER_PID 
wait $SSH_PID

#A bad way of keeping the container running, however waiting for the Upstream PID to be passed on correctly so the above wait will work.

while true; do
  wait $SERVER_PID 
  wait $SSH_PID
  # wait 1
done






















