# LOGU BASH Utility Instructions

These are the instructions for configuring LOGU for easier SSH and OC logins via BASH.  

## 

1. Clone this directory or download the bash script.

2. Add the following variable exports to your `~/.bashrc` or `~/.bash_profile` file:
```
export LOGU_SECRETS_FILE=~/.my_creds
export LOGU_SSH_PRIVATE_KEY=[Your SSH private key]
export LOGU_USERNAME=[Your SSH username]
source [Cloned repo directory]/logu_bash_lib.sh
```

3. Source your changes with `source ~/.bashrc` or `source ~/.bash_profile`

4. Test your ability to log in using the following command:
`logu.ssh host1 -p`
Use `logu.ssh -?` for all options.

5. Create a public and private key pair.
`ssh-keygen -t ed25519 -f ~/.ssh/logu_ed25519`

6. Add your public key, found at `~/.ssh/logu_ed25519.pub`, to your servers. If you are using an identity manager, add it there, otherwise, you can manually add your public key to a single server. To do this, SSH into the server and add your public key to `~/.ssh/authorized_keys`.

7. Test your login with the following command:
`logu.ssh host1`
Now, you should be able to log in to the server without providing a password.


## Log into OpenShift:  

First, ensure the Ansible binaries are installed.

1. Install vault binaries with the following command:

### Mac:  
`brew tap hashicorp/tap && brew install hashicorp/tap/vault`

### Linux:
```
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf -y install vault
```

### Other Operating Systems:  
[See HashiCorp's Vault Installation documentation](https://developer.hashicorp.com/vault/install)

2. Add `VAULT_ADDR`, `VAULT_TOKEN`, and `VAULT_TOKEN_READ` to `~/.bashrc` or `~/.bash_profile`.
```
export VAULT_ADDR='[Your HashiCorp Vault URL]'
export VAULT_TOKEN=[Vault token]
export VAULT_TOKEN_READ=[Vault token read]
```

3. Run the command `source ~/.bashrc` or `source ~/.bash_profile`

4. Add Vault CA to local trust store (replace with your vault certificate location):

### Mac:
`sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain [Your vault certificate location]/vault-root.crt`  

### Linux:
```
cp [Your vault certificate location]/vault-root.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
```

5. Test Vault connection, e.g. list your vault secrets with the following command:
`vault kv list secrets`
The output should be a list of secrets.

6. Test your ability to login as yourself, Kubeconfig, and Kubeadmin:
```
 logu.oc_login cluster1
 logu.oc_login cluster1 -kc
 logu.oc_login cluster1 -ka
```
