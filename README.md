# RTL to Gate-Level Digital VLSI Project

This repository presents a digital averaging design developed as part of a Digital VLSI Design course.

The project focuses on integrating and verifying an **average computation module** built from previously developed submodules, and validating its correctness through simulation.

## Project Overview
The averaging functionality is implemented by connecting three main components:
- `SUM` module – accumulates input data
- `DIV` module – performs division (provided as-is, without modification)
- `average` module – top-level module responsible for control and integration

The primary task was to correctly connect these components and ensure proper data flow and control signaling.

## Included Files
Only the relevant files for demonstrating functionality and verification are included:

- `average.v` – top-level averaging module  
- `average_tb.v` – testbench for the average module  
- `sum.v` – summation module  
- `sum_tb.v` – testbench for the sum module  
- Interface file (`IF`) – used to observe waveform behavior and signal interactions  
- Output files – simulation outputs showing correct results for both `SUM` and `average` modules  
- `div.v` – divider module (provided, unchanged)

## Verification
- Functional correctness was verified using directed testbenches.
- Waveform analysis confirms correct control signaling and data propagation.
- Output files demonstrate that the produced results match the expected values.

## Notes
Not all project files were uploaded intentionally.  
Only the essential RTL, testbenches, interfaces, and verification outputs required to demonstrate correct design integration and functionality are included.

