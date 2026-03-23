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

$data      = json_decode(file_get_contents("php://input"), true);
$player_id = $data['player_id'] ?? null;

if (!$player_id) {
    echo json_encode([
        "success" => false,
        "message" => "player_id is required"
    ]);
    exit;
}

try {
    $sql  = "DELETE FROM playerstbl WHERE player_id = :player_id";
    $stmt = $conn->prepare($sql);
    $stmt->execute([':player_id' => $player_id]);

    echo json_encode([
        "success" => true,
        "message" => "Player deleted successfully"
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}
?>
