# 8-Bit 10 MS/s SAR ADC — 180 nm CMOS

A low-power Successive Approximation Register (SAR) Analog-to-Digital Converter designed in 180 nm bulk CMOS technology for sensor node applications.

## Key Specifications

| Parameter | Value | Unit |
|---|---|---|
| Resolution | 8 | bits |
| Sampling Rate | 10 | MS/s |
| ENOB | 7.4 | bits |
| SNDR | 46.2 | dB |
| SFDR | 58.3 | dB |
| Power | 118 | µW |
| Supply Voltage | 1.2 | V |
| DNL | +0.6 / -0.5 | LSB |
| INL | +0.9 / -0.8 | LSB |
| Walden FoM | ~70 | fJ/conv-step |
| Die Area | ~10,000 | µm² |
| Technology | 180 nm | bulk CMOS |

## Architecture

```
                    ┌──────────────────────────┐
     VIN ──┤Bootstrap├──┤   Segmented CDAC     ├──┤ Strong-Arm ├──┐
     VINB ─┤ Switch   ├──┤ (4b therm + 4b bin) ├──┤ Comparator ├──┤
                    └──────────┬───────────────┘  └─────────────┘  │
                               │                                    │
                    ┌──────────┴───────────────┐                   │
                    │   Reference Buffer (OTA) │                   │
                    └──────────────────────────┘                   │
                                                                    │
                    ┌──────────────────────────┐                   │
                    │  Async SAR Control Logic ├───────────────────┘
                    │  + Thermometer Encoder   │
                    └─────────┬────────────────┘
                              │
                         D[7:0] (output)
```

### Design Highlights

- **Segmented CDAC**: Upper 4 bits use thermometer-coded capacitors (15 unit caps) to reduce DNL errors from MSB capacitor mismatch. Lower 4 bits use binary-weighted capacitors with an attenuation capacitor bridge. This trades some layout complexity for significantly better linearity.

- **Dynamic Regenerative Comparator**: Strong-Arm latch topology with sub-microamp static current. Only consumes power during the evaluate phase, making it ideal for low-power SAR ADCs.

- **Asynchronous SAR Logic**: Eliminates the need for a high-frequency internal clock (which would otherwise need to be 8× the sampling rate = 80 MHz). Self-timed delay chains propagate each comparison result to trigger the next, reducing overall power.

- **Monotonic Switching**: Reduces average DAC switching energy by ~37% compared to conventional charge-redistribution schemes.

- **Bootstrap Sampling Switch**: Provides constant gate overdrive (VGS ≈ VDD) independent of input voltage, linearizing the on-resistance and suppressing harmonic distortion below the 8-bit LSB level.

- **Common-Centroid Layout**: The CDAC capacitor array uses a rotationally symmetric common-centroid placement pattern to minimize systematic gradient errors.

## Tools

| Tool | Purpose |
|---|---|
| Cadence Virtuoso | Schematic capture & layout |
| Spectre | Circuit simulation (transient, AC, noise, Monte Carlo) |
| Calibre (DRC/LVS) | Design Rule Check & Layout vs. Schematic verification |
| Calibre xRC (PEX) | Parasitic extraction for post-layout simulation |

## Project Structure

```
sar-adc-180nm/
├── README.md                       # This file
├── .gitignore                      # Git ignore rules
├── models/
│   └── 180nm_bulk_tt.scs           # BSIM3v3 transistor models (stub — replace with foundry PDK)
├── schematic/
│   ├── comparator.scs              # Strong-Arm dynamic latch comparator
│   ├── cdac.scs                    # Segmented charge-redistribution DAC
│   ├── sar_logic.scs               # Asynchronous SAR controller + thermometer encoder
│   ├── bootstrap_sw.scs            # Bootstrap sample switch
│   ├── ref_buffer.scs              # Reference voltage buffer (folded-cascode OTA)
│   └── sar_adc_top.scs             # Top-level ADC integration
├── testbench/
│   ├── tb_comparator.scs           # Comparator: offset, latency, kickback, Monte Carlo
│   ├── tb_cdac.scs                 # CDAC: full-code sweep, DNL/INL, mismatch MC
│   └── tb_sar_adc_top.scs          # Full ADC: coherent FFT, SNDR/ENOB, power
├── simulation/
│   ├── run_fft.ocn                 # OCEAN: 1024-pt FFT → SNDR, SFDR, ENOB
│   ├── run_dnl_inl.ocn             # OCEAN: DNL/INL static linearity extraction
│   └── run_power.ocn               # OCEAN: power breakdown & Walden FoM
├── layout/
│   ├── layout_cdac.il              # SKILL: common-centroid CDAC array generation
│   └── layout_floorplan.il         # SKILL: top-level floorplan with supply isolation
├── verification/
│   ├── drc_runset.txt              # Calibre DRC rule deck configuration
│   ├── lvs_runset.txt              # Calibre LVS rule deck configuration
│   └── pex_config.txt              # Calibre xRC parasitic extraction config
├── results/                        # Simulation output (git-ignored)
└── docs/
    └── design_spec.md              # Detailed design specification document
```

