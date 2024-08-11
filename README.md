This guide will help you get started with the TIK cluster at ETH Zurich.

# 1. SSHing into the cluster

First, enable your VPN connection to the ETH network.

- VPN documentation: https://www.isg.inf.ethz.ch/Main/ServicesNetworkVPN
- Based on my experience the openconnect CLI doesn't work. So I suggest downloading the the Cisco-Anyconnect client and using the following settings:
	- server: `https://sslvpn.ethz.ch`
	- username: `<username>@student-net.ethz.ch`
	- password: your network password (also called Radius password, see: https://www.password.ethz.ch/)

Then ssh into the tik42 or j2tik login node and use your default password (also called LDAPS/AD password).

```bash
ssh <username>@tik42x.ethz.ch
```

Once you're in you'll have access to:

- Compute: The login node is only for file management and job submission. Do not run any computation on the login node.
- Storage: Use `/scratch/$USER` on the compute-nodes for temporary storage. Try to avoid using `/itet-stor/$USER/net_scratch/cluster` on the login-node.

Keep in mind:

- to use >8 GPUs you need your supervisor's permission and must reserve the nodes in advance in the shared calendar
- only submit jobs to `arton[01-08]`
- the A100s with 80GB on `tikgpu10` need special privileges
- the A6000s with 48GB on `tikgpu08` need special privileges
- set friendly `nice` values to your jobs, keep them small and preferably as array jobs

# 2. Running SLURM jobs

Before running a demo job, let's first add the following aliases to your `~/.bashrc.$USER` using the editor of your choice (ie. vim or nano). Don't forget to run `source ~/.bashrc.$USER` afterwards:

```bash
# convenience commands for slurm
export SLURM_CONF=/home/sladmitet/slurm/slurm.conf
alias smon_free="grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt"
alias smon_mine="grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt"
alias watch_smon_free="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt\""
alias watch_smon_mine="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt\""
```

Next we will run our little MNIST example written with Pytorch:

```bash
# clone this repository
cd /itet-stor/$USER/net_scratch/cluster
git clone https://github.com/ETH-DISCO/cluster-tutorial/
mv ./cluster-tutorial .

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

# 3. Using Conda

By running Slurm scripts you won't see the logs in real-time which can slow you down during development. For debugging or prototyping purposes it might make sense to attach your terminal to individual compute nodes and then execute scripts yourself. A jupyter notebook can also be convenient for this use-case:

```bash
# check node availability
smon_free
squeue --Format=jobarrayid:9,state:10,partition:14,reasonlist:16,username:10,tres-alloc:47,timeused:11,command:140,nodelist:20

# attach to a tikgpu06 node assuming it's free
srun --mem=250GB --gres=gpu:01 --nodelist tikgpu06 --pty bash -i

# set up storage
mkdir -p /scratch/$USER
cd /scratch/$USER

# run notebook
conda create --name jupyternb notebook --channel conda-forge
conda activate jupyternb
jupyter notebook --no-browser --port 5998 --ip $(hostname -f) # port range [5900-5999]
```

The last instruction will display a public link that you can then use to access the notebook.

To add additional dependencies you will need to add the following flags:

```bash
pip install <dependency> --upgrade --no-cache-dir --user --verbose

echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Make sure to deactivate the conda environment after you're done:

```bash
conda deactivate
conda env list
conda remove --all --yes --name jupyternb
exit # back to login node
```

# 4. Using Apptainer

The workflow introduced in the previous section with Conda is painfully slow in practice. – I believe that this is because NFS4 is sensitive to handling a large quantity of files, like those generated by Conda. This could explain why some file-related commands take up to an hour to run, while heavy computational tasks using CPU/GPU resources complete quickly.

Fortunately, our admins provide Apptainer, a containerization tool similar to Docker but designed for HPC environments. I recommend using Apptainer over Conda and moving all dependencies to the compute-nodes.

Here's how:

```bash
# check node availability
smon_free
squeue --Format=jobarrayid:9,state:10,partition:14,reasonlist:16,username:10,tres-alloc:47,timeused:11,command:140,nodelist:20

# attach to a tikgpu06 node assuming it's free
srun --mem=250GB --gres=gpu:01 --nodelist tikgpu06 --pty bash -i

# set up storage (filesystem should be ext4, so a lot faster)
mkdir -p /scratch/$USER
cd /scratch/$USER

# download sif (we don't have sudo privileges do build a .def file ourselves)
apptainer build --sandbox /scratch/$USER/cuda_sandbox docker://nvcr.io/nvidia/pytorch:23.08-py3
apptainer shell --nv /scratch/$USER/cuda_sandbox
nvidia-smi

pip install --upgrade pip

# run notebook
pip install --no-cache-dir jupyter
jupyter notebook --no-browser --port 5998 --ip $(hostname -f) # port range [5900-5999]
```

To tear everything down:

```bash
deactivate # exit venv
exit # exit apptainer
rm -rf ./* # wipe all dependencies
```

# References

Fallback: If you're on a tight schedule and things aren't working out, you can always fall back to cloud GPU providers. The best free option is Google Colab with a Tesla T4 and 12 hours of runtime per session (as of August 2024). Other options include:

- https://cloud-gpus.com/
- https://getdeploying.com/reference/cloud-gpu

General documentation:

- outdated tutorial: https://hackmd.io/hYACdY2aR1-F3nRdU8q5dA
- up-to-date tutorial: https://gitlab.ethz.ch/disco-students/cluster
- conda install: https://computing.ee.ethz.ch/Programming/Languages/Conda
- slurm docs: https://computing.ee.ethz.ch/Services/SLURM
- jupyter notebook docs: https://computing.ee.ethz.ch/FAQ/JupyterNotebook?highlight=%28notebook%29
- apptainer docs: https://computing.ee.ethz.ch/Services/Apptainer
- apptainer example: https://gitlab.ethz.ch/disco/social/apptainer-examples/

Thanks to:

- [Joel Mathys](https://github.com/iJorl) for the Slurm scripts
- [Andreas Plesner](https://github.com/aplesner) for introducing me to Apptainer
