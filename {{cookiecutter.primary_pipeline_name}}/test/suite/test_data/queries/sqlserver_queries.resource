*** Variables ***
${DROP_TABLE_EMPLOYEES}         DROP TABLE IF EXISTS employees

${DROP_TABLE_EMPLOYEES2}        DROP TABLE IF EXISTS employees2

${CREATE_TABLE_EMPLOYEES}
...                             CREATE TABLE employees (
...                             id INT IDENTITY(1,1) PRIMARY KEY,
...                             name NVARCHAR(100) NOT NULL,
...                             role NVARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2)
...                             )

${CREATE_TABLE_EMPLOYEES2}
...                             CREATE TABLE employees2 (
...                             id INT IDENTITY(1,1) PRIMARY KEY,
...                             name NVARCHAR(100) NOT NULL,
...                             role NVARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2)
...                             )

# ==================== SIT Pipeline Tables ====================

# --- tblRequest ---

${TBLREQUEST_DEFINITION}
...                             (Id INT IDENTITY(1,1) PRIMARY KEY,
...                             RequestType NVARCHAR(10) NOT NULL,
...                             Status INT NOT NULL DEFAULT 0,
...                             StatusMessage NVARCHAR(255),
...                             Requestor NVARCHAR(100),
...                             RequestorDepartment NVARCHAR(100),
...                             RequestedOn DATETIME,
...                             SubmittedOn DATETIME,
...                             ProcessedOn DATETIME,
...                             CBS_DCNumber NVARCHAR(50),
...                             CBS_FOCNumber NVARCHAR(50),
...                             CBS_GPNumber NVARCHAR(50),
...                             EBAS_GPId NVARCHAR(50),
...                             Remarks NVARCHAR(500))

${INSERT_TBLREQUEST_SAMPLE_DATA}
...                             INSERT INTO dbo.tblRequest (RequestType, Status, Requestor, RequestorDepartment, RequestedOn, CBS_DCNumber, CBS_FOCNumber, CBS_GPNumber, EBAS_GPId, Remarks)
...                             VALUES
...                             ('1', 0, 'John Smith', 'Engineering', GETDATE(), 'DC-1001', 'FOC-2001', 'GP-3001', 'EBAS-4001', 'DC Outbound Request Type 1'),
...                             ('2', 0, 'Jane Doe', 'Logistics', GETDATE(), 'DC-1002', 'FOC-2002', 'GP-3002', 'EBAS-4002', 'DC Outbound Request Type 2'),
...                             ('3', 0, 'Bob Wilson', 'Warehouse', GETDATE(), 'DC-1003', 'FOC-2003', 'GP-3003', 'EBAS-4003', 'FOC Request Type 3'),
...                             ('4', 0, 'Alice Brown', 'Procurement', GETDATE(), 'DC-1004', 'FOC-2004', 'GP-3004', 'EBAS-4004', 'FOC Request Type 4'),
...                             ('5', 0, 'Charlie Davis', 'Engineering', GETDATE(), 'DC-1005', 'FOC-2005', 'GP-3005', 'EBAS-4005', 'GP Request Type 5'),
...                             ('6', 0, 'Diana Lee', 'Logistics', GETDATE(), 'DC-1006', 'FOC-2006', 'GP-3006', 'EBAS-4006', 'GP Request Type 6'),
...                             ('1', 1, 'Eve Martin', 'Engineering', GETDATE(), 'DC-1007', 'FOC-2007', 'GP-3007', 'EBAS-4007', 'Already submitted - should be excluded'),
...                             ('3', 0, 'Frank White', 'Warehouse', GETDATE(), 'DC-1008', 'FOC-2008', 'GP-3008', 'EBAS-4008', 'Another FOC Request Type 3')

# --- tblHeader ---