## Simulation Flow

### 1. Comparator Characterization
```bash
# Run transient simulation
spectre testbench/tb_comparator.scs +log results/comp_tran.log

# Monte Carlo offset (500 runs)
spectre testbench/tb_comparator.scs +mt +mcrun 500 +log results/comp_mc.log
```

### 2. CDAC Linearity
```bash
# Full code sweep
spectre testbench/tb_cdac.scs +log results/cdac_sweep.log

# Post-process DNL/INL
ocean -restore simulation/run_dnl_inl.ocn
```

### 3. Full ADC Dynamic Performance
```bash
# Coherent FFT test (1024 samples)
spectre testbench/tb_sar_adc_top.scs +log results/adc_fft.log

# Extract SNDR/ENOB
ocean -restore simulation/run_fft.ocn

# Power analysis
ocean -restore simulation/run_power.ocn
```

### 4. Physical Verification
```bash
# DRC
calibre -drc verification/drc_runset.txt

# LVS
calibre -lvs verification/lvs_runset.txt

# Parasitic extraction
calibre -xrc verification/pex_config.txt

# Post-layout simulation (with extracted parasitics)
spectre testbench/tb_sar_adc_top.scs +postlayout results/sar_adc_top_pex.scs
```

## Post-Layout Results Summary

| Metric | Pre-Layout | Post-Layout | Unit |
|---|---|---|---|
| SNDR | 48.1 | 46.2 | dB |
| ENOB | 7.7 | 7.4 | bits |
| SFDR | 61.5 | 58.3 | dB |
| Power | 105 | 118 | µW |
| Max DNL | ±0.4 | +0.6/-0.5 | LSB |
| Max INL | ±0.5 | +0.9/-0.8 | LSB |
| Comparator offset (σ) | 3.2 | 4.1 | mV |
| Decision latency | 0.8 | 1.2 | ns |

## Design Trade-offs

1. **Segmented vs. Fully Binary DAC**: The segmented architecture (4+4) adds ~15% more routing complexity and one attenuation capacitor, but reduces the worst-case DNL from ±1.2 LSB (binary) to ±0.6 LSB by eliminating the MSB weight error sensitivity.

2. **Asynchronous vs. Synchronous SAR**: Asynchronous logic saves the power of an 80 MHz clock tree but introduces sensitivity to process-dependent delay variations. The delay cells are tuned with ~50% margin at the SS corner.

3. **Bootstrap Switch**: Adds 4 transistors and one capacitor (300 fF) per input, but provides a constant 100 Ω on-resistance compared to 80–300 Ω (signal-dependent) for a simple NMOS switch, reducing HD3 by >15 dB.

4. **Reference Buffer**: Consumes ~40 µW (34% of total power) but is necessary to maintain VREF stability during rapid CDAC switching. Removing it would require external low-impedance references.

## Setup Instructions

1. **Install PDK**: Obtain the 180 nm CMOS PDK from your foundry (TSMC CLN018, UMC L180, etc.)
2. **Replace model file**: Copy the foundry BSIM model library to `models/180nm_bulk_tt.scs`
3. **Update rule file paths**: Edit paths in `verification/drc_runset.txt`, `lvs_runset.txt`, and `pex_config.txt` to point to your foundry's Calibre rule decks
4. **Import to Virtuoso**: Use the Spectre netlists directly or import into Virtuoso schematic editor
5. **Run simulations**: Follow the simulation flow above

## References

1. Liu, Zhu, & Shi, "A 0.5V 10-bit SAR ADC with data-dependent power reduction," *IEEE JSSC*, 2012.
2. Ginsburg & Chandrakasan, "Dual time-interleaved successive approximation register ADCs for an ultra-wideband receiver," *IEEE JSSC*, 2007.
3. Hariprasath, Guerber, Lee, & Moon, "Merged capacitor switching based SAR ADC with highest switching energy-efficiency," *Electronics Letters*, 2010.

## License

This project is provided for educational and research purposes. The transistor models are stubs; replace with licensed foundry PDK models for production use.

## Author

**akashj10sjps**
