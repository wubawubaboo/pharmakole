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


}