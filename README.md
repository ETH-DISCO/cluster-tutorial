This guide will help you get started with the TIK cluster at ETH Zurich.

First, enable your VPN connection to the ETH network.

- VPN documentation: https://www.isg.inf.ethz.ch/Main/ServicesNetworkVPN
- Based on my experience the openconnect CLI doesn't work. So I suggest downloading the the Cisco-Anyconnect client and using the following settings:
	- server: `https://sslvpn.ethz.ch`
	- username: `<username>@student-net.ethz.ch`
	- password: your network password (also called Radius password, see: https://www.password.ethz.ch/)

Then ssh into the tik42 or j2tik login node and use your default password (also called LDAPS/AD password) and do some initial setup:

```bash
ssh <username>@tik42x.ethz.ch

# set slurm path
export SLURM_CONF=/home/sladmitet/slurm/slurm.conf

# clean up storage
find /home/$USER -mindepth 1 -maxdepth 1 ! -name 'public_html' -exec rm -rf {} +
rm -rf /scratch/$USER/*
rm -rf /scratch_net/$USER/*

# clean up cached deps
conda clean --all

# fix locale issues
unset LANG
unset LANGUAGE
unset LC_ALL
unset LC_CTYPE
echo 'export LANG=C.UTF-8' >> ~/.bashrc
export LANG=C.UTF-8
```

It's also recommended to use the following aliases to figure out which machines are still free. Add them to your `~/.bashrc.$USER` using the editor of your choice (ie. vim or nano). Don't forget to run `source ~/.bashrc.$USER` afterwards:

```bash
alias smon_free="grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt"
alias smon_mine="grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt"
alias watch_smon_free="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt\""
alias watch_smon_mine="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt\""
```

Once you're in you'll have access to:

- Compute: You can use compute-nodes for computation. The login-node is only for file management and job submission. Do not run any computation on the login-node.
- Storage: Use `/scratch/$USER` on the compute-nodes for temporary storage. Try to avoid using `/itet-stor/$USER/net_scratch` on the login-node.

Keep in mind:

- to use >8 GPUs you need your supervisor's permission and must reserve the nodes in advance in the shared calendar
- only submit jobs to `arton[01-08]`
- the A100s with 80GB on `tikgpu10` need special privileges
- the A6000s with 48GB on `tikgpu08` need special privileges
- set friendly `nice` values to your jobs, keep them small and preferably as array jobs

# a) Running Slurm jobs

First we will run our little MNIST example written with Pytorch using Slurm jobs.

```bash
# clone this repository
cd /itet-stor/$USER/net_scratch/cluster
git clone https://github.com/ETH-DISCO/cluster-tutorial/ .

# install conda
./conda_install.sh

# replace the placeholders with your actual username
sed 's/{{USERNAME}}/$USER/g' job.sh > job.sh
sed 's/{{USERNAME}}/$USER/g' job_array.sh > job_array.sh

# create job environment, dispatch job
conda env create -f conda-environment.yml
sbatch job.sh
sbatch job_array.sh

# check progress
watch -n 1 "squeue | grep $USER"
```

Once you're done you can check the output in `/itet-stor/{{USERNAME}}/net_scratch/cluster/jobs/`. Each filepointer your script writes to (ie. stderr, stdout) will have its own file.

# b) Using Conda

By running Slurm scripts you won't see the logs in real-time which can slow you down during development. For debugging or prototyping purposes it might make sense to attach your terminal to individual compute nodes and then execute scripts yourself. A jupyter notebook can also be convenient for this use-case:

```bash
# check node availability
grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt

# attach to a tikgpu06 node assuming it's free
srun --mem=50GB --gres=gpu:01 --nodelist tikgpu06 --pty bash -i

# set up storage
mkdir -p /scratch/$USER
cd /scratch/$USER

# run notebook
conda create --name jupyternb notebook --channel conda-forge
conda activate jupyternb
jupyter notebook --no-browser --port 5998 --ip $(hostname -f) # port range [5900-5999]
```

The last instruction will display a public link that you can then use to access the notebook.

To add additional dependencies once you're in the conda environment you will need to the following flags:

```bash
pip install <dependency> --upgrade --no-cache-dir --user --verbose

echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Make sure to deactivate the Conda environment when you're done:

```bash
conda deactivate
conda env list
conda remove --all --yes --name jupyternb
```

# c) Using Apptainer 🔥

The workflow introduced in the previous section with Conda is painfully slow in practice. – I believe that this is because NFS4 is sensitive to handling a large quantity of files, like those generated by Conda. This could explain why some file-related commands take up to an hour to run, while heavy computational tasks using CPU/GPU resources complete quickly. Fortunately compute nodes use the EXT4 filesystem which is significantly faster.

Fortunately, our admins provide Apptainer, a containerization tool similar to Docker but designed for HPC environments. I recommend using Apptainer over Conda and moving all dependencies to the compute-nodes.

Here's how:

```bash
# check node availability
grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt

# attach to a tikgpu06 node assuming it's free
# allocate 100GB of RAM and 1 GPU
srun --mem=100GB --gres=gpu:01 --nodelist tikgpu06 --pty bash -i

# clean up apptainer cache
rm -rf /scratch/$USER/*
rm -rf /scratch_net/$USER/*
mkdir -p /scratch/$USER
cd /scratch/$USER
apptainer cache clean
rm -rf "$PWD/.apptainer/cache"
rm -rf "$PWD/.apptainer/tmp"
mkdir -p "$PWD/.apptainer/cache"
mkdir -p "$PWD/.apptainer/tmp"
APPTAINER_CACHEDIR=/scratch/$USER/.apptainer/cache
export APPTAINER_TMPDIR=/scratch/$USER/.apptainer/tmp
export APPTAINER_BINDPATH="/scratch/$USER:/scratch/$USER"
export APPTAINER_CONTAIN=1

# disable pip cache
pip config set global.no-cache-dir false

# download apptainer sif
# for .def files see: `https://cloud.sylabs.io/builder`
apptainer build --disable-cache --sandbox /scratch/$USER/cuda_sandbox docker://nvcr.io/nvidia/pytorch:23.08-py3

# exec into apptainer
apptainer shell --nv \
  --bind "/scratch/$USER:/scratch/$USER" \
  --home /scratch/$USER/.apptainer/home:/home/$USER \
  --pwd /scratch/$USER \
  /scratch/$USER/cuda_sandbox \
  --containall
nvidia-smi

# store dependencies locally
export TMPDIR=/scratch/$USER/venv/.local
export PYTHONUSERBASE=/scratch/$USER/.local
export PYTHONNOUSERSITE=1
export PIP_CACHE_DIR=/scratch/$USER/.pip_cache
export PYTHONPATH=$PYTHONPATH:/scratch/$USER/site-packages

pip install --no-cache-dir --target=/scratch/$USER/site-packages virtualenv
/scratch/$USER/site-packages/bin/virtualenv ./venv
pip install --upgrade pip




# example dependency
pip install open_clip_torch --log piplog.txt




# run notebook
export JUPYTER_CONFIG_DIR=/scratch/$USER/.jupyter
export IPYTHONDIR=/scratch/$USER/.ipython
pip install --no-cache-dir jupyter
python -m ipykernel install --user --name=venv

# access via public ports
echo -e "\033[32mreplace 'hostname' in jupyter link with: '$(hostname -f):5998'\033[0m"
jupyter notebook --no-browser --port 5998 --ip $(hostname -f) # port range [5900-5999]
```

If you run out of storage when calling `pip install` make sure to use the `--log` flag to trace where additional dependencies get stored. You need to redirect them back to the current directory.

Some helpful commands to do so are:

```bash
export JUPYTER_DATA_DIR=/scratch/$USER/venv/jupyter_dir
export HF_HOME=/scratch/$USER/venv/HG_tmp
export TRANSFORMERS_CACHE=/scratch/$USER/venv/HG_tmp
export HUGGINGFACE_HUB_CACHE=/scratch/$USER/venv/HG_tmp
export TORCH_HOME=/scratch/$USER/venv/torch_tmp
```

Also see:

- https://github.com/huggingface/pytorch-image-models/discussions/790
- https://huggingface.co/docs/transformers/v4.38.1/en/installation#cache-setup

This setup will hopefully enable you to be more productive on the cluster.

# References

Fallback: If you're on a tight schedule and things aren't working out, you can always fall back to cloud GPU providers. The best free option is Google Colab with a Tesla T4 and 12 hours of runtime per session (as of August 2024).

Cloud GPU options include:

- https://cloud-gpus.com/
- https://getdeploying.com/reference/cloud-gpu

General documentation:

- best practices: https://computing.ee.ethz.ch/Services/HPCStorageIOBestPracticeGuidelines
- outdated tutorial: https://hackmd.io/hYACdY2aR1-F3nRdU8q5dA
- up-to-date tutorial: https://gitlab.ethz.ch/disco-students/cluster
- conda install: https://computing.ee.ethz.ch/Programming/Languages/Conda
- slurm docs: https://computing.ee.ethz.ch/Services/SLURM
- jupyter notebook docs: https://computing.ee.ethz.ch/FAQ/JupyterNotebook?highlight=%28notebook%29
- apptainer docs: https://computing.ee.ethz.ch/Services/Apptainer
- apptainer example: https://gitlab.ethz.ch/disco/social/apptainer-examples/

Thanks to:

- [@tkz10](https://github.com/TKZ10) for finding the pip redirection hack and for reviewing
- [@aplesner](https://github.com/aplesner) for the initial apptainer scripts and for reviewing
- [@ijorl](https://github.com/iJorl) for the initial slurm scripts
