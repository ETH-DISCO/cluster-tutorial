This guide will help you get started with the TIK cluster at ETH Zurich.

# 1. SSH into the cluster

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

- Compute: The login node is only for file management and job submission. Do not run any computation on the login node. Run batch jobs on the compute nodes using the SLURM system.
- Storage: Use `/itet-stor/<username>/net_scratch` on the login node and `/scratch/<username>` on the compute nodes for temporary storage.

To upload your files to the storage you can use `scp` or clone your git repository directly on the cluster:

```bash
scp -r /path/to/local/folder <username>@tik42x.ethz.ch:/itet-stor/<username>/net_scratch
```

Keep in mind:

- to use >8 GPUs you need your supervisor's permission and reserve the nodes in advance in the shared calendar
- only submit jobs to `arton[01-08]`
	- see all available nodes using `sinfo`
	- the A100s with 80GB on `tikgpu10` need special privileges
	- the A6000s with 48GB on `tikgpu08` need special privileges
- set friendly `nice` values to your jobs, keep them small and preferably as array jobs

# 2. Setup

First add the following instructions to your `~/.bashrc.<username>` file and then run `source ~/.bashrc.<username>`:

```bash
# convenience commands for slurm
export SLURM_CONF=/home/sladmitet/slurm/slurm.conf
alias smon_free="grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt"
alias smon_mine="grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt"
alias watch_smon_free="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp 'free|$' /home/sladmitet/smon.txt\""
alias watch_smon_mine="watch --interval 300 --no-title --differences --color \"grep --color=always --extended-regexp '${USER}|$' /home/sladmitet/smon.txt\""
```

Next run the `install_conda.sh` script to install Conda.

# 3. Submit batch jobs

Here's a simple example on how to run a simple MNIST Pytorch script through Slurm:

```bash
cd /itet-stor/<username>/net_scratch/cluster # ... copy your files here

# replace {{USERNAME}} with your <username> in the job script
sed 's/{{USERNAME}}/<username>/g' job.sh > job.sh
sed 's/{{USERNAME}}/<username>/g' job_array.sh > job_array.sh

# create job environment, dispatch job
conda env create -f conda-environment.yml
sbatch job.sh
sbatch job_array.sh

# check progress
watch -n 1 "squeue | grep '<username>'"
```

Once you're done you can check the output in `check output in /itet-stor/{{USERNAME}}/net_scratch/cluster/jobs/`. The output will be in the form of `<jobid>.out` or `<jobid>.err`.

# Debugging and Prototyping

Job scripts don't show the output in real time.

For debugging or prototyping purposes it might make sense to attach your terminal to individual compute nodes.

```bash
# check node availability
smon_free
squeue --Format=jobarrayid:9,state:10,partition:14,reasonlist:16,username:10,tres-alloc:47,timeused:11,command:140,nodelist:20

# attach to a tikgpu06 node assuming it's free
srun  --mem=25GB --gres=gpu:01 --nodelist tikgpu06 --pty bash -i

# set up storage
mkdir -p /scratch/<username>
```

Next you can activate run a jupyter notebook on the compute node and access it through your browser using the following commands:

```bash
conda create --name jupyternb notebook --channel conda-forge
conda activate jupyternb
jupyter notebook --no-browser --port 5998 --ip $(hostname -f) # port range [5900-5999]
```

The output will then show you at which link you can access the notebook.

Make sure to deactivate the conda environment after you're done:

```bash
conda deactivate
conda env list
conda remove --all --yes --name jupyternb
exit # back to login node
```


# Troubleshooting

Error messages because of misconfigured locale:

```bash
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=UTF-8
export LANG=C.UTF-8
```

Pip dependencies take too long to resolve:

```bash
pip install <dependency> --upgrade --no-cache-dir --user --verbose
```

Fallback: If you're on a tight schedule and things aren't working out, you can always fall back to cloud GPU providers. The best free option is Google Colab with a Tesla T4 and 12 hours of runtime per session (as of August 2024). Other options include:

- https://cloud-gpus.com/
- https://getdeploying.com/reference/cloud-gpu

# References

Documentation:

- outdated tutorial: https://hackmd.io/hYACdY2aR1-F3nRdU8q5dA
- up-to-date tutorial: https://gitlab.ethz.ch/disco-students/cluster
- conda install: https://computing.ee.ethz.ch/Programming/Languages/Conda
- slurm docs: https://computing.ee.ethz.ch/Services/SLURM
- jupyter notebook docs: https://computing.ee.ethz.ch/FAQ/JupyterNotebook?highlight=%28notebook%29
- apptainer docs: https://computing.ee.ethz.ch/Services/Apptainer
- apptainer example: https://gitlab.ethz.ch/disco/social/apptainer-examples/

Thanks to:

- [Joel Mathys](https://github.com/iJorl) for the Slurm scripts
- [Andreas Plesner](https://github.com/aplesner) for the Apptainer scripts and Hackmd tutorial

