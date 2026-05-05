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

# ═══════════════════════════════════════════════════════════════
# D0365 Pipeline — DDL for esb schema tables
# ═══════════════════════════════════════════════════════════════
# Used by:
#   - D0365_test_clean_version_2026_05_04.slp  (8 INSERT snaps)
#   - D0365_Error_Pipeline_SQL_Delete_2026_05_04.slp  (6 DELETE snaps)
#
# Column lists derived from Script London output and Mapper transformations
# in the main pipeline. All IDs are hierarchical strings produced by the
# script (e.g. fileId_fromId_invoicePos_cfdPos_bpPos_unitId).
# ═══════════════════════════════════════════════════════════════

${SQL_CREATE_SCHEMA_ESB}
...                             IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'esb') EXEC('CREATE SCHEMA esb')

# --- esb.D0365Interchange (from ZHV record) ---

${SQL_DROP_TABLE_D0365INTERCHANGE}
...                             IF OBJECT_ID('esb.D0365Interchange', 'U') IS NOT NULL DROP TABLE esb.D0365Interchange

${SQL_CREATE_TABLE_D0365INTERCHANGE}
...                             CREATE TABLE esb.D0365Interchange (
...                             D0365InterchangeID NVARCHAR(200) NOT NULL PRIMARY KEY,
...                             CreatedDate        DATETIME2     NOT NULL
...                             )

# --- esb.EMRInvoiceHeader (from 86I record) ---

${SQL_DROP_TABLE_EMRINVOICEHEADER}
...                             IF OBJECT_ID('esb.EMRInvoiceHeader', 'U') IS NOT NULL DROP TABLE esb.EMRInvoiceHeader

${SQL_CREATE_TABLE_EMRINVOICEHEADER}
...                             CREATE TABLE esb.EMRInvoiceHeader (
...                             EMRInvoiceHeaderID NVARCHAR(200) NOT NULL PRIMARY KEY,
...                             PartyID            NVARCHAR(50)  NULL,
...                             InvoiceNumber      INT           NULL,
...                             InvoiceDate        DATE          NULL,
...                             InvoicePaymentDate DATE          NULL,
...                             InvoiceTotal       DECIMAL(18,2) NULL,
...                             CreatedDate        DATETIME2     NULL
...                             )

# --- esb.ContractForDifference (from 87I record) ---

${SQL_DROP_TABLE_CONTRACTFORDIFFERENCE}
...                             IF OBJECT_ID('esb.ContractForDifference', 'U') IS NOT NULL DROP TABLE esb.ContractForDifference

${SQL_CREATE_TABLE_CONTRACTFORDIFFERENCE}
...                             CREATE TABLE esb.ContractForDifference (
...                             ContractForDifferenceID    NVARCHAR(200)  NOT NULL PRIMARY KEY,
...                             EMRInvoiceHeaderID         NVARCHAR(200)  NULL,
...                             CFDID                      NVARCHAR(50)   NULL,
...                             ContractType               NVARCHAR(20)   NULL,
...                             TotalAggregateDifference   DECIMAL(18,4)  NULL,
...                             TotalReconciliationAmount  DECIMAL(18,4)  NULL,
...                             TotalInterest              DECIMAL(18,4)  NULL,
...                             NetPayableAmount           DECIMAL(18,4)  NULL,
...                             TotalAdHocPayment          DECIMAL(18,4)  NULL
...                             )

# --- esb.CFDBillingPeriod (from 88I record) ---

${SQL_DROP_TABLE_CFDBILLINGPERIOD}
...                             IF OBJECT_ID('esb.CFDBillingPeriod', 'U') IS NOT NULL DROP TABLE esb.CFDBillingPeriod

${SQL_CREATE_TABLE_CFDBILLINGPERIOD}
...                             CREATE TABLE esb.CFDBillingPeriod (
...                             CFDBillingPeriodID         NVARCHAR(200) NOT NULL PRIMARY KEY,
...                             ContractForDifferenceID    NVARCHAR(200) NULL,
...                             SettlementDate             DATE          NULL,
...                             SettlementCode             NVARCHAR(20)  NULL,
...                             AggregateDifferenceAmount  DECIMAL(18,4) NULL,
...                             ReconciliationAmount       DECIMAL(18,4) NULL,
...                             CompensatoryInterest       DECIMAL(18,4) NULL,
...                             Validated                  BIT           NULL
...                             )

