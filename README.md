# Beyond the tensor: white matter biomarkers for neurodegeneration
This repository supports the publication:
Landin-Romero, Hazelton, Mito, & Calamente (Under review), *Imaging Neuroscience*

Searches were run programmatically through the Europe PMC Articles RESTful API (https://www.ebi.ac.uk/europepmc/webservices/rest/search) in R (httr and jsonlite packages), using the same query syntax as the Europe PMC website. Record counts were retrieved for each search overall, by publication type and by publication year. Searches were completed on 12/11/2026.

[Diffusion_search_europePMC.R][def1] is the script used to pull data counts from Europe PMC based on the following search terms per search area:

| **Area** | **Search terms** |
|------|--------------|
|Diffusion Tensor Imaging |  (BODY:"diffusion tensor imaging" OR TITLE:"diffusion tensor imaging" OR ABSTRACT:"diffusion tensor imaging") *AND* ("diffusion-weighted imaging" OR "diffusion weighted imaging" OR "diffusion MRI" OR "DTI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter")'|
| Fractional anisotropy |   (BODY:"fractional anisotropy" OR TITLE:"fractional anisotropy" OR ABSTRACT:"fractional anisotropy") *AND* ("diffusion tensor imaging" OR "diffusion-weighted imaging" OR "diffusion weighted imaging" OR "diffusion MRI" OR "DTI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter") |
| Constrained spherical deconvolution |  (BODY:"constrained spherical deconvolution" OR TITLE:"constrained spherical deconvolution" OR ABSTRACT:"constrained spherical deconvolution") *AND* ("diffusion-weighted imaging" OR "diffusion weighted imaging" OR "diffusion MRI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter")'|
| Fixel - based analysis | '(BODY:"fixel based analysis" OR BODY:"fixel-based analysis" OR TITLE:"fixel based analysis" OR TITLE:"fixel-based analysis" OR ABSTRACT:"fixel based analysis" OR ABSTRACT:"fixel-based analysis") AND ("diffusion-weighted imaging" OR "diffusion weighted imaging" OR "diffusion MRI" OR "MRI" OR "magnetic resonance imaging" OR "tractography" OR "white matter") |

[Figure_1_C_D_code.py][def2] produces the following figure used in Figure 1 of the manuscript, based on total count per year:


![Figure 1 C and D input][def3]


[def1]: Diffusion_search_europePMC.R
[def2]: Figure_1_C_D_code.py
[def3]: europepmc_counts/Figure_1_C_D.png