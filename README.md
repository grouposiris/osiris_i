# OSIRIS I: A Low-Power 32-bit RISC Core Processor

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![UPRJ_CI](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml) [![Caravel Build](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml)

## Introduction

This is a design of a 5-stage pipeline 32-bit RISC core with 16 general-purpose registers (x0-x15), where x0 is a dedicated ZERO register.
The program counter PC is a special-purpose 32-bit register. That can address at most 2³² instructions. All instructions are 32-bit. There are six instruction formats: R-type, I-type, S-type, B-Type, J-type, and U-type.

Refer to [README](docs/source/index.md) for this project documentation.

# 