# --- esb.CFDSettlementUnit (from 89I record) ---

${SQL_DROP_TABLE_CFDSETTLEMENTUNIT}
...                             IF OBJECT_ID('esb.CFDSettlementUnit', 'U') IS NOT NULL DROP TABLE esb.CFDSettlementUnit

${SQL_CREATE_TABLE_CFDSETTLEMENTUNIT}
...                             CREATE TABLE esb.CFDSettlementUnit (
...                             CFDSettlementUnitID                NVARCHAR(200) NOT NULL PRIMARY KEY,
...                             CFDBillingPeriodID                 NVARCHAR(200) NULL,
...                             SettlementUnitID                   INT           NULL,
...                             MeteredVolume                      DECIMAL(18,4) NULL,
...                             DSFUnitMeteredVolume               DECIMAL(18,4) NULL,
...                             DSFStationLoad                     DECIMAL(18,4) NULL,
...                             DSFStationLoadProportion           DECIMAL(18,4) NULL,
...                             TransmissionLossMultiplier         DECIMAL(18,4) NULL,
...                             ReferencePrice                     DECIMAL(18,4) NULL,
...                             StrikePrice                        DECIMAL(18,4) NULL,
...                             RenewableQualifyingMultiplier      DECIMAL(18,4) NULL,
...                             RenewableQualifyingMultiplierType  NVARCHAR(20)  NULL,
...                             CHPQualifyingMultiplier            DECIMAL(18,4) NULL,
...                             Difference                         DECIMAL(18,4) NULL,
...                             DifferenceAmount                   DECIMAL(18,4) NULL,
...                             Validated                          BIT           NULL
...                             )

# --- esb.CFDDefaultInterest (from 90I record) ---

${SQL_DROP_TABLE_CFDDEFAULTINTEREST}
...                             IF OBJECT_ID('esb.CFDDefaultInterest', 'U') IS NOT NULL DROP TABLE esb.CFDDefaultInterest

${SQL_CREATE_TABLE_CFDDEFAULTINTEREST}
...                             CREATE TABLE esb.CFDDefaultInterest (
...                             CFDDefaultInterestID     NVARCHAR(200) NOT NULL PRIMARY KEY,
...                             ContractForDifferenceID  NVARCHAR(200) NULL,
...                             EMRInvoiceNumber         INT           NULL,
...                             EMRInvoiceDate           DATE          NULL,
...                             AmountInDefault          DECIMAL(18,4) NULL,
...                             InterestPaymentFromDate  DATE          NULL,
...                             InterestPaymentToDate    DATE          NULL,
...                             InterestAmount           DECIMAL(18,4) NULL
...                             )

# --- esb.CFDDefaultInterestRate (from 91I record) ---

${SQL_DROP_TABLE_CFDDEFAULTINTERESTRATE}
...                             IF OBJECT_ID('esb.CFDDefaultInterestRate', 'U') IS NOT NULL DROP TABLE esb.CFDDefaultInterestRate

${SQL_CREATE_TABLE_CFDDEFAULTINTERESTRATE}
...                             CREATE TABLE esb.CFDDefaultInterestRate (
...                             CFDDefaultInterestRateID   NVARCHAR(200) NOT NULL PRIMARY KEY,
...                             CFDDefaultInterestID       NVARCHAR(200) NULL,
...                             InterestRateEffectiveDate  DATE          NULL,
...                             InterestRate               DECIMAL(10,6) NULL
...                             )

# --- esb.CFDAdHocPayment (from 92I record) ---

${SQL_DROP_TABLE_CFDADHOCPAYMENT}
...                             IF OBJECT_ID('esb.CFDAdHocPayment', 'U') IS NOT NULL DROP TABLE esb.CFDAdHocPayment

