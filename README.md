# Jupyter Notebook on Slurm Cluster

This repository contains two scripts that automate the process of starting a Jupyter Notebook on a Slurm cluster and setting up an SSH tunnel for easy access.

## Prerequisites

- Access to a Slurm cluster
- A conda environment with Jupyter Notebook and essential packages installed

## Quick Start Guide

1. **Setup Environment**: Clone the repository, ensure you have a conda environment with Jupyter Notebook. Use `conda create -n Jupyter python=3 jupyter` to create one if needed, and modify `start_forwarded_jupyter.sh` with your environment details.

2. **Launch Jupyter Notebook**: Execute `start_forwarded_jupyter.sh` to submit a Jupyter Notebook job to the Slurm cluster, set up an SSH tunnel, and access your notebook through a provided URL.

3. **Close Session**: To end your Jupyter Notebook session, press Enter in the terminal running `start_forwarded_jupyter.sh` to cancel the Slurm job and terminate the SSH tunnel.


## Usage

1. Clone this repository to your local machine.

2. Make sure you have a conda environment with Jupyter Notebook and essential packages installed. If you don't have one, you can create a basic environment with the following command:

   ```
   conda create -n Jupyter python=3 jupyter
   ```

   Modify the `start_forwarded_jupyter.sh`
   * slurm config
   * repalce the conda environment with yours

3. Run the `start_forwarded_jupyter.sh` script on your local machine. This script will guide you through the process of selecting a host or creating a new one, generating an SSH key pair if needed, and setting up the SSH tunnel.

4. The script will submit a Jupyter Notebook job to the Slurm cluster using the `start_jupyter.sh` script. It will wait for the job to start running and then set up the SSH tunnel.

5. Once the SSH tunnel is set up, you will see a message indicating the URL where you can access the Jupyter Notebook (e.g., `http://127.0.0.1:1718`).

6. To stop the Jupyter Notebook session, press Enter in the terminal where the `start_forwarded_jupyter.sh` script is running. The script will cancel the Slurm job and close the SSH tunnel.

## FAQ

**Q: What if I don't have a conda environment with Jupyter Notebook installed?**

A: The `start_jupyter.sh` script checks if the necessary packages are installed in your conda environment. If they are missing, it will provide instructions on how to create a basic environment with Jupyter Notebook and essential packages.

**Q: Can I use an existing SSH key pair?**

A: Yes, if you already have an SSH key pair that you want to use, you can select the existing host from the menu or provide the path to your key file when creating a new host.

**Q: What if the script fails to set up the SSH tunnel?**

A: If the script encounters any issues while setting up the SSH tunnel, it will display error messages indicating the problem. Make sure you have provided the correct host information and that your SSH key pair is properly configured.

**Q: How can I customize the Jupyter Notebook configuration?**

A: The `start_jupyter.sh` script contains the Slurm job configuration and Jupyter Notebook startup commands. You can modify this script to adjust the resource requirements, load modules, activate conda environments, or add additional Jupyter Notebook options as needed.

# Adding Kernels to Jupyter Notebook
Once you have successfully connected to your Jupyter Notebook, you may want to use different kernels (e.g., different Python or R versions) for your notebooks. Here's how you can add kernels to your Jupyter Notebook:

## Python Kernels
Create a new conda environment with the desired Python version and necessary packages. For example, to create an environment with Python 3.7:

```
conda create -n py37 python=3.7 ipykernel
```

Activate the new environment:

```
conda activate py37
```

Install the IPython kernel package if it's not already installed:

```
conda install ipykernel
```

Register the environment as a kernel in Jupyter Notebook:

```
python -m ipykernel install --user --name py37 --display-name "Python 3.7"
```

This command will create a new kernel named "Python 3.7" that uses the py37 conda environment.
Repeat steps 1-4 for any additional Python versions you want to use as kernels.

## R Kernels

Create a new conda environment for your R kernel:

```
conda create -n r_env r-essentials r-irkernel
```

Activate the new environment:

```
conda activate r_env
```

Register the environment as a kernel in Jupyter Notebook:

```
R -e "IRkernel::installspec(name = 'r_env', displayname = 'R')"
```

This command will create a new kernel named "R" that uses the r_env conda environment.
Repeat steps 2-4 for any additional R versions you want to use as kernels.
After adding the desired kernels, restart your Jupyter Notebook. You should now see the new kernels available in the "New" dropdown menu when creating a new notebook.

Note: Make sure to activate the appropriate conda environment before installing packages or registering kernels to ensure they are associated with the correct environment.

License
This project is licensed under the MIT License.