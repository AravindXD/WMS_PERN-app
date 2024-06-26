BEGIN
-- Sequences
CREATE SEQUENCE city_id_seq START 1;
CREATE SEQUENCE warehouse_id_seq START 1;
CREATE SEQUENCE rack_type_id_seq START 1;
CREATE SEQUENCE rack_id_seq START 1;
CREATE SEQUENCE tile_id_seq START 1;
CREATE SEQUENCE supplier_id_seq START 1;
CREATE SEQUENCE crate_id_seq START 1;
CREATE SEQUENCE customer_id_seq START 1;
CREATE SEQUENCE admin_id_seq START 1;

-- Tables with constraints
CREATE TABLE City (
    city_id INT PRIMARY KEY DEFAULT nextval('city_id_seq'),
    city_name VARCHAR(255) NOT NULL
);

CREATE TABLE Warehouse (
    warehouse_id INT PRIMARY KEY DEFAULT nextval('warehouse_id_seq'),
    city_id INT REFERENCES City(city_id),
    warehouse_name VARCHAR(255) NOT NULL,
    CONSTRAINT fk_warehouse_city FOREIGN KEY (city_id) REFERENCES City(city_id) ON DELETE CASCADE
);

CREATE TABLE RackType (
    rack_type_id INT PRIMARY KEY DEFAULT nextval('rack_type_id_seq'),
    rack_type_name VARCHAR(255) NOT NULL
);

CREATE TABLE Rack (
    rack_id INT PRIMARY KEY DEFAULT nextval('rack_id_seq'),
    warehouse_id INT REFERENCES Warehouse(warehouse_id),
    rack_type_id INT REFERENCES RackType(rack_type_id),
    rack_number INT NOT NULL,
    CONSTRAINT fk_rack_warehouse FOREIGN KEY (warehouse_id) REFERENCES Warehouse(warehouse_id) ON DELETE CASCADE,
    CONSTRAINT fk_rack_rack_type FOREIGN KEY (rack_type_id) REFERENCES RackType(rack_type_id) ON DELETE CASCADE
);

CREATE TABLE Tile (
    tile_id INT PRIMARY KEY DEFAULT nextval('tile_id_seq'),
    rack_id INT REFERENCES Rack(rack_id),
    row_number INT NOT NULL,
    column_number INT NOT NULL,
    dynamic_surface_area DECIMAL,
    allowed_height DECIMAL,
    aruco_id VARCHAR(255) UNIQUE,
    x_coordinate DECIMAL,
    y_coordinate DECIMAL,
    z_coordinate DECIMAL,
    CONSTRAINT fk_tile_rack FOREIGN KEY (rack_id) REFERENCES Rack(rack_id) ON DELETE CASCADE
);


CREATE TABLE Supplier (
    supplier_id INT PRIMARY KEY DEFAULT nextval('supplier_id_seq'),
    supplier_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(255) NOT NULL
);

CREATE TABLE Crate (
    crate_id INT PRIMARY KEY DEFAULT nextval('crate_id_seq'),
    serial_no VARCHAR(255) NOT NULL,
    nfc_id VARCHAR(255) NOT NULL,
    supplier_id INT REFERENCES Supplier(supplier_id),
    check_in_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expected_departure TIMESTAMP DEFAULT CURRENT_TIMESTAMP + INTERVAL '3 days',
    weight DECIMAL,
    length DECIMAL,
    breadth DECIMAL,
    height DECIMAL,
    crate_type VARCHAR(255),
    CONSTRAINT fk_crate_supplier FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id) ON DELETE CASCADE
);

CREATE TABLE Customer (
    customer_id INT PRIMARY KEY DEFAULT nextval('customer_id_seq'),
    customer_name VARCHAR(255) NOT NULL
);

CREATE TABLE Admin (
    admin_id INT PRIMARY KEY DEFAULT nextval('admin_id_seq'),
    admin_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(255) NOT NULL
);

