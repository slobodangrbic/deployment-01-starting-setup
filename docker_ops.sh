#!/bin/bash

# Configuration
GIT_REPO_PATH="D:\docker-complete-udemy-course\deployment-01-starting-setup"
DOCKER_REGISTRY="slobodang"
DOCKER_TAG="latest"
REGISTRY_USERNAME="slobodang"
REGISTRY_PASSWORD="Tehnique051"
ADDITIONAL_DOCKER_RUN_OPTIONS="-p 80:80 --rm"
GIT_REMOTE="origin"
GIT_BRANCH="main"

# Define an associative array of Docker image configurations
declare -A IMAGES=(
    ["node-example-1"]="Dockerfile"
    # Add more image configurations as needed
)

# Helper function to check if there are changes in the Git repository
git_has_changes() {
    local changes
    changes=$(git status -s)
    [[ -n "$changes" ]]
}

# Helper function to perform Docker build, push, save, load, and run
perform_docker_operations() {
    local image_name="$1"
    local dockerfile="$2"

    # Build the Docker image
    docker build -t "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG" -f "$dockerfile" .

    # Tag the Docker image for the registry
    docker tag "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG" "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"

    # Push the Docker image to the registry
    echo "$REGISTRY_PASSWORD" | docker login -u "$REGISTRY_USERNAME" --password-stdin "$DOCKER_REGISTRY"
    docker push "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"

    # Save the Docker image to a tarball
    docker save -o "${image_name}_image.tar" "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"

    # Load the Docker image from the tarball
    docker load -i "${image_name}_image.tar"

    # Run the Docker container
    docker run -d --name "${image_name}-container" $ADDITIONAL_DOCKER_RUN_OPTIONS "$DOCKER_REGISTRY/$image_name:$DOCKER_TAG"
}

# Navigate to the Git repository
cd "$GIT_REPO_PATH" || exit

# Check for changes in the Git repository
if git_has_changes; then
    echo "Changes detected in the Git repository. Proceeding with Docker operations..."

    # Iterate over each image configuration
    for image_name in "${!IMAGES[@]}"; do
        dockerfile="${IMAGES[$image_name]}"
        perform_docker_operations "$image_name" "$dockerfile"
    done

    echo "Docker operations completed successfully."
else
    echo "No changes detected in the Git repository. No Docker operations needed."
fi
