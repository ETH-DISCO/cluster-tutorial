This guide will help you get started with the TIK cluster at ETH Zurich.

First, enable your VPN connection[^vpn] to the ETH network through a client of your choice (preferably the Cisco-Anyconnect client[^cisco]) using the following configuration:

- server: `https://sslvpn.ethz.ch`
- username: `<username>@student-net.ethz.ch`
- password: your network password (Radius password[^pwd])

Then just ssh into the tik42 or j2tik login node using your default password (LDAPS/AD password):

```bash
ssh <username>@tik42x.ethz.ch
```

Once you're in you'll have access to:

- The login node:
	- Compute: Not permitted. The login-node is only for file management and job submission. Do not run any computation on the login-node (or you will get in trouble!).
	- Storage: Slow and small but non-volatile. Accessible through `/scratch/$USER`. Limited to just 8GB and uses the NFS4 instead of the EXT4 filesystem which is slower by a wide margin.
- The compute nodes:
	- Compute: Intended for compute. But bewared that sessions are limited to just 12h in interactive shells and background processes will be killed as soon you log out. Make sure to run long running processes via SLURM batch jobs, which can run 72h.
	- Storage: Fast and large but volatile. Accessible through `/itet-stor/$USER/net_scratch` (requires your shell to be attached). Uses the EXT4 filesystem.

Keep in mind:

- to use >8 GPUs you need your supervisor's permission and must reserve the nodes in advance in the shared calendar
- only submit jobs to `arton[01-08]`
- the A100s with 80GB on `tikgpu10` need special privileges
- the A6000s with 48GB on `tikgpu08` need special privileges
- set friendly `nice` values to your jobs, keep them small and preferably as array jobs

# Initialization

To set everything up, run:

```bash
# set slurm path
export SLURM_CONF=/home/sladmitet/slurm/slurm.conf

# clean up storage
find /home/$USER -mindepth 1 -maxdepth 1 ! -name 'public_html' -exec rm -rf {} +
rm -rf /scratch/$USER/*
rm -rf /scratch_net/$USER/*
cd /itet-stor/$USER/net_scratch/
shopt -s extglob
rm -rf !("conda"|"conda_pkgs")
shopt -u extglob

# fix locale issues
unset LANG
unset LANGUAGE
unset LC_ALL
unset LC_CTYPE
echo 'export LANG=C.UTF-8' >> ~/.bashrc
export LANG=C.UTF-8

# convenience aliases for ~/.bashrc.$USER
alias ll="ls -alF"
alias smon_free="grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt"
alias smon_mine="grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt"
alias watch_smon_free="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt\""
alias watch_smon_mine="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt\""

# install conda
cd /itet-stor/$USER/net_scratch/
if [ ! -d "/itet-stor/${USER}/net_scratch/conda" ] && [ ! -d "/itet-stor/${USER}/net_scratch/conda_pkgs" ]; then
  git clone https://github.com/ETH-DISCO/cluster-tutorial/ && mv cluster-tutorial/install-conda.sh . && rm -rf cluster-tutorial # only keep install-conda.sh
  chmod +x ./install-conda.sh && ./install-conda.sh
  eval "$(/itet-stor/$USER/net_scratch/conda/bin/conda shell.bash hook)" # conda activate base
  echo '[[ -f /itet-stor/${USER}/net_scratch/conda/bin/conda ]] && eval "$(/itet-stor/${USER}/net_scratch/conda/bin/conda shell.bash hook)"' >> ~/.bashrc # add to bashrc
fi
```

# a) Running Slurm jobs

You can run longer running tasks using Slurm jobs. Here's a quick demo using MNIST.

