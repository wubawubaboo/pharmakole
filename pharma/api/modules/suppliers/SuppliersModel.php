<?php
class SuppliersModel {
    private $pdo;
    public function __construct($pdo) { $this->pdo = $pdo; }

    public function createSupplier($data) {
        $sql = "INSERT INTO suppliers (name, contact_person, phone, email, address, created_at) VALUES (:name, :contact, :phone, :email, :address, NOW())";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([
            ':name' => $data['name'],
            ':contact' => $data['contact_person'] ?? null,
            ':phone' => $data['phone'] ?? null,
            ':email' => $data['email'] ?? null,
            ':address' => $data['address'] ?? null
        ]);
        return $this->pdo->lastInsertId();
    }

    public function listSuppliers($query = '') {
        if (!empty($query)) {
            $stmt = $this->pdo->prepare('SELECT * FROM suppliers WHERE name LIKE :q OR contact_person LIKE :q ORDER BY name');
            $stmt->execute([':q' => '%' . $query . '%']);
        } else {
            $stmt = $this->pdo->prepare('SELECT * FROM suppliers ORDER BY name');
            $stmt->execute();
        }
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function updateSupplier($id, $data) {
        $sql = "UPDATE suppliers SET 
                    name = :name, 
                    contact_person = :contact, 
                    phone = :phone, 
                    email = :email, 
                    address = :address
                WHERE id = :id";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':name' => $data['name'],
            ':contact' => $data['contact_person'] ?? null,
            ':phone' => $data['phone'] ?? null,
            ':email' => $data['email'] ?? null,
            ':address' => $data['address'] ?? null
        ]);
        return $stmt->rowCount();
    }

    public function deleteSupplier($id) {
        $stmt = $this->pdo->prepare('DELETE FROM suppliers WHERE id = :id');
        $stmt->execute([':id' => $id]);
        return $stmt->rowCount();
    }
}
?>