${TBLHEADER_DEFINITION}
...                             (Id INT IDENTITY(1,1) PRIMARY KEY,
...                             RequestId INT NOT NULL,
...                             GPRequestType NVARCHAR(10),
...                             ExpectedDOR DATETIME,
...                             Plant NVARCHAR(50),
...                             Reason NVARCHAR(255),
...                             StorageLocation NVARCHAR(50),
...                             SendTo NVARCHAR(100),
...                             Orginator NVARCHAR(100),
...                             OrginatorDepartment NVARCHAR(100),
...                             Approver NVARCHAR(100),
...                             ApproverDepartment NVARCHAR(100),
...                             NoOfItems INT,
...                             DCTransactionType NVARCHAR(50),
...                             DCOutBoundType NVARCHAR(50),
...                             Vendor NVARCHAR(100),
...                             FOCProcess NVARCHAR(50),
...                             CostCenter NVARCHAR(50),
...                             VendorChallanNo NVARCHAR(50),
...                             NatureOfProcess NVARCHAR(50),
...                             Customer NVARCHAR(100),
...                             Remarks NVARCHAR(500))

${INSERT_TBLHEADER_SAMPLE_DATA}
...                             INSERT INTO dbo.tblHeader (RequestId, GPRequestType, ExpectedDOR, Plant, Reason, StorageLocation, SendTo, Orginator, OrginatorDepartment, Approver, ApproverDepartment, NoOfItems, DCTransactionType, DCOutBoundType, Vendor, FOCProcess, CostCenter, VendorChallanNo, NatureOfProcess, Customer, Remarks)
...                             VALUES
...                             (1, '1', GETDATE(), 'Plant-A', 'Stock Transfer', 'SL-100', 'Warehouse-1', 'John Smith', 'Engineering', 'Manager-1', 'Engineering', 3, 'Outbound', 'DC Transfer', 'Vendor-A', NULL, 'CC-1001', NULL, 'Transfer', 'Customer-A', 'Header for request 1'),
...                             (2, '2', GETDATE(), 'Plant-B', 'Return Goods', 'SL-200', 'Warehouse-2', 'Jane Doe', 'Logistics', 'Manager-2', 'Logistics', 2, 'Outbound', 'DC Return', 'Vendor-B', NULL, 'CC-1002', NULL, 'Return', 'Customer-B', 'Header for request 2'),
...                             (3, '3', GETDATE(), 'Plant-A', 'FOC Delivery', 'SL-100', 'Warehouse-1', 'Bob Wilson', 'Warehouse', 'Manager-1', 'Warehouse', 2, NULL, NULL, 'Vendor-C', 'FOC-Standard', 'CC-1003', 'VC-001', 'FOC', 'Customer-C', 'Header for request 3'),
...                             (4, '4', GETDATE(), 'Plant-C', 'FOC Return', 'SL-300', 'Warehouse-3', 'Alice Brown', 'Procurement', 'Manager-3', 'Procurement', 1, NULL, NULL, 'Vendor-D', 'FOC-Return', 'CC-1004', 'VC-002', 'FOC', 'Customer-D', 'Header for request 4'),
...                             (5, '5', GETDATE(), 'Plant-B', 'GP Issue', 'SL-200', 'Warehouse-2', 'Charlie Davis', 'Engineering', 'Manager-2', 'Engineering', 2, NULL, NULL, 'Vendor-E', NULL, 'CC-1005', NULL, 'GP', 'Customer-E', 'Header for request 5'),
...                             (6, '6', GETDATE(), 'Plant-A', 'GP Receipt', 'SL-100', 'Warehouse-1', 'Diana Lee', 'Logistics', 'Manager-1', 'Logistics', 1, NULL, NULL, 'Vendor-F', NULL, 'CC-1006', NULL, 'GP', 'Customer-F', 'Header for request 6'),
...                             (8, '3', GETDATE(), 'Plant-C', 'FOC Delivery', 'SL-300', 'Warehouse-3', 'Frank White', 'Warehouse', 'Manager-3', 'Warehouse', 2, NULL, NULL, 'Vendor-G', 'FOC-Standard', 'CC-1007', 'VC-003', 'FOC', 'Customer-G', 'Header for request 8')

# --- tblItems ---

