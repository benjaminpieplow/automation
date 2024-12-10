# GIT configuration for new machine
# Benjamin Pieplow-Rohner
# 2024-03-27

echo "This script will configure GIT basics. It assumes GIT has been installed."
read -p "Enter your email: " email
read -p "Enter your Full Name: " fullName
read -p "Enter the default branch name [main]: " branchName
branchName=${branchName:-main}

git config --global user.email "$email"
git config --global user.name "$fullName"
git config --global init.defaultBranch $branchName
git config pull.rebase false