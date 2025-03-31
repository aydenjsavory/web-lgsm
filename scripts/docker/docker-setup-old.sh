#!/bin/bash

export SCRIPTPATH="$HOME/web-lgsm"
export apb="$SCRIPTPATH/venv/bin/ansible-playbook"
export venv_python="$SCRIPTPATH/venv/bin/python"
export ansible_connector="$SCRIPTPATH/playbooks/ansible_connector.py"
export accpt_usernames="$SCRIPTPATH/playbooks/vars/accepted_usernames.yml"
export web_lgsm_user_vars="$SCRIPTPATH/playbooks/vars/web_lgsm_user.yml"
export sudoers_file="/etc/sudoers.d/$USER-$USER"   
export SECRET_KEY=$(cat $SCRIPTPATH/.secret | awk -F'=' '{print $2}')

mkdir /home/root-keys
sudo rm -R /root/.ssh 
sudo ln -s /home/root-keys /root/.ssh
mkdir $HOME
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[34m'
RESET='\e[0m'




echo -e "${GREEN}Setting up within user Environment${RESET}"
if [![ -d "$SCRIPTPATH" ]]; then
  sudo rsync /data $HOME
fi
echo -e "${GREEN}####### Finalising Installation${RESET}"

#
# Correcting start rules for docker, If persistant container
# sed -i 's|export HOME=/home/web-lgsm|#export HOME=/home/web-lgsm|' $SCRIPTPATH/scripts/entrypoint.sh
# sed -i 's|service ssh start|sudo service ssh start |' $SCRIPTPATH/scripts/entrypoint.sh
# sed -i 's|exec sudo -E -u web-lgsm /home/web-lgsm/web-lgsm.py --start|#sudo -E ~/web-lgsm/web-lgsm.py --start|' $SCRIPTPATH/scripts/entrypoint.sh
# echo 'sudo -E ~/web-lgsm/web-lgsm.py --start|' >> $SCRIPTPATH/scripts/entrypoint.sh
# echo 'while true; do\n wait\ndone' >> $SCRIPTPATH/scripts/entrypoint.sh
# chmod +x $SCRIPTPATH/scripts/entrypoint.sh

#Remove for persistant container
# sudo $SCRIPTPATH/web-lgsm.py & 
# SERVER_PID=$!
sudo service ssh start&
SSH_PID=$!

echo -e "${GREEN}####### Project Setup & Installation Complete!!!${RESET}"

wait $SERVER_PID 
wait $SSH_PID

#A bad way of keeping the container running, however waiting for the Upstream PID to be passed on correctly so the above wait will work.

while true; do
  wait 1
done



# sudo chown $USER .


# #Get the web panel
# echo "Cloneing the web panel"
# git clone https://github.com/BlueSquare23/web-lgsm.git $SCRIPTPATH
# export WORKDIR=$SCRIPTPATH
#
# #Install System Dependancies
# while IFS= read -r package; do
#   echo "Installing $package..."
#   sudo apt install -y "$package"
#
#   # Check if the installation was successful
#   if [ $? -eq 0 ]; then
#     echo -e "${GREEN}${package} installed successfully.${RESET}"
#   else
#     echo -e "${RED}Failed to install $package.${RESET}"
#   fi
# done < $SCRIPTPATH/apt-reqs.txt
# echo -e "${GREEN}All packages installed.${RESET}"
#


# #Install the Python Dependancies
echo -e "${GREEN}Setting up Python Environment${RESET}"
cd $SCRIPTPATH
python3 -m venv $SCRIPTPATH/venv
source $SCRIPTPATH/venv/bin/activate
sed -i 's/^host = 127.0.0.1/host = 0.0.0.0/' $SCRIPTPATH/main.conf
pip install --upgrade pip setuptools
echo -e "${GREEN}Installing the Python Dependencies${RESET}"
sed 's/ *[><=~^].*//' $SCRIPTPATH/requirements.txt > $SCRIPTPATH/requirements_new
pip install -r $SCRIPTPATH/requirements_new
if [[ $? -ne 0 ]]; then
  echo -e "${RED}Error installing requirements from requirements.txt${RESET}"
  exit 1
fi
echo web_lgsm_user: $USER > $SCRIPTPATH/playbooks/vars/web_lgsm_user.yml
#
#
#Install the NPM Dependancies
echo -e "${GREEN}###### Installing NPM Requirements...${RESET}" \ 
  cd $SCRIPTPATH/app/static/js && \
  sudo npm install @xterm/xterm && \
  sudo npm install --save @xterm/addon-fit



# #SUDO No Password Rules
# echo -e "${GREEN}####### Setting up Sudoers Rules...${RESET}"
# export apb="$SCRIPTPATH/venv/bin/ansible-playbook"
# export venv_python="$SCRIPTPATH/venv/bin/python"
# export ansible_connector="$SCRIPTPATH/playbooks/ansible_connector.py"
# export accpt_usernames="$SCRIPTPATH/playbooks/vars/accepted_usernames.yml"
# export web_lgsm_user_vars="$SCRIPTPATH/playbooks/vars/web_lgsm_user.yml"
# export sudoers_file="/etc/sudoers.d/$USER-$USER"                                                                                      


# # Hardcode $USER ~ current system user into accepted_users validation list and
# # web_user ansible vars files.   
# sudo echo "  - $USER" >> $accpt_usernames
# sudo echo "web_lgsm_user: $USER" > $web_lgsm_user_vars
#
# # Write sudoers rule for passwordless install & delete.  
# sudoers_rule="$USER ALL=(root) NOPASSWD: $venv_python $ansible_connector *"
# temp_sudoers="temp"  
# touch $temp_sudoers
# echo "$sudoers_rule" > "$temp_sudoers"
# sudo chmod 0440 "$temp_sudoers"
# sudo chown root:root "$temp_sudoers"
# sudo visudo -cf "$temp_sudoers"
#
# # Validate new file.
# sudo mv "$temp_sudoers" "$sudoers_file"
#
#
# # Lock playbook files down for security reasons.  
# sudo find $SCRIPTPATH/playbooks -type f -exec chmod 644 {} \;
# sudo find $SCRIPTPATH/playbooks -type d -exec chmod 755 {} \;
# sudo chmod 755 $apb $ansible_connector
# sudo chown -R root:root $apb "$SCRIPTPATH/playbooks"
#
#
#
# # Generate the Secret Key & SSH keys 
# if [ ! -f "$SCRIPTPATH/random_key" ]; then
#   touch $SCRIPTPATH/random_key
#   echo $RANDOM | md5sum | head -c 20 >> $SCRIPTPATH/random_key
# fi
# echo "SECRET_KEY=$(cat random_key)" > $SCRIPTPATH/.secret
# chmod 600 $SCRIPTPATH.secret
# export SECRET_KEY=$(cat $SCRIPTPATH.secret)
#
# if [ ! -f "/home/$USER/.ssh/id_rsa" ]; then
#   ssh-keygen -t rsa -N '' -f /home/$USER/.ssh/id_rsa
# fi
#
#
# echo -e "${GREEN}####### Finalising Installation${RESET}"
#
# #
# # Correcting start rules for docker, If persistant container
# # sed -i 's|export HOME=/home/web-lgsm|#export HOME=/home/web-lgsm|' $SCRIPTPATH/scripts/entrypoint.sh
# # sed -i 's|service ssh start|sudo service ssh start |' $SCRIPTPATH/scripts/entrypoint.sh
# # sed -i 's|exec sudo -E -u web-lgsm /home/web-lgsm/web-lgsm.py --start|#sudo -E ~/web-lgsm/web-lgsm.py --start|' $SCRIPTPATH/scripts/entrypoint.sh
# # echo 'sudo -E ~/web-lgsm/web-lgsm.py --start|' >> $SCRIPTPATH/scripts/entrypoint.sh
# # echo 'while true; do\n wait\ndone' >> $SCRIPTPATH/scripts/entrypoint.sh
# # chmod +x $SCRIPTPATH/scripts/entrypoint.sh
#
# #Remove for persistant container
# sudo $SCRIPTPATH/web-lgsm.py & 
# SERVER_PID=$!
# sudo service ssh start&
# SSH_PID=$!
#
# echo -e "${GREEN}####### Project Setup & Installation Complete!!!${RESET}"
#
# wait $SERVER_PID 
# wait $SSH_PID
#
# #A bad way of keeping the container running, however waiting for the Upstream PID to be passed on correctly so the above wait will work.
#
# while true; do
#   wait 1
# done
#















