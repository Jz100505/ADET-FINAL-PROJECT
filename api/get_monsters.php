<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once "hauconnect.php";

try {
    $sql = "SELECT
                monster_id,
                monster_name,
                monster_type,
                spawn_latitude,
                spawn_longitude,
                spawn_radius_meters,
                picture_url
            FROM monsterstbl
            ORDER BY monster_id DESC";

    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $monsters = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "success" => true,
        "data"    => $monsters
    ]);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Failed to fetch monsters",
        "error"   => $e->getMessage()
    ]);
}
?>
