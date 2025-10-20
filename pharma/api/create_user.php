<?php
require_once __DIR__ . '/modules/users/UsersModel.php';
$cfg = include __DIR__ . '/../config/config.php';
$dsn = "mysql:host={$cfg['db']['host']};dbname={$cfg['db']['dbname']};charset=utf8mb4";
$pdo = new PDO($dsn, $cfg['db']['user'], $cfg['db']['pass'], [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
]);
$model = new UsersModel($pdo);

$message = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    $role = $_POST['role'] ?? 'staff';
    $full_name = $_POST['full_name'] ?? $username;

    if ($username && $password && $role) {
        $user = [
            'username' => $username,
            'password' => $password,
            'role' => $role,
            'full_name' => $full_name
        ];
        $id = $model->createUser($user);
        if ($id) {
            $message = "<div style='color:green'>User created successfully! User ID: $id</div>";
        } else {
            $message = "<div style='color:red'>Failed to create user.</div>";
        }
    } else {
        $message = "<div style='color:red'>Please fill all fields.</div>";
    }
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Create User</title>
</head>
<body>
    <h2>Create New User</h2>
    <?php echo $message; ?>
    <form method="post">
        <label>Username: <input type="text" name="username" required></label><br>
        <label>Password: <input type="password" name="password" required></label><br>
        <label>Full Name: <input type="text" name="full_name"></label><br>
        <label>Role:
            <select name="role">
                <option value="staff">Staff</option>
                <option value="owner">Owner</option>
            </select>
        </label><br>
        <button type="submit">Create User</button>
    </form>
</body>
</html>