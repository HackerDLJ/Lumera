# Lumera

**Real-world, smartphone-assisted anemia screening research platform.**

Lumera is designed around a simple principle: a screening tool should be easy to understand, scientifically measurable, and honest about uncertainty.

## Core workflow

```text
Phone camera
   ↓
Image quality gate
   ↓
Reference-card colour calibration
   ↓
Conjunctiva region detection
   ↓
Trained ML inference
   ↓
Hb estimate + uncertainty
   ↓
Safety / referral logic
   ↓
Field screening record
```

## Repository status

This repository starts with the production architecture and research pipeline. Clinical performance numbers are not hard-coded or fabricated. A model is considered deployable only after training and evaluation on appropriately paired image + laboratory haemoglobin data.

## Clinical scope

Lumera is a screening support system, not a diagnostic device. Concerning or uncertain results should be confirmed with standard haemoglobin testing and clinical assessment.
