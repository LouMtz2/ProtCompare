# ProtCompare

**ProtCompare** is a Shiny app designed to compare a query protein sequence to a list of target sequences using local alignment based on the BLOSUM62 substitution matrix.

##  📊 Features

* Computes sequence identity (%)
* Calculates coverage (%) of the query
* Determines combined scores (Identity × Coverage)
* Provides alignment scores
* Estimates empirical p-values from random sequence alignments

 ## 📁 Example Data

An example `.xlsx` file containing **Helicobacter pylori** protein sequences from **UniProt** is provided. These sequences are part of the **Helicobacter pylori** proteome (UP000000429) and can be used to demonstrate the input format expected by the app:

- [example_data.xlsx](example_data.xlsx)  
  (Proteins obtained from UniProt: [Helicobacter pylori Proteome](https://www.uniprot.org/proteomes/UP000000429))


## 🛠️ Requirements

This app requires:

- **R** version ≥ 4.0 (developed and tested on 4.4.0)

### 📦 R packages

The following packages are required (tested versions shown):

| Package     | Version  |
|-------------|----------|
| shiny       | 1.10.0   |
| readxl      | 1.4.5    |
| DT          | 0.33     |
| Biostrings  | 2.72.1   |
| pwalign     | 1.0.0    |
| bslib       | 0.9.0    |

## 💻 Installation & Usage

```R
install.packages(c("shiny", "readxl", "DT", "BiocManager", "bslib"))
BiocManager::install(c("Biostrings", "pwalign"))

library(shiny)
runApp("app.R")
```

## 📖 Citation

If you use **ProtCompare** in your research or project, please cite it as follows:

####  - Plain Text
Lourdes Martínez Martínez (2025). *ProtCompare (Version 1.0)* [Shiny App]. GitHub: https://github.com/LouMtz2/ProtCompare. MIT License.

####  - APA
Martínez Martínez, L. (2025). ProtCompare (Version 1.0) [Shiny app]. Retrieved from https://github.com/LouMtz2/ProtCompare

👉 You can also find a machine-readable citation in [`CITATION.cff`](./CITATION.cff) 

## 📄 License

ProtCompare is licensed under the MIT License with Citation Requirement. See the [LICENSE](LICENSE) file for details.

## 📧 Contact

* **Developer:** Lourdes Martínez Martínez
* **Email:** [loumtezmtez@gmail.com](mailto:loumtezmtez@gmail.com)


