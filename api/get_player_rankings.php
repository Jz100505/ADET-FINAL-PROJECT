<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once "hauconnect.php";

try {
    $sql = "SELECT
                p.player_id,
                p.player_name,
                COUNT(c.catch_id) AS catch_count
            FROM playerstbl p
            LEFT JOIN monster_catchestbl c ON p.player_id = c.player_id
            GROUP BY p.player_id, p.player_name
            ORDER BY catch_count DESC
            LIMIT 10";

    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $rankings = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Cast catch_count to int for clean JSON output
    foreach ($rankings as &$row) {
        $row['catch_count'] = (int)$row['catch_count'];
        $row['player_id']   = (int)$row['player_id'];
    }

    echo json_encode([
        "success" => true,
        "data"    => $rankings
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch rankings",
        "error"   => $e->getMessage()
    ]);
}
?>
