#!/usr/bin/env bash

# ==================================
# THIS IS THE ONLY THING TO EDIT
# Replace with your base domain
BASE_DOMAIN="example.com"
# ==================================


# ** INSTRUCTIONS **  
# To use this library, it's required to set the following env vars in your startup file (e.g. ~/.bashrc, ~/.bash_profile, etc.):
#
# LOGU_SECRETS_FILE: file to contain encrypted secrets, if this isn't set, it will use: ~/.my_creds
# LOGU_SSH_PRIVATE_KEY: path of your SSH private key (OPTIONAL)
# LOGU_USERNAME: Your IDM username
# LOGU_PASSWORD: Your IDM password (OPTIONAL, typically in a vaulted file.)

# To use logu.oc_login and logu.ssh you must also set:
#
# VAULT_ADDR and VAULT_TOKEN to read credentials from Vault."

# Optionally, if you are on your local workstation, so you are not challenged for a vault password every time.
# ANSIBLE_VAULT_PASSWORD_FILE: <path to your vault password file>

# Then, source this file

LOGU_VERSION='1.0.0'

# Block interactive execution
if [[ $0 = $BASH_SOURCE ]]; then
  echo "Error: $0 must be sourced; not executed interactively."
  exit 1
else
  echo "LOGU BASH utility library loaded."
fi

