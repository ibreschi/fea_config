mkdir ~/Deepomatic/git

curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-372.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-sdk* -C ~/
rm google-cloud-sdk*
/home/ibreschi/google-cloud-sdk/install.sh

gcloud components install kubectl

cd ~/git
git clone https://github.com/cykerway/complete-alias

# install krew
https://krew.sigs.k8s.io/docs/user-guide/setup/install/

kubectl krew install ctx
kubectl krew install ns

# Download slack
dpkg -i slack.deb

# Download docker
sudo docker login