${TBLITEMS_DEFINITION}
...                             (Id INT IDENTITY(1,1) PRIMARY KEY,
...                             RequestId INT NOT NULL,
...                             HeaderId INT,
...                             SerialNo INT,
...                             PartNumber NVARCHAR(50),
...                             PartDescription NVARCHAR(255),
...                             CategoryOfGoods NVARCHAR(100),
...                             UOM NVARCHAR(20),
...                             HSN NVARCHAR(20),
...                             Model NVARCHAR(50),
...                             ModelNo NVARCHAR(50),
...                             Quantity DECIMAL(10,2),
...                             Rate DECIMAL(10,2),
...                             FiscalYear NVARCHAR(10),
...                             EBAS_GPItemId NVARCHAR(50),
...                             VendorChallanNo NVARCHAR(50),
...                             CBS_GPNumber NVARCHAR(50))

${INSERT_TBLITEMS_SAMPLE_DATA}
...                             INSERT INTO dbo.tblItems (RequestId, HeaderId, SerialNo, PartNumber, PartDescription, CategoryOfGoods, UOM, HSN, Model, ModelNo, Quantity, Rate, FiscalYear, EBAS_GPItemId, VendorChallanNo, CBS_GPNumber)
...                             VALUES
...                             (1, 1, 1, 'PN-1001', 'Servo Motor 500W', 'Electrical', 'EA', '8501', 'SM-500', 'SM-500-A', 10, 2500.00, '2025-26', 'EGI-001', NULL, NULL),
...                             (1, 1, 2, 'PN-1002', 'Control Board v3', 'Electronics', 'EA', '8542', 'CB-V3', 'CB-V3-B', 5, 1200.00, '2025-26', 'EGI-002', NULL, NULL),
...                             (1, 1, 3, 'PN-1003', 'Power Cable 10m', 'Electrical', 'MTR', '8544', 'PC-10', 'PC-10-C', 20, 150.00, '2025-26', 'EGI-003', NULL, NULL),
...                             (2, 2, 1, 'PN-2001', 'Hydraulic Pump', 'Mechanical', 'EA', '8413', 'HP-200', 'HP-200-A', 2, 8500.00, '2025-26', 'EGI-004', NULL, NULL),
...                             (2, 2, 2, 'PN-2002', 'Pressure Gauge', 'Instruments', 'EA', '9026', 'PG-100', 'PG-100-B', 4, 350.00, '2025-26', 'EGI-005', NULL, NULL),
...                             (3, 3, 1, 'PN-3001', 'Bearing SKF 6205', 'Mechanical', 'EA', '8482', 'BRG-62', 'BRG-62-A', 50, 120.00, '2025-26', 'EGI-006', 'VC-001', NULL),
...                             (3, 3, 2, 'PN-3002', 'Lubricant 5L', 'Consumables', 'LTR', '2710', 'LUB-5L', 'LUB-5L-B', 10, 450.00, '2025-26', 'EGI-007', 'VC-001', NULL),
...                             (4, 4, 1, 'PN-4001', 'Safety Helmet', 'Safety', 'EA', '6506', 'SH-100', 'SH-100-A', 25, 85.00, '2025-26', 'EGI-008', 'VC-002', NULL),
...                             (5, 5, 1, 'PN-5001', 'Steel Rod 12mm', 'Raw Material', 'KG', '7214', 'SR-12', 'SR-12-A', 500, 45.00, '2025-26', 'EGI-009', NULL, NULL),
...                             (5, 5, 2, 'PN-5002', 'Welding Wire 1.2mm', 'Consumables', 'KG', '8311', 'WW-12', 'WW-12-B', 100, 280.00, '2025-26', 'EGI-010', NULL, NULL),
...                             (6, 6, 1, 'PN-6001', 'LED Panel Light', 'Electrical', 'EA', '9405', 'LP-40W', 'LP-40W-A', 30, 650.00, '2025-26', 'EGI-011', NULL, NULL),
...                             (8, 7, 1, 'PN-8001', 'Packing Material', 'Consumables', 'KG', '3923', 'PM-STD', 'PM-STD-A', 100, 35.00, '2025-26', 'EGI-012', 'VC-003', NULL),
...                             (8, 7, 2, 'PN-8002', 'Stretch Film Roll', 'Consumables', 'EA', '3920', 'SF-500', 'SF-500-B', 20, 180.00, '2025-26', 'EGI-013', 'VC-003', NULL)
