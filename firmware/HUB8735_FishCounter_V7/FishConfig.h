#pragma once

// Enable only after a compatible, one-class fish model has been installed.
#ifndef FISH_MODEL_READY
#define FISH_MODEL_READY 0
#endif

const int FISH_CLASS_ID = 0;
const int MIN_CONFIDENCE_PERCENT = 30;
const unsigned int EXPECTED_MAX_FISH = 5;
const unsigned long REPORT_INTERVAL_MS = 1000;

// Set by stage_firmware.py after placing the model and selection in .ino.
#define FISH_MODEL_STAGED 0
