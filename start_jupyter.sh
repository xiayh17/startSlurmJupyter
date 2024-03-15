#!/bin/bash
#SBATCH --job-name=jupyter-notebook
#SBATCH --output=jupyter-log-%J.txt
#SBATCH --time=02:00:00
#SBATCH --mem=4G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1

# Load module or activate conda environment as needed
# Example: module load python/3.8
# Example: source activate myenv
# Any additional setup needed
eval "$(conda shell.bash hook)"

if ! conda list -n Jupyter | grep -q 'jupyter'; then
    echo "Error: Essential packages for Jupyter Notebook are missing in your conda environment."
    echo "To create a basic environment with Jupyter Notebook and essential packages, run:"
    echo "conda create -n Jupyter_basic python=3 jupyter"
    exit 1
fi

conda activate Jupyter

# Automatically find an available port
found_port=false
for port in {1718..8898}; do
  if ! lsof -i:$port >/dev/null 2>&1 && ! netstat -tuln | grep ":$port " >/dev/null 2>&1; then
    remote_port=$port
    echo "Found available port: $remote_port"
    found_port=true
    break
  fi
done

if ! $found_port; then
    echo "No available port found for Jupyter Notebook in Slurm."
    exit 1
fi

# Start Jupyter Notebook on the found available port
jupyter_log="${HOME}/jupyter_notebook.log"
jupyter_port="${HOME}/jupyter_port.txt"
# Check file exists. if there, delete it
if [ -f "$jupyter_log" ]; then
    rm "$jupyter_log"
fi
if [ -f "$jupyter_port" ]; then
    rm "$jupyter_port"
fi
jupyter notebook --no-browser --ip='*' --port=$remote_port > "$jupyter_log" 2>&1 &
jupyter_pid=$!

# Wait for Jupyter Notebook to start and write the port into a file
max_attempts=20
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if [ -f "$jupyter_log" ]; then
        echo "Jupyter Notebook log file found: $jupyter_log"
        if grep -q "Jupyter Server.*is running at:" "$jupyter_log"; then
            echo $remote_port > "${HOME}/jupyter_port.txt"
            echo "jupyter_port.txt saved in path: ${HOME}/jupyter_port.txt"
            echo "Jupyter Notebook started on port $remote_port."
            break
        fi
    else
        echo "Jupyter Notebook log file not found: $jupyter_log. $attempt/$max_attempts" 
    fi
    attempt=$((attempt + 1))
    sleep 5
done

# Check if Jupyter Notebook started successfully
if [ $attempt -eq $max_attempts ]; then
    echo "Error: Jupyter Notebook startup not detected after $max_attempts attempts."
    echo "Please check the Jupyter Notebook log file: $jupyter_log"
    # Kill the Jupyter Notebook process if it's still running
    kill $jupyter_pid 2>/dev/null
    wait $jupyter_pid 2>/dev/null
    exit 1
fi

# Keep the Slurm job running until it is canceled or reaches the time limit
echo "Jupyter Notebook is running. The Slurm job will continue until it is canceled or reaches the time limit."
wait $jupyter_pid