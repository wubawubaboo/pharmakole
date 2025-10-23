<?php
class UsersModel{
private $pdo; public function __construct($pdo){$this->pdo = $pdo;}

public function createUser($u){
    $stmt = $this->pdo->prepare('INSERT INTO users (username, password_hash, role, full_name, created_at) VALUES (:u,:p,:r,:n,NOW())');
    $stmt->execute([':u'=>$u['username'],':p'=>password_hash($u['password'], PASSWORD_DEFAULT),':r'=>$u['role'],':n'=>$u['full_name']]);
    return $this->pdo->lastInsertId();
}

public function authenticate($username, $password){
    $stmt = $this->pdo->prepare('SELECT * FROM users WHERE username = :u');
    $stmt->execute([':u'=>$username]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if($row && password_verify($password, $row['password_hash'])){
        unset($row['password_hash']); return $row;
    }
    return false;
}

// --- NEW: List all users ---
public function listUsers(){
    $stmt = $this->pdo->prepare('SELECT id, username, role, full_name, created_at FROM users ORDER BY full_name');
    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

// --- NEW: Update a user ---
public function updateUser($id, $data){
    if (!empty($data['password'])) {
        $sql = "UPDATE users SET username = :u, role = :r, full_name = :n, password_hash = :p WHERE id = :id";
        $params = [
            ':u' => $data['username'],
            ':r' => $data['role'],
            ':n' => $data['full_name'],
            ':p' => password_hash($data['password'], PASSWORD_DEFAULT),
            ':id' => $id
        ];
    } else {
        $sql = "UPDATE users SET username = :u, role = :r, full_name = :n WHERE id = :id";
         $params = [
            ':u' => $data['username'],
            ':r' => $data['role'],
            ':n' => $data['full_name'],
            ':id' => $id
        ];
    }
    $stmt = $this->pdo->prepare($sql);
    $stmt->execute($params);
    return $stmt->rowCount();
}

// --- NEW: Delete a user ---
public function deleteUser($id){
    $stmt = $this->pdo->prepare('DELETE FROM users WHERE id = :id');
    $stmt->execute([':id' => $id]);
    return $stmt->rowCount();
}

}