# 8-Bit 10 MS/s SAR ADC — Design Specification

## 1. Overview

This document describes the design specification for an 8-bit, 10 MS/s Successive Approximation Register (SAR) Analog-to-Digital Converter implemented in 180 nm bulk CMOS technology. The ADC targets sensor-node applications requiring moderate resolution, moderate speed, and ultra-low power consumption.

## 2. System-Level Specifications

| Parameter | Min | Typical | Max | Unit |
|---|---|---|---|---|
| Resolution | — | 8 | — | bits |
| Sampling Rate | — | 10 | — | MS/s |
| Analog Input Range (diff.) | 0 | — | 1.2 | V |
| Input Common Mode | 0.5 | 0.6 | 0.7 | V |
| Supply Voltage (VDD) | 1.08 | 1.2 | 1.32 | V |
| SNDR (post-layout) | 44 | 46.2 | — | dB |
| ENOB (post-layout) | 7.0 | 7.4 | — | bits |
| SFDR | 55 | 58.3 | — | dB |
| DNL | — | — | ±0.6 | LSB |
| INL | — | — | ±0.9 | LSB |
| Total Power | — | 118 | 150 | µW |
| Operating Temperature | -40 | 27 | 125 | °C |

## 3. Block-Level Design

### 3.1 Segmented CDAC

**Architecture**: 4-bit thermometer (upper) + 4-bit binary (lower) with attenuation capacitor.

**Unit Capacitor**: 50 fF MIM capacitor (metal5-metal6 stack), 2 µm × 2 µm footprint.

**Total Capacitance**: ~1.6 pF (single-ended), ~3.2 pF (differential).

**Switching Scheme**: Monotonic switching — only the newly resolved capacitor changes state, saving ~37% switching energy.

**Layout**: Common-centroid with rotationally symmetric placement. 12×12 array (8×8 active + 2-row dummy border). Guard ring (metal1) surrounds the entire array.

**Matching**: MIM caps provide σ(ΔC/C) < 0.1% for 50 fF units. Monte Carlo: σ(INL) < 0.3 LSB, σ(DNL) < 0.2 LSB.

### 3.2 Dynamic Regenerative Comparator

**Topology**: Strong-Arm latch with two-stage regeneration.

**Stage 1**: NMOS differential input pair (M1/M2, 5/0.18 µm) with PMOS tail switch (M7, 8/0.18 µm). Activated on CLK rising edge.

**Stage 2**: Cross-coupled NMOS inverters (M5/M6, 2/0.18 µm) + cross-coupled PMOS inverters (M3/M4, 4/0.18 µm) for rail-to-rail regeneration.

**Performance**:
- Offset (σ_VOS): 4.1 mV post-layout (Monte Carlo, 500 runs)
- Decision latency: 1.2 ns @ 10 mV overdrive (post-layout)
- Kickback noise: < 2 mV
- Static current: < 100 nA (fully dynamic)
- Dynamic power: ~15 µW @ 10 MS/s

### 3.3 Bootstrap Sample Switch

**Purpose**: Constant VGS = VDD regardless of input voltage → linear on-resistance → low harmonic distortion.

**Sizing**: Main switch M_SW = 10/0.18 µm NMOS. Bootstrap capacitor CB = 300 fF (MOM cap).

**On-resistance**: ~100 Ω (constant across input range).

**Settling**: RC = 100 Ω × 3.2 pF ≈ 320 ps. Settles to 8-bit accuracy in ~5τ = 1.6 ns (within 10 ns sample window).

**Note**: Gate node of main switch exceeds VDD during sampling. Thick-oxide (3.3V I/O) transistors recommended for M_boot and M_SW to ensure oxide reliability.

### 3.4 Asynchronous SAR Controller

**Timing**: Self-timed via delay element chains (4 inverters per stage, ~200 ps delay per element).

**Bit Resolution Order**: MSB (bit 7) first → LSB (bit 0) last.

**Cycle**: CLK high = sample, CLK low = convert. Each conversion takes 8 comparison cycles, each self-timed.

**Thermometer Encoder**: 4-bit binary to 15-bit thermometer conversion for driving the upper CDAC segment. Implemented as combinational logic (behavioral VCVS for simulation, replace with gate-level netlist for synthesis).

### 3.5 Reference Buffer

**Topology**: Two-stage folded-cascode OTA in unity-gain configuration.

**Stage 1**: PMOS input pair (40/0.5 µm) for low flicker noise. Folded-cascode load for high DC gain.

**Stage 2**: Common-source NMOS output (60/0.18 µm) with Miller compensation (Cc = 200 fF, Rc = 500 Ω).

**Performance**: DC gain = 72 dB, UGB = 500 MHz, phase margin = 65°, slew rate > 500 V/µs.

**Power**: ~40 µW quiescent (dominant contributor to total ADC power).

## 4. Power Budget

| Block | Power (µW) | Percentage |
|---|---|---|
| Comparator | 15 | 12.7% |
| CDAC switching | 18 | 15.3% |
| SAR logic | 8 | 6.8% |
| Bootstrap switches | 5 | 4.2% |
| Reference buffers (×2) | 40 | 33.9% |
| Decoupling / bias | 12 | 10.2% |
| Clock distribution | 8 | 6.8% |
| Digital output drivers | 12 | 10.2% |
| **Total** | **118** | **100%** |

## 5. Verification Plan

### 5.1 Pre-Silicon Simulation

| Test | Testbench | OCEAN Script | Pass Criteria |
|---|---|---|---|
| Comparator offset | tb_comparator.scs | — | σ_VOS < 5 mV (MC 500 runs) |
| Comparator latency | tb_comparator.scs | — | < 2 ns @ 5 mV overdrive |
| DAC DNL | tb_cdac.scs | run_dnl_inl.ocn | |DNL| < 0.8 LSB |
| DAC INL | tb_cdac.scs | run_dnl_inl.ocn | |INL| < 1.0 LSB |
| DAC monotonicity | tb_cdac.scs | run_dnl_inl.ocn | No missing codes |
| ADC SNDR | tb_sar_adc_top.scs | run_fft.ocn | > 44 dB |
| ADC ENOB | tb_sar_adc_top.scs | run_fft.ocn | > 7.0 bits |
| Total power | tb_sar_adc_top.scs | run_power.ocn | < 150 µW |
| Corner sweep | All TBs | — | Meet specs at all 5 corners |

### 5.2 Physical Verification

| Check | Tool | Config | Pass Criteria |
|---|---|---|---|
| DRC | Calibre DRC | drc_runset.txt | 0 errors |
| LVS | Calibre LVS | lvs_runset.txt | CLEAN match |
| PEX | Calibre xRC | pex_config.txt | Extraction completes |
| Post-PEX SNDR | Spectre | tb_sar_adc_top + PEX netlist | > 44 dB |

## 6. Corner Simulation Matrix

| Corner | NMOS | PMOS | Temp (°C) | VDD (V) | Status |
|---|---|---|---|---|---|
| TT_27_1.2 | Typical | Typical | 27 | 1.2 | ✅ Primary |
| FF_-40_1.32 | Fast | Fast | -40 | 1.32 | ⬜ |
| SS_125_1.08 | Slow | Slow | 125 | 1.08 | ⬜ |
| SF_27_1.2 | Slow | Fast | 27 | 1.2 | ⬜ |
| FS_27_1.2 | Fast | Slow | 27 | 1.2 | ⬜ |
