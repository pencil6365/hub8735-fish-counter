#pragma once
#include "FishConfig.h"
#include "NNObjectDetection.h"
#if FISH_MODEL_READY && !FISH_MODEL_STAGED
#error "Use 02_PlaceConvertedModel.cmd to stage the .nb and the .ino model selection."
#endif

// The BSP scans .ino text before C++ preprocessing. Keep this inactive
// custom-model selection here so streaming-only builds need no .nb file.
inline void selectFishModel(NNObjectDetection& detector) {
#if FISH_MODEL_READY
    detector.modelSelect(OBJECT_DETECTION, CUSTOMIZED_YOLOV7TINY, NA_MODEL, NA_MODEL);
#endif
}
