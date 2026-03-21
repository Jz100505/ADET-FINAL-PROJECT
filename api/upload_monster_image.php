<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
error_reporting(E_ALL);
ini_set('display_errors', 0);

$response = [
    "success" => false,
    "message" => "Unknown error"
];

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception("Invalid request method");
    }

    if (!isset($_FILES['image'])) {
        throw new Exception("No image uploaded");
    }

    if ($_FILES['image']['error'] !== UPLOAD_ERR_OK) {
        throw new Exception("Upload error code: " . $_FILES['image']['error']);
    }

    $uploadDir = __DIR__ . '/uploads/';

    if (!is_dir($uploadDir)) {
        if (!mkdir($uploadDir, 0777, true)) {
            throw new Exception("Failed to create upload directory");
        }
    }

    $tmpName      = $_FILES['image']['tmp_name'];
    $originalName = basename($_FILES['image']['name']);
    $extension    = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));

    $allowed = ['jpg', 'jpeg', 'png', 'webp'];
    if (!in_array($extension, $allowed)) {
        throw new Exception("Invalid file type");
    }

    $newFileName = uniqid("monster_", true) . "." . $extension;
    $destination = $uploadDir . $newFileName;

    if (!move_uploaded_file($tmpName, $destination)) {
        throw new Exception("Failed to move uploaded file");
    }

    // THE IP INDICATED VARIES — make sure you have an "uploads" folder
    // on your webserver if you plan to host it on your own.
    $imageUrl = "http://3.0.90.110/uploads/" . $newFileName;

    $response = [
        "success"   => true,
        "image_url" => $imageUrl
    ];
} catch (Exception $e) {
    $response = [
        "success" => false,
        "message" => $e->getMessage()
    ];
}

echo json_encode($response);
?>
