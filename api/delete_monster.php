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

$data       = json_decode(file_get_contents("php://input"), true);
$monster_id = $data['monster_id'] ?? null;

if (!$monster_id) {
    echo json_encode([
        "success" => false,
        "message" => "monster_id is required"
    ]);
    exit;
}

try {
    $sql  = "DELETE FROM monsterstbl WHERE monster_id = :monster_id";
    $stmt = $conn->prepare($sql);
    $stmt->execute([
        ':monster_id' => $monster_id
    ]);

    echo json_encode([
        "success" => true,
        "message" => "Monster deleted successfully"
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}
?>
