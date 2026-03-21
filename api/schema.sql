-- ============================================================
-- HAU Monsters DB Schema
-- Database: haumonstersDB
-- ============================================================

CREATE DATABASE IF NOT EXISTS haumonstersDB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE haumonstersDB;

-- ------------------------------------------------------------
-- Table: monsterstbl  (PRIMARY focus for this exam)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monsterstbl (
    monster_id          INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    monster_name        VARCHAR(100)     NOT NULL,
    monster_type        VARCHAR(100)     NOT NULL,
    spawn_latitude      DECIMAL(10,7)    NOT NULL,
    spawn_longitude     DECIMAL(10,7)    NOT NULL,
    spawn_radius_meters DECIMAL(10,2)    NOT NULL DEFAULT 100.00,
    picture_url         VARCHAR(500)     NULL,
    PRIMARY KEY (monster_id),
    INDEX idx_spawn_lat_lng (spawn_latitude, spawn_longitude)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Table: playerstbl
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS playerstbl (
    player_id   INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    player_name VARCHAR(100)     NOT NULL,
    email       VARCHAR(150)     NULL,
    created_at  DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Table: locationstbl
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS locationstbl (
    location_id   INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    location_name VARCHAR(150)     NOT NULL,
    latitude      DECIMAL(10,7)    NOT NULL,
    longitude     DECIMAL(10,7)    NOT NULL,
    PRIMARY KEY (location_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Table: monster_catchestbl
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS monster_catchestbl (
    catch_id    INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id   INT(10) UNSIGNED NOT NULL,
    monster_id  INT(10) UNSIGNED NOT NULL,
    caught_at   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    latitude    DECIMAL(10,7)    NULL,
    longitude   DECIMAL(10,7)    NULL,
    PRIMARY KEY (catch_id),
    FOREIGN KEY (player_id)  REFERENCES playerstbl(player_id)  ON DELETE CASCADE,
    FOREIGN KEY (monster_id) REFERENCES monsterstbl(monster_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
