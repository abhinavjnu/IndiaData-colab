# Colab Setup (GitHub code + Drive data)

This project is configured for a Colab-first workflow so heavy R jobs use Colab RAM/CPU instead of local RAM.

## 1) Open the notebook

- Open `PLFS/colab testing.ipynb` in Colab.
- In Colab: `Runtime` -> `Change runtime type` -> pick High-RAM (if available).

## 2) Run cells in order

The notebook automates:

- Installing R/system dependencies
- Mounting Google Drive
- Cloning the GitHub repo to `/content/IndiaData`
- Creating Drive-backed data/output directories
- Writing `config.yaml` for Colab paths
- Installing R packages via `R/00_setup.R`
- Running `PLFS/automated_plfs_analysis.R` with log capture

## 3) Data location

Put large PLFS files in Drive, not in git:

- `/content/drive/MyDrive/IndiaDataData/raw`

Outputs and logs are saved to:

- `/content/drive/MyDrive/IndiaDataData/outputs`
- `/content/drive/MyDrive/IndiaDataData/logs`

## 4) Security

- Do not commit `config.yaml`.
- Put API key only in runtime-generated `config.yaml`.
