<?php
$host = "localhost";
$dbname = "haumonstersDB";       // DATABASE VARIES
$username = "dbmanager";          // USER VARIES
$password = "6adetp@ssw0rd2022!"; // PASSWORD VARIES

try {
    $conn = new PDO(
        "mysql:host=$host;dbname=$dbname;charset=utf8mb4",
        $username,
        $password
    );
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo json_encode([
        "success" => false,
        "message" => "Database connection failed",
        "error" => $e->getMessage()
    ]);
    exit;
}
?>