```bash
# check node availability
grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt

# attach to a node (assuming it's free)
srun --mem=100GB --gres=gpu:01 --nodelist tikgpu07 --pty bash -i

#
# clone and choose script
#

cd /scratch/$USER
rm -rf ./*

git clone https://github.com/ETH-DISCO/cluster-tutorial/ && cd cluster-tutorial
FILEPATH="./mnist.py"

#
# dispatch job
#

# create environment.yml
eval "$(/itet-stor/$USER/net_scratch/conda/bin/conda shell.bash hook)" # conda activate base
if conda env list | grep -q "^con "; then
    read -p "the 'con' environment already exists. do you want to remove and recreate it? (y/n): " answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        echo "removing existing 'con' environment..."
        conda remove --yes --name con --all
        rm -rf /itet-stor/$USER/net_scratch/conda_envs/con && conda remove --yes --name con --all || true
    fi
fi
conda env create --file environment.yml
conda info --envs

# dispatch job
git clone https://github.com/ETH-DISCO/cluster-tutorial/ && mv cluster-tutorial/job.sh . && rm -rf cluster-tutorial # get job.sh
sed -i 's/{{USERNAME}}/'$USER'/g' job.sh # template username
sed -i 's/{{NODE}}/'tikgpu07'/g' job.sh # template node
sbatch job.sh $FILEPATH

# check status
watch -n 1 "squeue | grep $USER"
ls -v cd /scratch/$USER/slurm/* | tail -n 1 | xargs cat
```

# b) Prototyping within an Apptainer

Here's how to spin up an Apptainer and start working within it:

```bash
# check node availability
grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt

# attach to a node (assuming it's free) and allocate 100GB of RAM and 1 GPU
srun --mem=100GB --gres=gpu:01 --nodelist tikgpu07 --pty bash -i

#
# step 1
#

# clean user files and apptainer cache
rm -rf /scratch/$USER/*
rm -rf /scratch_net/$USER/*
mkdir -p /scratch/$USER
cd /scratch/$USER
yes | apptainer cache clean
rm -rf "$PWD/.apptainer/cache"
rm -rf "$PWD/.apptainer/tmp"
mkdir -p "$PWD/.apptainer/cache"
mkdir -p "$PWD/.apptainer/tmp"
APPTAINER_CACHEDIR=/scratch/$USER/.apptainer/cache
export APPTAINER_TMPDIR=/scratch/$USER/.apptainer/tmp
export APPTAINER_BINDPATH="/scratch/$USER:/scratch/$USER"
export APPTAINER_CONTAIN=1

# download apptainer sif
# for .def files see: `https://cloud.sylabs.io/builder`
apptainer build --disable-cache --sandbox /scratch/$USER/cuda_sandbox docker://nvcr.io/nvidia/pytorch:23.08-py3

#
# step 2
#

# exec into apptainer
apptainer shell --nv --bind "/scratch/$USER:/scratch/$USER" --home /scratch/$USER/.apptainer/home:/home/$USER --pwd /scratch/$USER /scratch/$USER/cuda_sandbox --containall

# set env variables
# see: https://github.com/huggingface/pytorch-image-models/discussions/790
# see: https://huggingface.co/docs/transformers/v4.38.1/en/installation#cache-setup
alias ll="ls -alF"
mkdir -p /scratch/$USER/apptainer_env/venv/.local
export TMPDIR=/scratch/$USER/apptainer_env/venv/.local
mkdir -p /scratch/$USER/apptainer_env/.local
export PYTHONUSERBASE=/scratch/$USER/apptainer_env/.local
export PYTHONNOUSERSITE=1
mkdir -p /scratch/$USER/apptainer_env/pip_cache
export PIP_CACHE_DIR=/scratch/$USER/apptainer_env/pip_cache
mkdir -p /scratch/$USER/apptainer_env/site_packages
export PYTHONPATH=$PYTHONPATH:/scratch/$USER/apptainer_env/site_packages
mkdir -p /scratch/$USER/apptainer_env/jupyter_data
export JUPYTER_DATA_DIR=/scratch/$USER/apptainer_env/jupyter_data
mkdir -p /scratch/$USER/apptainer_env/hf_cache
export HF_HOME=/scratch/$USER/apptainer_env/hf_cache
mkdir -p /scratch/$USER/apptainer_env/hf_cache
export TRANSFORMERS_CACHE=/scratch/$USER/apptainer_env/hf_cache
mkdir -p /scratch/$USER/apptainer_env/hf_cache
export HUGGINGFACE_HUB_CACHE=/scratch/$USER/apptainer_env/hf_cache
mkdir -p /scratch/$USER/apptainer_env/torch_cache
export TORCH_HOME=/scratch/$USER/apptainer_env/torch_cache
mkdir -p /scratch/$USER/apptainer_env/lightning_logs
export LIGHTNING_LOGS=/scratch/$USER/apptainer_env/lightning_logs
mkdir -p /scratch/$USER/apptainer_env/checkpoints
export PL_CHECKPOINT_DIR=/scratch/$USER/apptainer_env/checkpoints
mkdir -p /scratch/$USER/apptainer_env/tensorboard_logs
export TENSORBOARD_LOGDIR=/scratch/$USER/apptainer_env/tensorboard_logs
mkdir -p /scratch/$USER/apptainer_env/cuda_cache
export CUDA_CACHE_PATH=/scratch/$USER/apptainer_env/cuda_cache
export OMP_NUM_THREADS=1 # avoid oversubcription in multigpu
export MKL_NUM_THREADS=1 # avoid oversubcription in multigpu

