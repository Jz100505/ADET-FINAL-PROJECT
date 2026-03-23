<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once "hauconnect.php";

try {
    $sql = "SELECT
                player_id,
                player_name,
                username,
                created_at
            FROM playerstbl
            ORDER BY player_id DESC";

    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $players = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "success" => true,
        "data"    => $players
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch players",
        "error"   => $e->getMessage()
    ]);
}
?>