-- Relationships
CREATE TABLE Supplies (
    supplier_id INT REFERENCES Supplier(supplier_id),
    crate_id INT REFERENCES Crate(crate_id),
    price DECIMAL,
    quantity INT,
    city_id INT REFERENCES City(city_id),
    PRIMARY KEY (supplier_id, crate_id, city_id),
    CONSTRAINT fk_supplies_supplier FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id) ON DELETE CASCADE,
    CONSTRAINT fk_supplies_crate FOREIGN KEY (crate_id) REFERENCES Crate(crate_id) ON DELETE CASCADE,
    CONSTRAINT fk_supplies_city FOREIGN KEY (city_id) REFERENCES City(city_id) ON DELETE CASCADE
);

CREATE TABLE Orders (
    crate_id INT REFERENCES Crate(crate_id),
    customer_id INT REFERENCES Customer(customer_id),
    price DECIMAL,
    quantity INT,
    city_id INT REFERENCES City(city_id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (crate_id, customer_id, city_id),
    CONSTRAINT fk_orders_crate FOREIGN KEY (crate_id) REFERENCES Crate(crate_id) ON DELETE CASCADE,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_orders_city FOREIGN KEY (city_id) REFERENCES City(city_id) ON DELETE CASCADE
);

CREATE TABLE Access (
    admin_id INT REFERENCES Admin(admin_id),
    warehouse_id INT REFERENCES Warehouse(warehouse_id),
    PRIMARY KEY (admin_id, warehouse_id),
    CONSTRAINT fk_access_admin FOREIGN KEY (admin_id) REFERENCES Admin(admin_id) ON DELETE CASCADE,
    CONSTRAINT fk_access_warehouse FOREIGN KEY (warehouse_id) REFERENCES Warehouse(warehouse_id) ON DELETE CASCADE
);

CREATE TABLE PlacedIn (
    crate_id INT REFERENCES Crate(crate_id),
    rack_id INT REFERENCES Rack(rack_id),
    tile_id INT REFERENCES Tile(tile_id),
    PRIMARY KEY (crate_id, rack_id, tile_id),
    CONSTRAINT fk_placedin_crate FOREIGN KEY (crate_id) REFERENCES Crate(crate_id) ON DELETE CASCADE,
    CONSTRAINT fk_placedin_rack FOREIGN KEY (rack_id) REFERENCES Rack(rack_id) ON DELETE CASCADE,
    CONSTRAINT fk_placedin_tile FOREIGN KEY (tile_id) REFERENCES Tile(tile_id) ON DELETE CASCADE
);

CREATE TABLE CustomerAccess (
    customer_id INT REFERENCES Customer(customer_id),
    crate_id INT REFERENCES Crate(crate_id),
    PRIMARY KEY (customer_id, crate_id),
    CONSTRAINT fk_customeraccess_customer FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_customeraccess_crate FOREIGN KEY (crate_id) REFERENCES Crate(crate_id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX idx_supplier_id ON Supplies(supplier_id);
CREATE INDEX idx_crate_id ON Supplies(crate_id);
CREATE INDEX idx_city_id ON Supplies(city_id);
CREATE INDEX idx_crate_id_orders ON Orders(crate_id);
CREATE INDEX idx_customer_id_orders ON Orders(customer_id);
CREATE INDEX idx_city_id_orders ON Orders(city_id);
CREATE INDEX idx_admin_id_access ON Access(admin_id);
CREATE INDEX idx_warehouse_id_access ON Access(warehouse_id);
CREATE INDEX idx_crate_id_placedin ON PlacedIn(crate_id);
CREATE INDEX idx_rack_id_placedin ON PlacedIn(rack_id);
CREATE INDEX idx_tile_id_placedin ON PlacedIn(tile_id);
CREATE INDEX idx_customer_id_customeraccess ON CustomerAccess(customer_id);
CREATE INDEX idx_crate_id_customeraccess ON CustomerAccess(crate_id);

END
/