# make venv
pip install --no-cache-dir --target=/scratch/$USER/apptainer_env/site_packages virtualenv
/scratch/$USER/apptainer_env/site_packages/bin/virtualenv /scratch/$USER/apptainer_env/venv
source /scratch/$USER/apptainer_env/venv/bin/activate
export PIP_NO_CACHE_DIR=false

#
# demo
#

# installing and running pytorch
pip install --upgrade pip
rm -rf /scratch/$USER/piplog.txt
pip install --no-cache-dir --log /scratch/$USER/piplog.txt torch torchvision torchaudio
cat << EOF > demo.py
import torch
free_memory, total = torch.cuda.mem_get_info()
print(f"CUDA available: {torch.cuda.is_available()}")
EOF
echo "number of GPUs: $(nvidia-smi --list-gpus | wc -l)" # sanity check
python3 demo.py # should print true

#
# jupyterlab for convenience
#

# install JupyterLab
mkdir -p /scratch/$USER/apptainer_env/jupyter_config
export JUPYTER_CONFIG_DIR=/scratch/$USER/apptainer_env/jupyter_config
mkdir -p /scratch/$USER/apptainer_env/ipython_config
export IPYTHONDIR=/scratch/$USER/apptainer_env/ipython_config
pip install --no-cache-dir jupyterlab jupyter
python -m ipykernel install --user --name=venv

echo "> http://$(hostname -f):5998"
jupyter lab --no-browser --port 5998 --ip $(hostname -f) # port range [5900-5999]
```

# Footnotes

General documentation:

- best practices: https://computing.ee.ethz.ch/Services/HPCStorageIOBestPracticeGuidelines
- outdated tutorial: https://hackmd.io/hYACdY2aR1-F3nRdU8q5dA
- up-to-date tutorial: https://gitlab.ethz.ch/disco-students/cluster
- conda install: https://computing.ee.ethz.ch/Programming/Languages/Conda
- slurm docs: https://computing.ee.ethz.ch/Services/SLURM
- jupyter notebook docs: https://computing.ee.ethz.ch/FAQ/JupyterNotebook?highlight=%28notebook%29
- apptainer docs: https://computing.ee.ethz.ch/Services/Apptainer
- apptainer example: https://gitlab.ethz.ch/disco/social/apptainer-examples/
- cloud GPU as fallback: https://cloud-gpus.com/ and https://getdeploying.com/reference/cloud-gpu

Thanks to:
 
- [@tkz10](https://github.com/TKZ10) for finding the dependency redirection hack and reviewing
- [@aplesner](https://github.com/aplesner) for the initial apptainer scripts and reviewing
- [@ijorl](https://github.com/iJorl) for the initial slurm scripts

[^vpn]: See: https://www.isg.inf.ethz.ch/Main/ServicesNetworkVPN
[^pwd]: See: https://www.password.ethz.ch/
[^cisco]: Based on my experience the openconnect CLI doesn't work. So I suggest downloading the the [Cisco-Anyconnect client](https://apps.apple.com/at/app/cisco-secure-client/id1135064690?l=en-GB)
