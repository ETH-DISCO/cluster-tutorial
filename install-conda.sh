#!/bin/bash

# based on: https://computing.ee.ethz.ch/Programming/Languages/Conda

declare -i SPACE_AVAILABLE SPACE_MINIMUM_REQUIRED
SPACE_MINIMUM_REQUIRED=5 # [G]

if [[ -z "${1}" ]]; then
    # Default install location
    OPTION='netscratch'
else
    OPTION="${1}"
fi

line=$(printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-')

# Display underlined title to improve readability of script output
function title() {
    echo
    echo "$@"
    echo "${line}"
}

case "${OPTION}" in
h | help | '-h' | '--help')
    title 'Possible installation options are:'
    echo 'Install conda to your local scratch disk:'
    echo "${BASH_SOURCE[0]} localscratch"
    echo
    echo 'Install conda to your directory on net_scratch:'
    echo "${BASH_SOURCE[0]}"
    echo 'or'
    echo "${BASH_SOURCE[0]} netscratch"
    echo
    echo 'Provide a custom location for installation'
    echo "${BASH_SOURCE[0]} /path/to/custom/location"
    echo
    echo "The recommended minimum space requirement for installation is ${SPACE_MINIMUM_REQUIRED} G."
    exit 0
    ;;
l | local | localscratch | '-l' | '-local' | '-localscratch')
    # If local scratch is made available through scratch_net, use its path in
    # order to be able to access it on other hosts through scratch_net
    if grep -q scratch_net /etc/auto.master; then
        CONDA_BASE_DIR="/scratch_net/$(hostname -s)/${USER}"
    else
        CONDA_BASE_DIR="/scratch/${USER}"
    fi
    ;;
n | net | netscratch | '-n' | '-net' | '-netscratch')
    net_scratch_direct="/usr/itetnas04/data-scratch-01/${USER}/data" # Path to net_scratch for exercise accounts
    net_scratch_itet_stor="/itet-stor/${USER}/net_scratch"           # Path to net_scratch for non-exercise accounts
    if [[ -d ${net_scratch_itet_stor} ]]; then
        CONDA_BASE_DIR="${net_scratch_itet_stor}"
    else
        CONDA_BASE_DIR="${net_scratch_direct}"
    fi
    ;;
*)
    CONDA_BASE_DIR="${1}"
    ;;
esac

# Check if this script is started on an Euler login node, if it is, suggest a custom install location and exit
if [[ -z ${HOSTNAME} ]]; then
    host_name=$(hostname -s)
else
    host_name=${HOSTNAME}
fi
if [[ -n ${host_name} ]]; then
    if [[ ${host_name%-*} == 'eu-login' ]]; then
        echo "It seems you're using this script on the Euler cluster."
        echo 'Provide a custom location for installation, for example in your Euler home:'
        echo "${BASH_SOURCE[0]} ${HOME}/conda"
        exit 1
    fi
fi

# Create install location if it doesn't exist
if [[ ! -d "${CONDA_BASE_DIR}" ]]; then
    mkdir -p "${CONDA_BASE_DIR}"
fi

# Check available space on selected install location
SPACE_AVAILABLE=$(($(stat -f --format="%a*%S" "${CONDA_BASE_DIR}") / 1024 / 1024 / 1024))
if ((SPACE_AVAILABLE <= SPACE_MINIMUM_REQUIRED)); then
    title 'Warning!'
    echo "Available space on '${CONDA_BASE_DIR}' is ${SPACE_AVAILABLE} G."
    echo "This is less than the minimum recommendation of ${SPACE_MINIMUM_REQUIRED} G."
    read -p "Press 'y' if you want to continue installing anwyway: " -n 1 -r
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Locations for conda installation, packet cache and virtual environments
CONDA_INSTALL_DIR="${CONDA_BASE_DIR}/conda"
CONDA_PACKET_CACHE_DIR="${CONDA_BASE_DIR}/conda_pkgs"
CONDA_ENV_DIR="${CONDA_BASE_DIR}/conda_envs"