function logu.ssh() {
  local USAGE="Usage: $FUNCNAME <host> [-p|-i]
Login to a host using SSH.
  -p Password authentication.
  -i (default) Identity (pub key) authentication.

Examples:
  $> logu.ssh host1
  $> logu.ssh host1 -p
  $> logu.ssh host1 -i  
"

  if [[ -z $1 || $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  local host=$1
  local ip="${1}.${BASE_DOMAIN}"
  echo "Host: $host - IP: $ip"

  if [[ -z "${LOGU_USERNAME}" ]]; then
    echo "Error: LOGU_USERNAME must be set (exported)."
    return
  fi

  if [[ "${2}" == '-p' ]]; then
    ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -l "${LOGU_USERNAME}" "${ip}"
  else
    if [[ -z "${LOGU_SSH_PRIVATE_KEY}" ]]; then
      echo "Error: LOGU_SSH_PRIVATE_KEY path must be set (exported) for identity authentication."
      return
    fi
    ssh -i "${LOGU_SSH_PRIVATE_KEY}" -l "${LOGU_USERNAME}" "${ip}"
  fi
}

function logu.oc_login() {
  local USAGE="Usage: $FUNCNAME <host> [-kc (kubeconfig login)] [-ka (kubeadmin)] [-i (for no tls)]
Login to an OpenShift cluster using kubeconfig, kubeadmin or user credentials.

Examples: 
  Login with kubeconfig:
    $> logu.oc_login cluster1 -kc
  Login as kubeadmin:
    $> logu.oc_login cluster1 -ka
  Login as user (LOGU_USERNAME):
    $> logu.oc_login cluster1
  Optionally pass -i to skip TLS verification:
    $> logu.oc_login cluster1 -i
    $> logu.oc_login cluster1 -ka -i  
"

  if [[ -z $1 || $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  # Get kubeconfig or kubeadmin credentials from Vault.
  if [[ -z VAULT_ADDR && -z VAULT_TOKEN ]]; then
    echo "Error: VAULT_ADDR and VAULT_TOKEN must be set to read credentials from Vault."
    echo " You can find the Vault tokens in our secrets spreadsheet."
    return
  fi

  local cluster=$1

  # Get API URL from Vault
  local url=$(vault kv get -field=api secrets/openshift/${cluster})
  if [[ -z "${url}" ]]; then
    echo "Error: API URL not found for cluster: '${cluster}' in Vault."
    echo "Make sure you're logged into VPN if it is required, or check the cluster name spelling."
    return
  fi

  if [[ $3 == "-i" || $2 == "-i" ]]; then
    local no_tls="--insecure-skip-tls-verify=true"
  fi

  echo "Cluster: ${cluster} - URL: $url"

  if [[ ${2} == "-kc" ]]; then
    local kubeconfig=$(vault kv get -field=kubeconfig secrets/openshift/${cluster})
    if [[ -z "${kubeconfig}" ]]; then
      echo "Error: kubeconfig not found in Vault."
      return
    fi
    rm -rf /tmp/kubeconfig
    echo "${kubeconfig}" > /tmp/kubeconfig
    export KUBECONFIG=/tmp/kubeconfig
    echo "KUBECONFIG set to /tmp/kubeconfig"
  elif [[ ${2} == "-ka" ]]; then
    local kubepass=$(vault kv get -field=kubeadmin secrets/openshift/${cluster})
    if [[ -z "${kubepass}" ]]; then
      echo "Error: kubeadmin password not found in Vault."
      echo " If this is a cluster with Hosted Control Planes, HCP clusters don't have kubeadmin, use -kc instead."
      return
    fi
    oc login -u "kubeadmin" -p "${kubepass}" "${url}" ${no_tls}
  else
    if [[ -z "${LOGU_USERNAME}" ]]; then
      echo "Error: LOGU_USERNAME must be set (exported). Optionally, LOGU_PASSWORD can be set as well."
      return
    fi
    if [[ -n "${LOGU_PASSWORD}" ]]; then
      oc login -u "${LOGU_USERNAME}" -p "${LOGU_PASSWORD}" --server="${url}" ${no_tls}
    else
      oc login -u "${LOGU_USERNAME}" --server="${url}" ${no_tls}
    fi
  fi
  echo ""
  echo "Currently logged in as user: $(oc whoami) - Console: $(oc whoami --show-console)"
}

# Global variable definitions
if [[ -z $LOGU_SECRETS_FILE ]]; then
  export LOGU_SECRETS_FILE=~/.my_creds
fi

# Display current library version.
function logu.version() {
  echo "LOGU v${LOGU_VERSION}"
}

function logu.myvault_edit() {
  local USAGE="Usage: $FUNCNAME [vault-file]
Edit personal vault file, or any vault file passed. By default, this will use $LOGU_SECRETS_FILE
The file will be created and encrypted if it doesn't already exist.
"
  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  type ansible-vault >/dev/null 2>&1 || { echo >&2 "ansible-vault is required."; return; }

  if [[ -z $1 ]]; then
    vault_file=$LOGU_SECRETS_FILE
  else
    vault_file=$1
  fi

  # Create the file if doesn't exist.
  if [ ! -f "$vault_file" ]; then
      echo "$vault_file does not exist. Creating and encrypting it..."
      touch $vault_file
      ansible-vault encrypt $vault_file
  fi

  ansible-vault edit $vault_file
  echo "Reloading vault file: $vault_file ..."
  logu.myvault_load
}

function logu.myvault_load() {
  local USAGE="Usage: $FUNCNAME [vault-file]
Load the personal vault file, or any vault file passed. 
By default, this will use $LOGU_SECRETS_FILE
"
  if [[ $1 == "-?" ]]; then
    echo "${USAGE}"
    return
  fi

  if [[ -z $1 ]]; then
    vault_file=$LOGU_SECRETS_FILE
  else
    vault_file=$1
  fi

  type ansible-vault >/dev/null 2>&1 || { echo >&2 "ansible-vault is required."; return; }

  # Since the line: 'source <(ansible-vault view "$vault_file");' doesn't work on a Mac
  #  let's decrypt the file before loading, then re-encrypt.
  if [[ $(uname) == "Darwin" ]]; then
    # on a Mac
    ansible-vault decrypt "$vault_file" > /dev/null
    source "$vault_file"
    ansible-vault encrypt "$vault_file" > /dev/null
  else
    # on Linux
    source <(ansible-vault view "$vault_file"); 
  fi
  echo "Vault file: $LOGU_SECRETS_FILE loaded to memory."
}
