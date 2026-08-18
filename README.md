[![DOI](https://img.shields.io/badge/DOI-10.5281%2Fzenodo.20592013-blue.svg)](https://doi.org/10.5281/zenodo.20592013)

# be-ercp-radiation-rct-analysis

This repository contains selected, de-identified Stata do-files for the following study:

**バルーン内視鏡下ERCPにおける照射方法の工夫による被ばく量軽減の検討 多施設共同前向きランダム化比較検討試験**

The repository documents the sample-size simulation and the statistical workflow used for the study. Patient-level data, direct identifiers, site-specific mappings, and analysis outputs are not included.

## Repository contents

- `simulation_nis.do`: sample-size simulation for the non-inferiority design.
- `000_config.do`: project path and directory settings.
- `do/010_import.do`: import of the private source dataset.
- `do/020_clean.do`: data cleaning and derivation of the analysis dataset.
- `do/030_define_vars.do`: definition of analysis variables, including de-identified site coding.
- `do/035_calc_wt.do`: propensity-score estimation, stabilized inverse-probability weights, and balance diagnostics.
- `do/200_Main_analysis.do`: primary-outcome analysis and its unweighted sensitivity analysis.
- `do/301_Secondary.do`: secondary-outcome analyses and unweighted sensitivity analyses.

The private source data and the original site mapping are not distributed. Therefore, the workflow is not executable as-is without authorized access to the study data and a locally restored site mapping.

## Statistical analysis

Because the final randomization configuration could have reduced balance in some of the intended allocation factors, the primary analyses used stabilized inverse-probability-of-treatment weighting (IPTW). The denominator propensity score was estimated by logistic regression using the intended allocation factors: study site, procedure type, and first or repeat procedure. The numerator was the marginal probability of the assigned treatment. Stabilized weights were used as probability weights with robust standard errors. Covariate balance was assessed using absolute standardized mean differences, and the propensity-score and weight distributions were examined. No weight trimming, truncation, or common-support exclusion was applied.

The primary outcome was insertion time among participants with successful insertion. The treatment effect was estimated using weighted linear regression with robust standard errors. Non-inferiority was concluded when the upper limit of the two-sided 95% confidence interval for the mean difference (low-frame-rate group minus conventional group) was below the prespecified 5-minute margin. An unweighted Welch two-sample analysis was performed as a sensitivity analysis.

Binary secondary outcomes were analyzed in all randomized participants using weighted modified Poisson regression with robust variance, reporting risk ratios. Continuous secondary outcomes were analyzed among participants with successful insertion using weighted linear regression with robust standard errors, reporting mean differences. Unweighted sensitivity analyses were also performed. Secondary analyses used two-sided tests without adjustment for multiple comparisons.

## Software and dependencies

The analyses were executed using StataNow 19.5. Some scripts include `version 18.0` statements to preserve language compatibility.

The workflow uses the following user-written Stata commands, which must be available in the local Stata installation:

- `fre`
- `swbin`
- `covbalx`
- `kishess`
- `loveplot`
- `csplot`

## Expected project structure

```text
project-root/
├── 000_config.do
├── simulation_nis.do
├── data_raw/       # private data; not distributed
├── data_clean/     # generated locally; not distributed
├── do/
│   ├── 010_import.do
│   ├── 020_clean.do
│   ├── 030_define_vars.do
│   ├── 035_calc_wt.do
│   ├── 200_Main_analysis.do
│   └── 301_Secondary.do
├── log/            # generated locally; not distributed
└── output/         # generated locally; not distributed
```

Before running the workflow, replace `Project_Root` in `000_config.do` with the local absolute project path and create the four working directories shown above. Then run the do-files in their numbered order. The de-identified site coding in `do/030_define_vars.do` must be adapted locally to the authorized study data.

## Data availability and privacy

No participant-level dataset is included in this repository. The public code has been reviewed to remove direct personal identifiers, individual names, original site names, and the private mapping between study sites and analysis codes. Logs and generated outputs are intentionally excluded because they can contain local paths, software-license information, or other non-code artifacts.

## Citation and license

Citation metadata are provided in `CITATION.cff`. Please cite the archived Zenodo version corresponding to the release used. The code is distributed under the MIT License; see `LICENSE`.
