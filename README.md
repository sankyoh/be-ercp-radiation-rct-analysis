[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20592014.svg)](https://doi.org/10.5281/zenodo.20592013)

# be-ercp-radiation-rct-analysis

This repository contains selected Stata do-files produced as part of statistical analysis support for a multicenter prospective randomized trial evaluating radiation dose reduction during balloon endoscopy-assisted ERCP.

## Study

Japanese title:

**バルーン内視鏡下ERCPにおける照射方法の工夫による被ばく量軽減の検討 多施設共同前向きランダム化比較検討試験**

## Files

### `simulation_nis.do`

This Stata do-file performs a simulation-based sample size assessment for a non-inferiority comparison.

The simulation used prior data on insertion time and supported a target sample size of 100 participants. Considering possible dropouts and other losses, the planned sample size was set at 110 participants.

### `analysis.do`

This Stata do-file performs the main non-inferiority analysis for the primary endpoint, **insertion time**.

The analysis compares Group A with Group B using a Welch-type approach. The non-inferiority margin was set at 5 minutes.

## Notes

- Patient-level data are not included.
- This repository contains Stata do-files from statistical analysis support conducted by Toshiharu Mitsuhashi for the study.
- The do-files are provided for documentation and reproducibility of the statistical support process.
