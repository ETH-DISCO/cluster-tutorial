# Apptainer examples
This repository contains examples of how to use Apptainer to deploy applications on the disco cluster (and other places).

## Using Apptainer
You need to have a working installation of Apptainer. You can find the installation instructions [here](https://apptainer.org/docs/user/main/quick_start.html#installation). 

You can find details in the documention [here](https://apptainer.org/docs/user/main/index.html). However, the examples in this repository should be enough to get you started.

You need sudo to build the container, but you can run the container without sudo. Build the container on your local machine, and then copy the container to the disco cluster using `scp output_image.sif USERNAME@tik42x.ethz.ch:/itet-stor/USERNAME/net_scratch/path/to/storage/output_image.sif`.

## Basic commands
- `apptainer build output_image.sif definition_file.def` - Build the container.
- `apptainer run output_image.sif` - Run the container using the commands in the definition file.
- `apptainer exec output_image.sif command` - Execute the container using the specified command.
- `apptainer shell output_image.sif` - Enter the container shell, so you can work interactively.

## Examples
- [PyTorch Simple](pytorch-simple/README.md)