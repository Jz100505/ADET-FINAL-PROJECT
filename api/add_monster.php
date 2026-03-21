<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require_once "hauconnect.php";

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        "success" => false,
        "message" => "Only POST method is allowed"
    ]);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);

$monster_name        = trim($data['monster_name'] ?? '');
$monster_type        = trim($data['monster_type'] ?? '');
$spawn_latitude      = $data['spawn_latitude'] ?? null;
$spawn_longitude     = $data['spawn_longitude'] ?? null;
$spawn_radius_meters = $data['spawn_radius_meters'] ?? null;
$picture_url         = trim($data['picture_url'] ?? '');

if (
    $monster_name === '' ||
    $monster_type === '' ||
    $spawn_latitude === null ||
    $spawn_longitude === null ||
    $spawn_radius_meters === null
) {
    echo json_encode([
        "success" => false,
        "message" => "Missing required fields"
    ]);
    exit;
}

try {
    $sql = "INSERT INTO monsterstbl (
                monster_name,
                monster_type,
                spawn_latitude,
                spawn_longitude,
                spawn_radius_meters,
                picture_url
            ) VALUES (
                :monster_name,
                :monster_type,
                :spawn_latitude,
                :spawn_longitude,
                :spawn_radius_meters,
                :picture_url
            )";

    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':monster_name',        $monster_name);
    $stmt->bindParam(':monster_type',        $monster_type);
    $stmt->bindParam(':spawn_latitude',      $spawn_latitude);
    $stmt->bindParam(':spawn_longitude',     $spawn_longitude);
    $stmt->bindParam(':spawn_radius_meters', $spawn_radius_meters);
    $stmt->bindParam(':picture_url',         $picture_url);
    $stmt->execute();

    echo json_encode([
        "success" => true,
        "message" => "Monster added successfully"
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