# Abort if pre-existing installation is found
if [[ -d "${CONDA_INSTALL_DIR}" ]]; then
    if [[ -z "$(find "${CONDA_INSTALL_DIR}" -maxdepth 0 -type d -empty 2>/dev/null)" ]]; then
        title 'Checking installation path'
        echo "Already installed. The installation path '${CONDA_INSTALL_DIR}' is not empty."
        echo 'Aborting installation.'
        exit 1
    fi
fi

# Installer of choice for conda
CONDA_INSTALLER_URL='https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh'

# Unset pre-existing python paths
if [[ -n ${PYTHONPATH} ]]; then
    unset PYTHONPATH
fi

# Downlad latest version of miniconda and install it
title 'Downloading and installing conda'
wget -O miniconda.sh "${CONDA_INSTALLER_URL}" &&
    chmod +x miniconda.sh &&
    ./miniconda.sh -b -p "${CONDA_INSTALL_DIR}" &&
    rm ./miniconda.sh

# Configure conda
title 'Configuring conda'
eval "$(${CONDA_INSTALL_DIR}/bin/conda shell.bash hook)"
conda config --add pkgs_dirs "${CONDA_PACKET_CACHE_DIR}" --system
conda config --add envs_dirs "${CONDA_ENV_DIR}" --system
conda config --set auto_activate_base false
conda config --set default_threads "$(nproc)"
conda config --set pip_interop_enabled True
conda config --set channel_priority strict
conda deactivate

# Prevent conda base environment from using user site-packages
mkdir -p "${CONDA_INSTALL_DIR}/etc/conda/activate.d"
echo '#!/bin/bash
if [[ -n ${PYTHONUSERBASE} ]]; then
    declare -g "PYTHONUSERBASE_${CONDA_DEFAULT_ENV}=${PYTHONUSERBASE}"
    export "PYTHONUSERBASE_${CONDA_DEFAULT_ENV}"
    unset PYTHONUSERBASE
fi' >"${CONDA_INSTALL_DIR}/etc/conda/activate.d/disable-PYTHONUSERBASE.sh"
chmod +x "${CONDA_INSTALL_DIR}/etc/conda/activate.d/disable-PYTHONUSERBASE.sh"

mkdir -p "${CONDA_INSTALL_DIR}/etc/conda/deactivate.d"
echo '#!/bin/bash
COMBOVAR=PYTHONUSERBASE_${CONDA_DEFAULT_ENV}
COMBOVAR_CONTENT=${!COMBOVAR}
if [[ -n ${COMBOVAR_CONTENT} ]]; then
    declare -g "PYTHONUSERBASE=${COMBOVAR_CONTENT}"
    export PYTHONUSERBASE
    unset "PYTHONUSERBASE_${CONDA_DEFAULT_ENV}"
fi' >"${CONDA_INSTALL_DIR}/etc/conda/deactivate.d/reenable-PYTHONUSERBASE.sh"
chmod +x "${CONDA_INSTALL_DIR}/etc/conda/deactivate.d/reenable-PYTHONUSERBASE.sh"

# Update conda and conda base environment
title 'Updating conda and conda base environment'
conda update conda --yes
conda update -n 'base' --update-all --yes

# Clean installation
title 'Removing unused packages and caches'
conda clean --all --yes

# Improve perf
title 'Configuring conda'
conda update -n base conda
conda install -n base conda-libmamba-solver
conda config --set solver libmamba
conda config --set default_threads $(nproc)

# Display information about this conda installation
title 'Information about this conda installation'
conda info

# Display instructions for finalizing installation
GREEN='\033[0;32m'
RESET='\033[0m'
function green_title() {
    echo -e "${GREEN}$@${RESET}"
}
green_title 'Installation of conda is complete. Follow the instructions below to finalize.'

title 'Initialize conda immediately'
echo "eval \"\$(${CONDA_INSTALL_DIR}/bin/conda shell.bash hook)\""

title 'Automatically initialize conda for future shell sessions'
echo "echo '[[ -f ${CONDA_INSTALL_DIR}/bin/conda ]] && eval \"\$(${CONDA_INSTALL_DIR}/bin/conda shell.bash hook)\"' >> ${HOME}/.bashrc"

title 'Completely remove conda'
echo "rm -r ${CONDA_INSTALL_DIR} ${CONDA_INSTALL_DIR}_pkgs ${CONDA_INSTALL_DIR}_envs ${HOME}/.conda"
