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

$player_id   = $data['player_id']   ?? null;
$player_name = trim($data['player_name'] ?? '');
$username    = trim($data['username']    ?? '');
$new_password = trim($data['new_password'] ?? '');

if ($player_id === null || $player_name === '' || $username === '') {
    echo json_encode([
        "success" => false,
        "message" => "Missing required fields"
    ]);
    exit;
}

try {
    // Check username uniqueness (excluding current player)
    $checkSql  = "SELECT COUNT(*) FROM playerstbl
                  WHERE username = :username AND player_id != :player_id";
    $checkStmt = $conn->prepare($checkSql);
    $checkStmt->bindParam(':username',  $username);
    $checkStmt->bindParam(':player_id', $player_id, PDO::PARAM_INT);
    $checkStmt->execute();

    if ((int)$checkStmt->fetchColumn() > 0) {
        echo json_encode([
            "success" => false,
            "message" => "Username already taken by another player"
        ]);
        exit;
    }

    // Build query — only update password if provided
    if ($new_password !== '') {
        $hashedPassword = password_hash($new_password, PASSWORD_BCRYPT);
        $sql = "UPDATE playerstbl
                SET player_name = :player_name,
                    username    = :username,
                    password    = :password
                WHERE player_id = :player_id";

        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':player_name', $player_name);
        $stmt->bindParam(':username',    $username);
        $stmt->bindParam(':password',    $hashedPassword);
        $stmt->bindParam(':player_id',   $player_id, PDO::PARAM_INT);
    } else {
        $sql = "UPDATE playerstbl
                SET player_name = :player_name,
                    username    = :username
                WHERE player_id = :player_id";

        $stmt = $conn->prepare($sql);
        $stmt->bindParam(':player_name', $player_name);
        $stmt->bindParam(':username',    $username);
        $stmt->bindParam(':player_id',   $player_id, PDO::PARAM_INT);
    }

    $stmt->execute();

    echo json_encode([
        "success" => true,
        "message" => "Player updated successfully"
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
