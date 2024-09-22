#!/bin/bash
#SBATCH --mail-type=NONE # disable email notifications can be [NONE, BEGIN, END, FAIL, REQUEUE, ALL]
#SBATCH --output=/itet-stor/{{USERNAME}}/net_scratch/slurm/%j.out # redirection of stdout (%j is the job id)
#SBATCH --error=/itet-stor/{{USERNAME}}/net_scratch/slurm/%j.err # redirection of stderr
#SBATCH --mem=100G
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --exclude=tikgpu[08-10]
#CommentSBATCH --nodelist=tikgpu01 # example: specify a node
#CommentSBATCH --account=tik-internal # example: charge a specific account
#CommentSBATCH --constraint='titan_rtx|tesla_v100|titan_xp|a100_80gb' # example: specify a gpu

rm -rf /itet-stor/${USER}/net_scratch/slurm
mkdir -p /itet-stor/${USER}/net_scratch/slurm

set -o errexit # exit on error

TMPDIR=$(mktemp -d) # create a temp directory for the job
if [[ ! -d ${TMPDIR} ]]; then
  echo 'Failed to create temp directory' >&2
  exit 1
fi
trap "exit 1" HUP INT TERM # exit on interrupt
trap 'rm -rf "${TMPDIR}"' EXIT # cleanup on exit
export TMPDIR
cd "${TMPDIR}"

echo "running on node: $(hostname)"
echo "in directory: $(pwd)"
echo "starting on: $(date)"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"

[[ -f /itet-stor/${USER}/net_scratch/conda/bin/conda ]] && eval "$(/itet-stor/${USER}/net_scratch/conda/bin/conda shell.bash hook)" # load conda
conda activate base

# ------------------------------------------------ run the job
conda env create --file /itet-stor/${USER}/net_scratch/cluster-tutorial/environment.yml
conda activate con
python /itet-stor/${USER}/net_scratch/cluster-tutorial/mnist.py

echo "finished at: $(date)"
exit 0
