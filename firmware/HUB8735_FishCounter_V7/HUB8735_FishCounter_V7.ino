// HUB8735 Ultra / ideasHatch 4.0.15. Board upload requires user approval.
#include "WiFi.h"
#include "StreamIO.h"
#include "VideoStream.h"
#include "RTSP.h"
#include "NNObjectDetection.h"
#include "VideoStreamOverlay.h"
#include "FishConfig.h"
#include "FishModel.h"
#include "WifiCredentials.h"

#define CHANNEL 0
#define CHANNELNN 3

VideoSetting config(VIDEO_FHD, 30, VIDEO_H264, 0);
// Training/conversion must match this supported input configuration.
VideoSetting configNN(416, 416, 10, VIDEO_RGB, 0);
RTSP rtsp;
NNObjectDetection detector;
StreamIO videoStreamer(1, 1);
StreamIO nnStreamer(1, 1);
bool streamReady = false;
unsigned long lastReport = 0;

int pixelCoordinate(float value, int extent) {
    if (value < 0.0f) value = 0.0f;
    if (value > 1.0f) value = 1.0f;
    return (int)(value * (extent - 1));
}

void setup() {
    Serial.begin(115200);
    config.setBitrate(2 * 1024 * 1024);
    Camera.configVideoChannel(CHANNEL, config);
#if FISH_MODEL_READY
    Camera.configVideoChannel(CHANNELNN, configNN);
#endif
    Camera.videoInit();
    Camera.channelBegin(CHANNEL);

#if FISH_MODEL_READY
    // Requires a converted custom YOLOv7-tiny model, class 0 = fish.
    detector.configVideo(configNN);
    detector.configThreshold(MIN_CONFIDENCE_PERCENT / 100.0f, 0.3f);
    selectFishModel(detector);
    detector.begin();
    nnStreamer.registerInput(Camera.getStream(CHANNELNN));
    nnStreamer.setStackSize();
    nnStreamer.setTaskPriority();
    nnStreamer.registerOutput(detector);
    if (nnStreamer.begin() != 0) {
        Serial.println("ERROR: inference stream link failed");
        return;
    }
    Camera.channelBegin(CHANNELNN);
#endif
    OSD.configVideo(CHANNEL, config);
    OSD.begin();
    streamReady = true;
    // AI starts before networking, so an unavailable AP cannot prevent inference.
    // WiFi.begin itself may take time; inference runs in its separate stream task.
    unsigned long wifiStart = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < 30000UL) {
        WiFi.begin(ssid, pass);
        delay(500);
    }
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi unavailable: local AI/serial continues; restart with WiFi for RTSP.");
        return;
    }
    rtsp.configVideo(config);
    rtsp.begin();
    videoStreamer.registerInput(Camera.getStream(CHANNEL));
    videoStreamer.registerOutput(rtsp);
    if (videoStreamer.begin() != 0) {
        Serial.println("RTSP link failed: local AI/serial continues.");
        return;
    }
    Serial.print("RTSP: rtsp://");
    Serial.print(WiFi.localIP());
    Serial.print(":");
    Serial.println(rtsp.getPort());
}

// Emits NDJSON over debug USB serial. Dedicated ESP32 UART is not configured.
void reportResults(unsigned int count, const std::vector<ObjectDetectionResult>& results) {
    Serial.print("{\"schema\":1,\"uptime_ms\":");
    Serial.print(millis());
    Serial.print(",\"model_ready\":");
    Serial.print(FISH_MODEL_READY ? "true" : "false");
    Serial.print(",\"visible_count\":");
    if (FISH_MODEL_READY) Serial.print(count);
    else Serial.print("null");
    Serial.print(",\"above_expected_max\":");
    if (FISH_MODEL_READY) Serial.print(count > EXPECTED_MAX_FISH ? "true" : "false");
    else Serial.print("null");
    Serial.print(",\"boxes\":[");
    bool first = true;
    for (ObjectDetectionResult item : results) {
        if (item.type() != FISH_CLASS_ID || item.score() < MIN_CONFIDENCE_PERCENT) continue;
        if (item.xMax() <= item.xMin() || item.yMax() <= item.yMin()) continue;
        if (!first) Serial.print(",");
        first = false;
        Serial.print("{\"class\":\"fish\",\"confidence_percent\":");
        Serial.print(item.score());
        Serial.print(",\"xyxy_normalized\":[");
        Serial.print(item.xMin(), 4); Serial.print(",");
        Serial.print(item.yMin(), 4); Serial.print(",");
        Serial.print(item.xMax(), 4); Serial.print(",");
        Serial.print(item.yMax(), 4); Serial.print("]}");
    }
    Serial.println("]}");
}

void loop() {
    if (!streamReady) { delay(1000); return; }
    std::vector<ObjectDetectionResult> results;
#if FISH_MODEL_READY
    results = detector.getResult();
#endif
    unsigned int visibleCount = 0;
    OSD.createBitmap(CHANNEL);
    for (ObjectDetectionResult item : results) {
        if (item.type() != FISH_CLASS_ID || item.score() < MIN_CONFIDENCE_PERCENT) continue;
        if (item.xMax() <= item.xMin() || item.yMax() <= item.yMin()) continue;
        ++visibleCount;
        int x1 = pixelCoordinate(item.xMin(), config.width());
        int y1 = pixelCoordinate(item.yMin(), config.height());
        int x2 = pixelCoordinate(item.xMax(), config.width());
        int y2 = pixelCoordinate(item.yMax(), config.height());
        OSD.drawRect(CHANNEL, x1, y1, x2, y2, 3, OSD_COLOR_WHITE);
        char label[24];
        snprintf(label, sizeof(label), "fish %d%%", item.score());
        int labelY = y1 - OSD.getTextHeight(CHANNEL);
        if (labelY < 0) labelY = 0;
        OSD.drawText(CHANNEL, x1, labelY, label, OSD_COLOR_CYAN);
    }
    char status[64];
    if (FISH_MODEL_READY) {
        snprintf(status, sizeof(status), "Visible fish: %u%s", visibleCount,
                 visibleCount > EXPECTED_MAX_FISH ? " CHECK COUNT" : "");
    } else {
        snprintf(status, sizeof(status), "Fish model not ready | Count: N/A");
    }
    OSD.drawText(CHANNEL, 20, 20, status, OSD_COLOR_CYAN);
    OSD.update(CHANNEL);
    unsigned long now = millis();
    if (now - lastReport >= REPORT_INTERVAL_MS) {
        lastReport = now;
        reportResults(visibleCount, results);
    }
    delay(100);
}
