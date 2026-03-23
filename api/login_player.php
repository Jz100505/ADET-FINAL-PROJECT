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

$username = trim($data['username'] ?? '');
$password = trim($data['password'] ?? '');

if ($username === '' || $password === '') {
    echo json_encode([
        "success" => false,
        "message" => "Username and password are required"
    ]);
    exit;
}

try {
    $sql  = "SELECT player_id, player_name, username, password
             FROM playerstbl
             WHERE username = :username
             LIMIT 1";

    $stmt = $conn->prepare($sql);
    $stmt->bindParam(':username', $username);
    $stmt->execute();

    $player = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$player) {
        echo json_encode([
            "success" => false,
            "message" => "Invalid username or password"
        ]);
        exit;
    }

    if (!password_verify($password, $player['password'])) {
        echo json_encode([
            "success" => false,
            "message" => "Invalid username or password"
        ]);
        exit;
    }

    echo json_encode([
        "success" => true,
        "message" => "Login successful",
        "data"    => [
            "player_id"   => $player['player_id'],
            "player_name" => $player['player_name'],
            "username"    => $player['username']
        ]
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
