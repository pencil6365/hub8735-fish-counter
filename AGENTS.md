# Project handoff

- Read `給下一個ChatGPT的提示詞.txt`, `完整操作與故障排查手冊.md`, `專案現況.json`, and the portable package's `portable/VALIDATION.txt` first. The dated status is a handoff snapshot; inspect actual files and current results before proceeding.
- Respond in beginner-friendly Traditional Chinese. Read/prepare/edit new project copies/compile within scope. Obtain explicit current user approval before flashing the physical board. Never infer upload-to-board approval from general computer access or “continue.”
- Preserve original data and credentials. Never commit Wi-Fi passwords, tokens, account verification data or unredacted private conversion notices. GitHub credentials headers use placeholders; configure only local copies.
- Hardware: HUB-8735_ultra / RTL8735B / JXF37. BSP ideasHatch 4.0.15-Release. Model: custom YOLOv7-tiny, class 0 fish, RGB 416x416, UINT8 requested, confidence .30, NMS IoU .30.
- Official fish NB was pending on 2026-10-28. No fish-NB full compile, flash or on-board acceptance was completed. Streaming full compile and both C++ API syntax modes passed. Do not equate those with AI firmware validation.
- The BSP scans `.ino` text. Model installation must stage `yolov7_tiny.nb`, both READY/STAGED flags, and the literal customized modelSelect in `.ino`. Do not flip READY alone or rename PT to NB.
- Run the portable menu from a short ASCII path such as C:\Fish. Do not modify Windows security/locale globally. Preserve the scoped C locale workaround and hash checks before flashing.
- The portable sketch starts AI before networking; no-WiFi and power-on behavior still require physical-board tests. WiFi.begin may block beyond the outer retry time. Do not promise a strict 30-second boot.
- Archive source projects and old training scripts may retain old absolute paths. Do not run training scripts blindly. Keep correlated frames in the same dataset split. Training-fit examples are not held-out evidence.
- Update handoff status with actual evidence, including compile logs, conversion settings and test conditions. Do not report actions performed without tool or user evidence.
