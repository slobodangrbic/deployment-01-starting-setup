#!/bin/bash

# Source the configuration from the .env file
if [[ -f .env ]]; then
    source .env
else
    echo "Error: The .env file is missing. Please create one with the required configuration."
    exit 1
fi

# Define an associative array of Docker image configurations
declare -A IMAGES=(
    ["node-example-1"]="Dockerfile"
    # Add more image configurations as needed
)

# Helper function to remove old dangling Docker images
remove_old_images() {
    echo "Checking for and removing old dangling Docker images..."
    # Use the docker image prune command to remove dangling images
    docker image prune -f
    echo "Old dangling Docker images removed."
}

# Helper function to check if there are changes in the Git repository
git_has_changes() {
    local changes
    # Fetch the latest changes from the remote repository
    git fetch origin main

    # Compare local changes with the remote tracking branch
    changes=$(git status -s -uno)
    [[ -n "$changes" ]]
}

# Helper function to perform Docker build, push, save, load, and run
perform_docker_operations() {
    local image_name="$1"
    local dockerfile="$2"

    # Build the Docker image
    docker build -t "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG" -f "$dockerfile" .

    # Display build information and ask for user confirmation
    echo "Docker image $image_name:$DOCKER_TAG built successfully."
    read -p "Do you want to push this image to the registry? (y/n): " push_confirm

    if [ "$push_confirm" == "y" ]; then
        # Tag the Docker image for the registry
        docker tag "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG" "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"

        # Push the Docker image to the registry
        echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USERNAME" --password-stdin "$DOCKER_REGISTRY"
        docker push "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"

        echo "Docker image $image_name:$DOCKER_TAG pushed to the registry."
    else
        echo "Docker image $image_name:$DOCKER_TAG was not pushed to the registry."
    fi

    # Save the Docker image to a tarball
    docker save -o "${image_name}_image.tar" "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"

    # Display save information and ask for user confirmation
    echo "Docker image $image_name:$DOCKER_TAG saved to ${image_name}_image.tar."
    read -p "Do you want to load this image locally? (y/n): " load_confirm

    if [ "$load_confirm" == "y" ]; then
        # Load the Docker image from the tarball
        docker load -i "${image_name}_image.tar"

        echo "Docker image $image_name:$DOCKER_TAG loaded locally."
    else
        echo "Docker image $image_name:$DOCKER_TAG was not loaded locally."
    fi

    # Display run information and ask for user confirmation
    read -p "Do you want to run a container with this image? (y/n): " run_confirm

    if [ "$run_confirm" == "y" ]; then
        # Run the Docker container
        docker run -d --name "${image_name}-container" $ADDITIONAL_DOCKER_RUN_OPTIONS "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"

        echo "Docker container ${image_name}-container running."
    else
        echo "Docker container ${image_name}-container was not started."
    fi

    # Display scp information and ask for user confirmation
    read -p "Do you want to copy this image to another machine using scp? (y/n): " scp_confirm
    echo # Move to a new line after user input

    if [ "$scp_confirm" == "y" ]; then
        # Use scp to copy the Docker image tarball to the remote machine
        scp "${image_name}_image.tar" "$SCP_REMOTE_USERNAME@$SCP_REMOTE_IP:$SCP_REMOTE_PATH"

        echo "Docker image $image_name:$DOCKER_TAG copied to $SCP_REMOTE_USERNAME@$SCP_REMOTE_IP:$SCP_REMOTE_PATH."
    else
        echo "Docker image $image_name:$DOCKER_TAG was not copied using scp."
    fi

    # Check for container health status
    read -p "Do you want to run a health check for this container? (y/n): " check_confirm

    if [ "$check_confirm" == "y" ]; then
        # Run the Docker container

        sleep 5

        docker inspect --format='{{json .State.Health}}' "${image_name}-container"

        sleep 30

        echo "Docker container status is healthy ${image_name}-container ."
    else
        echo "Docker container status is not healthy ${image_name}-container ."
    fi
}

# Navigate to the Git repository
cd $GIT_REPO_PATH || exit

# Check for changes in the Git repository
if git_has_changes; then
    echo "Changes detected in the Git repository. Proceeding with Docker operations..."

    # Iterate over each image configuration
    for image_name in "${!IMAGES[@]}"; do
        dockerfile="${IMAGES[$image_name]}"
        perform_docker_operations "$image_name" "$dockerfile"
    done

    # Remove old dangling Docker images
    remove_old_images

    echo "Docker operations completed successfully."
else
    echo "No changes detected in the Git repository. No Docker operations needed."
fi

# Prompt the user to confirm closing the window
read -p "Press Enter to close the window..."

# End of the script ...