${SQL_CREATE_TABLE_CFDADHOCPAYMENT}
...                             CREATE TABLE esb.CFDAdHocPayment (
...                             CFDAdHocPaymentID                NVARCHAR(200) NOT NULL PRIMARY KEY,
...                             ContractForDifferenceID          NVARCHAR(200) NULL,
...                             Description                      NVARCHAR(255) NULL,
...                             CurtailmentCompAmount            DECIMAL(18,4) NULL,
...                             TerminationAmount                DECIMAL(18,4) NULL,
...                             QualChangeInLawAmount            DECIMAL(18,4) NULL,
...                             GenerationTaxAmount              DECIMAL(18,4) NULL,
...                             SustainabilityChangeInLawAmount  DECIMAL(18,4) NULL,
...                             OtherCFDAdHocPayment             DECIMAL(18,4) NULL,
...                             CompensatoryInterest             DECIMAL(18,4) NULL,
...                             CompensatoryInterestFromDate     DATE          NULL,
...                             CompensatoryInterestToDate       DATE          NULL
...                             )

# --- Existence probe used by idempotent setup ---

${SQL_CHECK_D0365_TABLES_EXIST}
...                             SELECT COUNT(*) AS cnt FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id WHERE s.name = 'esb' AND t.name = 'D0365Interchange'

# --- Truncate-before-run (resets state to allow re-running with the same input file) ---
# IDs in the D0365 pipeline are deterministic (fileId_fromId_...), so re-running
# the same file twice without clearing rows triggers PRIMARY KEY violations.
# Order: child tables first, then parents.

${SQL_DELETE_FROM_CFDADHOCPAYMENT}            DELETE FROM esb.CFDAdHocPayment
${SQL_DELETE_FROM_CFDDEFAULTINTERESTRATE}     DELETE FROM esb.CFDDefaultInterestRate
${SQL_DELETE_FROM_CFDDEFAULTINTEREST}         DELETE FROM esb.CFDDefaultInterest
${SQL_DELETE_FROM_CFDSETTLEMENTUNIT}          DELETE FROM esb.CFDSettlementUnit
${SQL_DELETE_FROM_CFDBILLINGPERIOD}           DELETE FROM esb.CFDBillingPeriod
${SQL_DELETE_FROM_CONTRACTFORDIFFERENCE}      DELETE FROM esb.ContractForDifference
${SQL_DELETE_FROM_EMRINVOICEHEADER}           DELETE FROM esb.EMRInvoiceHeader
${SQL_DELETE_FROM_D0365INTERCHANGE}           DELETE FROM esb.D0365Interchange

# --- Row-count queries used by data verification test cases ---

${SQL_COUNT_D0365INTERCHANGE}            SELECT COUNT(*) FROM esb.D0365Interchange
${SQL_COUNT_EMRINVOICEHEADER}            SELECT COUNT(*) FROM esb.EMRInvoiceHeader
${SQL_COUNT_CONTRACTFORDIFFERENCE}       SELECT COUNT(*) FROM esb.ContractForDifference
${SQL_COUNT_CFDBILLINGPERIOD}            SELECT COUNT(*) FROM esb.CFDBillingPeriod
${SQL_COUNT_CFDSETTLEMENTUNIT}           SELECT COUNT(*) FROM esb.CFDSettlementUnit
${SQL_COUNT_CFDDEFAULTINTEREST}          SELECT COUNT(*) FROM esb.CFDDefaultInterest
${SQL_COUNT_CFDDEFAULTINTERESTRATE}      SELECT COUNT(*) FROM esb.CFDDefaultInterestRate
${SQL_COUNT_CFDADHOCPAYMENT}             SELECT COUNT(*) FROM esb.CFDAdHocPayment

# --- Content lookups used by content-verification test cases ---

${SQL_SELECT_INTERCHANGE_ID}             SELECT D0365InterchangeID FROM esb.D0365Interchange
${SQL_SELECT_INVOICE_TOTAL}              SELECT InvoiceTotal FROM esb.EMRInvoiceHeader
${SQL_SELECT_NET_PAYABLE_AMOUNT}         SELECT NetPayableAmount FROM esb.ContractForDifference
# Settlement unit IDs are read directly via Get Column Values (table + column)
# from sql_table_operations.resource — no dedicated SELECT variable needed.
