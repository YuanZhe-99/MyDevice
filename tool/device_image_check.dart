// Shared rules for bundled device thumbnails (`assets/device_images/*.png`).
//
// The rules live in `lib/shared/utils/device_image_processing.dart` so the
// in-app image editor uses the same definition; this file re-exports them for
// `tool/validate_json.dart`, `tool/prepare_device_image.dart` and the tests.

export 'package:my_device/shared/utils/device_image_processing.dart'
    show
        checkDeviceImage,
        deviceImageAlphaThreshold,
        deviceImageSafeFraction,
        deviceImageSize;
