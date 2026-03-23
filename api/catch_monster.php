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

$player_id = $data['player_id'] ?? null;
$monster_id = $data['monster_id'] ?? null;
$latitude = $data['latitude'] ?? null;
$longitude = $data['longitude'] ?? null;

if ($monster_id === null || $latitude === null || $longitude === null) {
    echo json_encode([
        "success" => false,
        "message" => "Missing required fields"
    ]);
    exit;
}

try {
    // Check monster exists
    $checkStmt = $conn->prepare(
        "SELECT monster_id FROM monsterstbl WHERE monster_id = :monster_id"
    );
    $checkStmt->execute([':monster_id' => $monster_id]);
    if (!$checkStmt->fetch()) {
        echo json_encode([
            "success" => false,
            "message" => "Monster not found"
        ]);
        exit;
    }

    // Try to record the catch if a valid player_id was supplied.
    // This is best-effort — if the player doesn't exist in the DB yet
    // (e.g. demo mode), we skip the catch log and still delete the monster.
    if ($player_id !== null) {
        $playerCheck = $conn->prepare(
            "SELECT player_id FROM playerstbl WHERE player_id = :player_id"
        );
        $playerCheck->execute([':player_id' => $player_id]);

        if ($playerCheck->fetch()) {
            // Player exists — create a location entry and log the catch
            $locName = "Catch Location (" .
                round((float) $latitude, 4) . ", " .
                round((float) $longitude, 4) . ")";

            $locStmt = $conn->prepare(
                "INSERT INTO locationstbl (location_name) VALUES (:location_name)"
            );
            $locStmt->bindParam(':location_name', $locName);
            $locStmt->execute();
            $location_id = $conn->lastInsertId();

            $catchSql = "INSERT INTO monster_catchestbl
                            (player_id, monster_id, location_id, latitude, longitude)
                         VALUES
                            (:player_id, :monster_id, :location_id, :latitude, :longitude)";

            $catchStmt = $conn->prepare($catchSql);
            $catchStmt->bindParam(':player_id', $player_id, PDO::PARAM_INT);
            $catchStmt->bindParam(':monster_id', $monster_id, PDO::PARAM_INT);
            $catchStmt->bindParam(':location_id', $location_id, PDO::PARAM_INT);
            $catchStmt->bindParam(':latitude', $latitude);
            $catchStmt->bindParam(':longitude', $longitude);
            $catchStmt->execute();
        }
        // If player not found, silently skip the catch log
    }

    // Fetch current monster name
    $nameStmt = $conn->prepare(
        "SELECT monster_name FROM monsterstbl WHERE monster_id = :monster_id"
    );
    $nameStmt->execute([':monster_id' => $monster_id]);
    $row = $nameStmt->fetch(PDO::FETCH_ASSOC);
    $currentName = $row ? $row['monster_name'] : 'Monster';

    // Guard: already captured
    if (str_ends_with($currentName, '(Captured)')) {
        echo json_encode([
            "success" => false,
            "message" => "This monster has already been captured"
        ]);
        exit;
    }

    // Mark as captured: rename + zero out spawn radius
    $newName = $currentName . " (Captured)";
    $updStmt = $conn->prepare(
        "UPDATE monsterstbl
         SET monster_name        = :new_name,
             spawn_radius_meters = 0
         WHERE monster_id = :monster_id"
    );
    $updStmt->execute([
        ':new_name' => $newName,
        ':monster_id' => $monster_id,
    ]);

    echo json_encode([
        "success" => true,
        "message" => "Monster captured successfully",
        "monster_id" => (int) $monster_id,
        "monster_name" => $newName,
    ]);

} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>