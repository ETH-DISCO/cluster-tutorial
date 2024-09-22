#!/bin/bash
#SBATCH --mail-type=NONE # mail configuration: NONE, BEGIN, END, FAIL, REQUEUE, ALL
#SBATCH --output=/itet-stor/{{USERNAME}}/net_scratch/demo/jobs/%j.out # where to store the output (%j is the JOBID), subdirectories must exist
#SBATCH --error=/itet-stor/{{USERNAME}}/net_scratch/demo/jobs/%j.err # where to store error messages
#SBATCH --mem=20G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --exclude=tikgpu10,tikgpu[06-09]
#CommentSBATCH --nodelist=tikgpu01 # Specify that it should run on this particular node
#CommentSBATCH --account=tik-internal
#CommentSBATCH --constraint='titan_rtx|tesla_v100|titan_xp|a100_80gb'

set -o errexit # exit on error

# ------------------------------------------ end of configuration ------------------------------------------

DIRECTORY=/itet-stor/${USER}/net_scratch/demo
CONDA_ENVIRONMENT=demo
mkdir -p /itet-stor/${USER}/net_scratch/demo/jobs

# Set a directory for temporary files unique to the job with automatic removal at job termination
TMPDIR=$(mktemp -d)
if [[ ! -d ${TMPDIR} ]]; then
  echo 'Failed to create temp directory' >&2
  exit 1
fi
trap "exit 1" HUP INT TERM
trap 'rm -rf "${TMPDIR}"' EXIT
export TMPDIR
cd "${TMPDIR}"

# log some stuff

echo "running on node: $(hostname)"
echo "in directory: $(pwd)"
echo "starting on: $(date)"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"

[[ -f /itet-stor/${USER}/net_scratch/conda/bin/conda ]] && eval "$(/itet-stor/${USER}/net_scratch/conda/bin/conda shell.bash hook)"
conda activate ${CONDA_ENVIRONMENT}
echo "Conda activated"
cd ${DIRECTORY}

python job.py

echo "finished at: $(date)"
exit 0
