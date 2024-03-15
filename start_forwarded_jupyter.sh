#!/bin/bash

# Function to display a menu and get user input
display_menu() {
    echo "Please select a host:"
    for ((i=1; i<=$#; i++)); do
        echo "$i. ${!i}"
    done
    echo "0. Create a new host"
    read -p "Enter your choice: " choice
    echo "$choice"
}

# Function to get host details from user input
get_host_details() {
    read -p "Enter host alias: " host_alias
    read -p "Enter username: " user
    read -p "Enter hostname or IP: " hostname
    read -p "Enter port (default is 22): " port
    port=${port:-22}
}

# Function to add or update a host in the SSH config file
update_ssh_config() {
    local config_file="$HOME/.ssh/config"
    local host_entry="Host $host_alias\n  HostName $hostname\n  User $user\n  Port $port\n  IdentityFile ~/.ssh/id_rsa_jupyter\n"
    
    if grep -q "^Host $host_alias$" "$config_file"; then
        # Update existing host entry
        sed -i "/^Host $host_alias$/,/^$/c\\$host_entry" "$config_file"
    else
        # Add new host entry
        echo "\n$host_entry" >> "$config_file"
    fi
}

# function to generate an SSH key pair
generate_ssh_key() {
    local key_file="$HOME/.ssh/id_rsa_jupyter"
    if [ -f "$key_file" ] || [ -f "$key_file.pub" ]; then
        read -p "SSH key files already exist. Do you want to overwrite them? (y/n): " overwrite
        if [ "$overwrite" == "y" ] || [ "$overwrite" == "Y" ]; then
            ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -q >/dev/null 2>&1
            echo "SSH key pair generated: $key_file"
        else
            echo "Existing SSH key pair will be used."
        fi
    else
        ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -q >/dev/null 2>&1
        echo "SSH key pair generated: $key_file"
    fi
}

# Function to check if an IdentityFile is present in the SSH config
check_identity_file() {
    local config_content=$(sed -n "/^Host $host_alias$/,/^$/p" "$ssh_config_file")
    local identity_file=$(echo "$config_content" | awk '/^[[:space:]]*IdentityFile[[:space:]]+/ {print $2}')
    
    if [ -z "$identity_file" ]; then
        read -p "No IdentityFile found for the chosen host. Do you want to add one? (y/n): " add_identity_file
        if [ "$add_identity_file" == "y" ] || [ "$add_identity_file" == "Y" ]; then
            identity_file="$HOME/.ssh/id_rsa_jupyter"
            sed -i "/^Host $host_alias$/,/^$/a \  IdentityFile $identity_file" "$ssh_config_file"
            echo "IdentityFile added to the SSH config: $identity_file"
        else
            echo "Proceeding without adding an IdentityFile to the SSH config."
        fi
    else
        echo "IdentityFile found in the SSH config: $identity_file"
    fi
}

# Function to copy the public key to the login node
copy_public_key() {
    local key_file="$HOME/.ssh/id_rsa_jupyter.pub"
    if [ -n "$user" ] && [ -n "$login_node" ] && [ -n "$login_node_port" ]; then
        ssh-copy-id -i "$key_file" -p "${login_node_port}" "${user}@${login_node}"
    else
        echo "Error: User, login node, or port not set. Skipping ssh-copy-id."
    fi
}

# Read hosts from SSH config file
ssh_config_file="$HOME/.ssh/config"
ssh_hosts=()

# Check if the SSH config file exists
if [ -f "$ssh_config_file" ]; then
    # Read the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Extract the host alias
        if [[ $line =~ ^Host[[:space:]]+([^*].+)$ ]]; then
            ssh_hosts+=("${BASH_REMATCH[1]}")
        fi
    done < "$ssh_config_file"
fi

# Check if any hosts are available
if [ ${#ssh_hosts[@]} -eq 0 ]; then
    echo "No host options available. Please create a new host."
    get_host_details
    update_ssh_config
else
    # Display menu and get user selection
    display_menu "${ssh_hosts[@]}"

    if [ "$choice" = "0" ]; then
        get_host_details
        update_ssh_config
        
        echo "Selected host:"
        echo "Host alias: $host_alias"
        echo "User: $user"
        echo "Hostname: $hostname"
        echo "Port: $port"

        # Set variables for ssh-copy-id
        login_node=$hostname
        login_node_port=$port

        # Copy the public key to the remote machine
        copy_public_key

    else
        selected_index=$((choice - 1))
        host_alias="${ssh_hosts[$selected_index]}"
        
        # Extract host details from SSH config file
        config_content=$(sed -n "/^Host $host_alias$/,/^$/p" "$ssh_config_file")
        user=$(echo "$config_content" | awk '/^[[:space:]]*User[[:space:]]+/ {print $2}')
        hostname=$(echo "$config_content" | awk '/^[[:space:]]*HostName[[:space:]]+/ {print $2}')
        port=$(echo "$config_content" | awk '/^[[:space:]]*Port[[:space:]]+/ {print $2}')
        
        # Set variables for ssh-copy-id
        login_node=$hostname
        login_node_port=$port
        
        # Check if IdentityFile is specified for the chosen host
        check_identity_file
        
        echo "Selected host:"
        echo "Host alias: $host_alias"
        echo "User: $user"
        echo "Hostname: $hostname"
        echo "Port: $port"
    fi
fi

# Variables
user=$user
login_node=$host_alias
login_node_port=$port

# Copy the Jupyter start script to the login node
scp -P "${login_node_port}" start_jupyter.sh "${user}@${login_node}:~/"

# Submit the Jupyter notebook job
job_output=$(ssh -p "${login_node_port}" "${user}@${login_node}" "sbatch ~/start_jupyter.sh ${remote_port}")
echo "job_output: ${job_output}"

# Extract job ID
job_id=$(echo "${job_output}" | awk '{print $4}')

# Initialize a counter for the waiting time in seconds
wait_time=0

# Loop until the job starts
while true; do
    job_state=$(ssh -p "${login_node_port}" "${user}@${login_node}" "squeue --job ${job_id} --noheader --format=%t")
    if [[ "$job_state" == "R" ]]; then
        echo "Job ${job_id} is running. Waiting jupyter start up (30s)..."
        break
    else
        echo "Job ${job_id} is in state ${job_state}. Waiting for $((wait_time/60)) minutes and $((wait_time%60)) seconds..."
        sleep 10 # Check every 10 seconds
        # Increase the wait_time by the sleep duration
        wait_time=$((wait_time + 10))
    fi
done

# Get the hostname of the node running the Jupyter Notebook
job_info=$(ssh -p "${login_node_port}" "${user}@${login_node}" "scontrol show job ${job_id}")
echo "job_info: ${job_info}"
hostname=$(echo "${job_info}" | grep '^ *NodeList=' | cut -d'=' -f2)
echo "hostname: ${hostname}"

# Give time for jupyter start up
sleep 30

# Attempt to download the jupyter_port.txt file, with retries if necessary
for attempt in {1..5}; do
    scp -P "${login_node_port}" "${user}@${login_node}:~/jupyter_port.txt" "./remote_jupyter_port.txt" && break
    echo "Attempt $attempt to download remote_jupyter_port.txt failed, retrying..."
    sleep 5
done

# Check if the jupyter_port.txt was successfully downloaded
if [ ! -f ./remote_jupyter_port.txt ]; then
    echo "Failed to download remote_jupyter_port.txt after several attempts."
    exit 1
fi

echo "Remote Jupyter Notebook job ${job_id} has been started."
# Read the port from the file
remote_port=$(cat ./remote_jupyter_port.txt)



echo "Remote Jupyter Notebook is running on: ${hostname}:${remote_port}"

# Find an available local port for the SSH tunnel
echo "Searching for an available local port for the SSH tunnel..."
found_port=false
for port in {1718..1800}; do
  if ! lsof -i:$port && ! netstat -tuln | grep ":$port " >/dev/null; then
    local_port=$port
    echo "Found available local port for SSH tunnel: $local_port"
    found_port=true
    break
  fi
done

if ! $found_port; then
    echo "No available local port found for SSH tunnel."
    exit 1
fi

# Setup the SSH tunnel using the retrieved remote port
# Now, use $local_port for setting up the SSH tunnel
echo "Setting up SSH tunnel to access Jupyter Notebook on ${hostname}:${local_port}"
ssh -N -f -L ${local_port}:${hostname}:${remote_port} "${user}@${login_node}" -p "${login_node_port}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
echo "Build command: \nssh -N -f -L ${local_port}:${hostname}:${remote_port} ${user}@${login_node} -p ${login_node_port} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "SSH tunnel setup complete. You can access Jupyter Notebook at http://127.0.0.1:${local_port}"

# Store the job ID and local port in files
echo "${job_id}" > ./jupyter_job_id.txt
echo "${local_port}" > ./local_jupyter_port.txt

# Wait for a stop command
echo "To stop the Jupyter Notebook session, press Enter."
read -s -n 1

# Cancel the Slurm job
ssh -p "${login_node_port}" "${user}@${login_node}" "scancel ${job_id}"
echo "Slurm job ${job_id} has been canceled. Waiting for tunnel closure"

# Kill the SSH tunnel
tunnel_pid=$(lsof -t -i:"${local_port}")
kill "${tunnel_pid}"
echo "SSH tunnel on port ${local_port} has been closed. Waiting for cleanup..."

# Clean up temporary files
rm ./jupyter_job_id.txt ./local_jupyter_port.txt ./remote_jupyter_port.txt
echo "Temporary files have been removed."

echo "Jupyter Notebook session has been successfully stopped and cleaned up."
