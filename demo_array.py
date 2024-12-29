import os
import sys
from pathlib import Path
import fcntl

def write_to_file(job_id):
    output_file = Path("/scratch") / os.environ["USER"] / "array-output.txt"
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_file, "a") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX) # acquire
        try:
            message = f"hello from {job_id}\n"
            f.write(message)
            f.flush()
            os.fsync(f.fileno())
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN) # release

if __name__ == "__main__":
    job_id = sys.argv[1]  # get the array job ID
    write_to_file(job_id)
