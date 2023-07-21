#!/bin/bash
SECRET_FILE_ZIP=tbaas-secrets.zip
SECRET_DIR_OUT=tbaas-secrets
SECRET_NAME=tridentity-tbaas-secrets
TKE_CONFIG_FILE=tke-config.yml
FILES_NEED_ENCODE_BASE64=("ca.crt" "user_sign.crt" "user_sign.key" "user_tls.crt" "user_tls.key" "chain_admin_cert" "chain_admin_key")

echo "Please input unzip password:"
read SECRET_UNZIP_PASSWORD

# check have secrets file zip
if [ ! -f "$SECRET_FILE_ZIP" ]; then
    echo "Error: $SECRET_FILE_ZIP not found." >&2
    echo "Please copy $SECRET_FILE_ZIP to current directory and try again." >&2
    exit 1
fi

# check have tke config file
if [ ! -f "$TKE_CONFIG_FILE" ]; then
    echo "Error: $TKE_CONFIG_FILE not found." >&2
    echo "Please copy $TKE_CONFIG_FILE to current directory and try again." >&2
    exit 1
fi

# check is unzip installed, if not install unzip in ubuntu
if ! [ -x "$(command -v unzip)" ]; then
    echo 'Warning: unzip is not installed.' >&2
    echo 'Info: installing unzip...' >&2
    sudo apt-get install unzip -y
fi

# check is base64 installed, if not install base64 in ubuntu
if ! [ -x "$(command -v base64)" ]; then
    echo 'Warning: base64 is not installed.' >&2
    echo 'Info: installing base64...' >&2
    sudo apt-get install base64 -y
fi

# check is kubectl installed
if ! [ -x "$(command -v kubectl)" ]; then
    echo 'Warning: kubectl is not installed.' >&2
    echo 'Info: installing kubectl...' >&2

    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Connect to cluster
echo "Connect to cluster..."

mkdir -p ~/.kube && cp -p $TKE_CONFIG_FILE ~/.kube/tke-config
export KUBECONFIG=~/.kube/tke-config

rm -rf $SECRET_DIR_OUT
unzip -P $SECRET_UNZIP_PASSWORD $SECRET_FILE_ZIP -d $SECRET_DIR_OUT

if [ $? -ne 0 ]; then
    echo "Error: unzip $SECRET_FILE_ZIP failed." >&2
    exit 1
fi

for file in $SECRET_DIR_OUT/*; do
    # check is file in FILES_NEED_ENCODE_BASE64
    if [[ ! " ${FILES_NEED_ENCODE_BASE64[@]} " =~ " $(basename ${file}) " ]]; then
        echo "Skip encode base64 file: $file"
        continue
    fi
    base64 -i $file -o $file
done

kubectl delete secret $SECRET_NAME --ignore-not-found=true
kubectl create secret generic $SECRET_NAME --from-file=$SECRET_DIR_OUT
