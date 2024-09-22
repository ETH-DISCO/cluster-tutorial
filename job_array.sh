#!/bin/bash
#SBATCH --mail-type=NONE # mail configuration: NONE, BEGIN, END, FAIL, REQUEUE, ALL
#SBATCH --output=/itet-stor/{{USERNAME}}/net_scratch/cluster/jobs/%A-%a.out # where to store the output (%j is the JOBID), subdirectories must exist
#SBATCH --error=/itet-stor/{{USERNAME}}/net_scratch/cluster/jobs/%A-%a.err # where to store error messages
#SBATCH --mem=20G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --exclude=tikgpu10,tikgpu[06-09]
#SBATCH --array=0-3%2 # run 10 jobs in paralle, but only 2 at a time
#CommentSBATCH --nodelist=tikgpu01 # Specify that it should run on this particular node
#CommentSBATCH --account=tik-internal
#CommentSBATCH --constraint='titan_rtx|tesla_v100|titan_xp|a100_80gb'

ETH_USERNAME={{USERNAME}}

# ------------------------------------------ end of configuration ------------------------------------------

PROJECT_NAME=cluster
DIRECTORY=/itet-stor/$USER/net_scratch/${PROJECT_NAME}
CONDA_ENVIRONMENT=cluster-tutorial
mkdir -p ${DIRECTORY}/jobs

# Exit on errors
set -o errexit

# Set a directory for temporary files unique to the job with automatic removal at job termination
TMPDIR=$(mktemp -d)
if [[ ! -d ${TMPDIR} ]]; then
echo 'Failed to create temp directory' >&2
exit 1
fi
trap "exit 1" HUP INT TERM
trap 'rm -rf "${TMPDIR}"' EXIT
export TMPDIR

# Change the current directory to the location where you want to store temporary files, exit if changing didn't succeed.
# Adapt this to your personal preference
cd "${TMPDIR}" || exit 1

# Send some noteworthy information to the output log

echo "Running on node: $(hostname)"
echo "In directory: $(pwd)"
echo "Starting on: $(date)"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"
echo "SLURM_ARRAY_TASK_ID: ${SLURM_ARRAY_TASK_ID}"

[[ -f /itet-stor/$USER/net_scratch/conda/bin/conda ]] && eval "$(/itet-stor/$USER/net_scratch/conda/bin/conda shell.bash hook)"
conda activate ${CONDA_ENVIRONMENT}
echo "Conda activated"
cd ${DIRECTORY}

# Execute your code
# Here you want to use a different configuration depending on $SLUM_ARRAY_TASK_ID
python job_array.py ${SLURM_ARRAY_TASK_ID}

# Send more noteworthy information to the output log
echo "Finished at: $(date)"

# End the script with exit code 0
exit 0
