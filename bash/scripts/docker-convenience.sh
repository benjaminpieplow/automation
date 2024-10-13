# Gets your Docker environmnet set up using the convenience script that you always have to Google for and remember what else you have to do
# Benjamin Rohner
# 2023-03-27

echo "Documetnation: https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script"

# Update
sudo apt update && apt upgrade -y
sudo apt install curl -y

# Get the script
curl -fsSL https://get.docker.com -o get-docker.sh

# Run the script
sudo sh ./get-docker.sh

sudo usermod -aG docker $USER

# Test Docker
docker run hello-world


read -p "Did that work? Enter to continue, ctrl-c to fix your mistake." $null

sudo apt install docker-compose -y
sudo reboot