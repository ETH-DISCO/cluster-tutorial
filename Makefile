.ONESHELL:
SHELL = /bin/bash
CONDA_DEACTIVATE = source $$(conda info --base)/etc/profile.d/conda.sh ; conda deactivate
CONDA_ACTIVATE_BASE = source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate base
CONDA_ACTIVATE_CON = source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate con

.PHONY: conda-get-yaml # generate an environment yaml file
conda-get-yaml:
	conda config --env --set subdir osx-64
	# conda config --env --set subdir osx-arm64
	conda config --set auto_activate_base false
	conda info

	$(CONDA_ACTIVATE_BASE)
	conda create --yes --name con python=3.11

	$(CONDA_ACTIVATE_CON)
	pip install --upgrade pip setuptools wheel

	# install packages
	# ...

	# export
	rm -f conda-environment.yml
	conda env export --name con > conda-environment.yml

	# remove
	# $(CONDA_DEACTIVATE)
	# conda remove --yes --name con --all

.PHONY: conda-install-env # install conda environment from yaml file
conda-install-env:
	$(CONDA_ACTIVATE_BASE)
	conda env create --file conda-environment.yml
	@echo -e "\033[0;32mcreated new conda environment. 'conda activate con' / 'conda deactivate'\033[0m"

.PHONY: conda-clean # remove conda environment
conda-clean:
	conda remove --yes --name con --all
	conda env list
	$(CONDA_DEACTIVATE)

.PHONY: help # generate help message
help:
	@grep '^.PHONY: .* #' Makefile | sed 's/\.PHONY: \(.*\) # \(.*\)/\1	\2/' | expand -t20
