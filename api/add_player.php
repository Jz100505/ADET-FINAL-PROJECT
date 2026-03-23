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

$player_name = trim($data['player_name'] ?? '');
$username    = trim($data['username']    ?? '');
$password    = trim($data['password']    ?? '');

if ($player_name === '' || $username === '' || $password === '') {
    echo json_encode([
        "success" => false,
        "message" => "Missing required fields"
    ]);
    exit;
}

try {
    // Check if username already exists
    $checkSql  = "SELECT COUNT(*) FROM playerstbl WHERE username = :username";
    $checkStmt = $conn->prepare($checkSql);
    $checkStmt->bindParam(':username', $username);
    $checkStmt->execute();

    if ((int)$checkStmt->fetchColumn() > 0) {
        echo json_encode([
            "success" => false,
            "message" => "Username already taken"
        ]);
        exit;
    }

    // Hash password before storing
    $hashedPassword = password_hash($password, PASSWORD_BCRYPT);

    $sql = "INSERT INTO playerstbl (player_name, username, password)
            VALUES (:player_name, :username, :password)";

    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':player_name', $player_name);
    $stmt->bindParam(':username',    $username);
    $stmt->bindParam(':password',    $hashedPassword);
    $stmt->execute();

    echo json_encode([
        "success"   => true,
        "message"   => "Player registered successfully",
        "player_id" => $conn->lastInsertId()
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
